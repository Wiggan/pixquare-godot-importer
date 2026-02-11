
extends RefCounted
class_name PxCore

# -----------------------------------------------------------------------------
# Binary reader helpers (little-endian)
# -----------------------------------------------------------------------------
class PxReader:
	var f: FileAccess

	func _init(file: FileAccess) -> void:
		f = file

	func pos() -> int:
		return f.get_position()

	func seek(p: int) -> void:
		f.seek(p)

	func skip(n: int) -> void:
		f.seek(f.get_position() + n)

	func u8() -> int:
		return f.get_8()

	func bool() -> bool:
		return f.get_8() != 0

	func u16() -> int:
		return f.get_16()

	func i16() -> int:
		var v := f.get_16()
		return v - 0x10000 if v >= 0x8000 else v

	func u32() -> int:
		return f.get_32()

	func u64() -> int:
		return f.get_64()

	func bytes(n: int) -> PackedByteArray:
		return f.get_buffer(n)

	func dumb_string(n: int) -> String:
		if n <= 0:
			return ""
		return bytes(n).get_string_from_utf8()

	func size_u32() -> Vector2i:
		var w := u32()
		var h := u32()
		return Vector2i(w, h)

	func array_count() -> int:
		# Arrays are prefixed by UInt64 element count (except a few special cases not used here).
		var count := int(u64())
		return count

# -----------------------------------------------------------------------------
# Px parsing (minimal)
# -----------------------------------------------------------------------------
const ARTWORK_HEADER_BYTES := 64
const ENTRY_HEADER_BYTES := 16
const LAYER_HEADER_BYTES := 32
const FRAME_HEADER_BYTES := 32
const FRAMECONTENT_HEADER_BYTES := 32



static func _read_entry(r: PxReader) -> PxTypes.PxEntry:
	# Header (16): UInt32 size, UInt8 entry type, rest unused
	var size := r.u32()
	var entry_type := r.u8()
	r.skip(ENTRY_HEADER_BYTES - 4 - 1)

	var start := r.pos()
	var id_len := r.u8()
	var id := r.dumb_string(id_len)

	# Be robust: skip to end of model content if there's more (size excludes header)
	var consumed := r.pos() - start
	if consumed < size:
		r.skip(size - consumed)

	var e := PxTypes.PxEntry.new()
	e.entry_type = entry_type
	e.id = id
	return e

static func _skip_model_u32_header(r: PxReader, header_bytes: int) -> void:
	var size := r.u32()
	r.skip(header_bytes - 4)
	r.skip(size)

static func _skip_custom_data(r: PxReader) -> void:
	# CustomData header (16): UInt64 size, UInt8 type, rest unused
	var size := r.u64()
	r.skip(16 - 8) # remaining header bytes
	# size excludes header
	r.skip(int(size))
	
static func _read_frame(r: PxReader) -> PxTypes.PxFrame:
	var size := r.u32()
	var id_len := r.u8()
	var content_id_len := r.u8()
	r.skip(FRAME_HEADER_BYTES - 4 - 1 - 1)

	var content_start := r.pos()

	var id := r.dumb_string(id_len)
	var duration := r.u32()
	var selected := r.bool()
	var content_id := r.dumb_string(content_id_len)

	var opacity_f16 := r.u16() # keep raw
	var z_index := r.i16()

	var cd_count := r.array_count()
	for _i in range(cd_count):
		_skip_custom_data(r)

	var consumed := r.pos() - content_start
	if consumed < size:
		r.skip(size - consumed)

	var fr := PxTypes.PxFrame.new()
	fr.id = id
	fr.duration_ms = int(duration)
	fr.selected = selected
	fr.content_id = content_id
	fr.opacity_f16 = int(opacity_f16)
	fr.z_index = int(z_index)
	return fr

static func _read_layer_full(r: PxReader) -> PxTypes.PxLayer:
	var size := r.u32()
	var id_len := r.u8()
	var name_len := r.u8()
	r.skip(1) # ignore optionset
	r.skip(LAYER_HEADER_BYTES - 4 - 1 - 1 - 1)

	var content_start := r.pos()

	var id := r.dumb_string(id_len)
	var name := r.dumb_string(name_len)

	var frames: Array[PxTypes.PxFrame] = []
	var frame_count := r.array_count()
	frames.resize(frame_count)
	for i in range(frame_count):
		frames[i] = _read_frame(r)

	var visible := true
	var blend := PxTypes.BLEND_NORMAL

	var remaining := size - int(r.pos() - content_start)
	if remaining >= 2 + 1 + 1 + 1 + 1 + 2:
		r.skip(2)     # opacity f16
		visible = r.bool()
		r.skip(1)     # locked
		r.skip(1)     # selected
		r.skip(1)     # alpha-locked
		blend = r.u16()

	remaining = size - int(r.pos() - content_start)
	if remaining > 0:
		r.skip(remaining)

	var lay := PxTypes.PxLayer.new()
	lay.id = id
	lay.name = name
	lay.visible = visible
	lay.blend = blend
	lay.frames = frames
	return lay


static func _read_frame_content(r: PxReader) -> Dictionary:
	# Header (32): UInt64 size, UInt8 id_len, UInt32 ignore, UInt32 color_len, OptionSet<UInt8> ignore, rest unused
	var size := r.u64()
	var id_len := r.u8()
	r.skip(4) # ignore
	var color_len := r.u32()
	r.skip(1) # ignore
	r.skip(FRAMECONTENT_HEADER_BYTES - (8 + 1 + 4 + 4 + 1))

	var content_start := r.pos()

	var id := r.dumb_string(id_len)
	var compressed := r.bytes(color_len)

	# Robust: skip any remaining bytes in the model (size excludes header)
	var consumed := r.pos() - content_start
	if consumed < int(size):
		r.skip(int(size) - consumed)

	return {"id": id, "compressed": compressed}

# -----------------------------------------------------------------------------
# Compositing (premultiplied alpha in file; unpremultiply at end)
# -----------------------------------------------------------------------------
static func _premul_over(dst: PackedByteArray, src: PackedByteArray) -> void:
	# Both arrays are RGBA premultiplied, same length
	var n := dst.size()
	var i := 0
	while i < n:
		var sr := int(src[i + 0])
		var sg := int(src[i + 1])
		var sb := int(src[i + 2])
		var sa := int(src[i + 3])

		if sa != 0:
			var dr := int(dst[i + 0])
			var dg := int(dst[i + 1])
			var db := int(dst[i + 2])
			var da := int(dst[i + 3])

			var inv := 255 - sa

			# out = src + dst*(1-sa)
			dst[i + 0] = clampi(sr + ((dr * inv + 127) / 255), 0, 255)
			dst[i + 1] = clampi(sg + ((dg * inv + 127) / 255), 0, 255)
			dst[i + 2] = clampi(sb + ((db * inv + 127) / 255), 0, 255)
			dst[i + 3] = clampi(sa + ((da * inv + 127) / 255), 0, 255)

		i += 4

static func _unpremultiply_rgba(premul: PackedByteArray) -> PackedByteArray:
	var out := premul.duplicate()
	var n := out.size()
	var i := 0
	while i < n:
		var a := int(out[i + 3])
		if a <= 0:
			out[i + 0] = 0
			out[i + 1] = 0
			out[i + 2] = 0
		elif a < 255:
			# rgb = rgb * 255 / a
			out[i + 0] = clampi((int(out[i + 0]) * 255 + (a / 2)) / a, 0, 255)
			out[i + 1] = clampi((int(out[i + 1]) * 255 + (a / 2)) / a, 0, 255)
			out[i + 2] = clampi((int(out[i + 2]) * 255 + (a / 2)) / a, 0, 255)
		i += 4
	return out
	

static func _compose_frame_rgba_straight(
	w: int,
	h: int,
	layer_ids: Array[String],
	layers_by_id: Dictionary,
	frame_content_by_id: Dictionary,
	frame_index: int,
	composite_visible: bool
) -> PackedByteArray:
	var expected_len := w * h * 4

	# Premultiplied RGBA working buffer
	var out_premul := PackedByteArray()
	out_premul.resize(expected_len)
	for i in range(expected_len):
		out_premul[i] = 0

	for id in layer_ids:
		var lay = layers_by_id.get(id, null)
		if lay == null:
			continue
		if composite_visible and not lay.visible:
			continue
		if frame_index < 0 or frame_index >= lay.frames.size():
			continue

		var content_id: String = lay.frames[frame_index].content_id
		if content_id == "":
			continue

		var compressed: PackedByteArray = frame_content_by_id.get(content_id, PackedByteArray())
		if compressed.is_empty():
			continue

		var raw_premul := PxZlib.inflate_pixquare_zlib(compressed)
		if raw_premul.is_empty():
			push_error("Pixquare import: inflate failed for content_id=%s" % content_id)
			continue

		if raw_premul.size() != expected_len:
			push_warning("Pixquare import: frame bytes mismatch got=%d expected=%d" % [raw_premul.size(), expected_len])
			continue

		_premul_over(out_premul, raw_premul)

	# Convert premultiplied -> straight alpha for Godot Image
	return _unpremultiply_rgba(out_premul)


static func _make_sheet_bytes(frames: Array[PackedByteArray], w: int, h: int) -> PackedByteArray:
	var frame_count := frames.size()
	var sheet_w := w * frame_count
	var sheet_h := h
	var sheet := PackedByteArray()
	sheet.resize(sheet_w * sheet_h * 4)

	# Copy row-by-row for each frame into the big sheet.
	for fi in range(frame_count):
		var src := frames[fi]
		var x_off := fi * w

		for y in range(h):
			var src_row_start := (y * w) * 4
			var dst_row_start := ((y * sheet_w) + x_off) * 4

			# Copy w*4 bytes
			for b in range(w * 4):
				sheet[dst_row_start + b] = src[src_row_start + b]

	return sheet


static func load_document(source_file: String) -> PxTypes.PxDocument:
	var file := FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return null

	var r := PxReader.new(file)
	var doc := PxTypes.PxDocument.new()
	doc.source_path = source_file

	# Artwork header (64 bytes)
	var _total_file_size := r.u64()
	var artwork_id_len := r.u8()
	r.skip(2)
	r.skip(ARTWORK_HEADER_BYTES - (8 + 1 + 2))

	# Artwork content
	doc.artwork_id = r.dumb_string(artwork_id_len)
	doc.canvas_size = r.size_u32()

	# [Entry]
	var entry_count := r.array_count()
	doc.entries.resize(entry_count)
	for i in range(entry_count):
		doc.entries[i] = _read_entry(r)

	# [Group] (skip, but keep room for later)
	var group_count := r.array_count()
	for _i in range(group_count):
		_skip_model_u32_header(r, 32)

	# [Layer]
	var layer_count := r.array_count()
	for _i in range(layer_count):
		var lay := _read_layer_full(r)
		doc.layers_by_id[lay.id] = lay

	# [FrameContent]
	var fc_count := r.array_count()
	for _i in range(fc_count):
		var fc := _read_frame_content(r)
		doc.frame_content_by_id[fc["id"]] = fc["compressed"]

	# [ARGBColor] palette
	var palette_count := r.array_count()
	doc.palette = r.bytes(palette_count * 4)

	return doc


# -----------------------------------------------------------------------------
# Import entrypoint
# -----------------------------------------------------------------------------
static func build_texture_2d(doc: PxTypes.PxDocument, options: Dictionary) -> Texture2D:
	var w := doc.canvas_size.x
	var h := doc.canvas_size.y

	var frame_index := int(options.get("frame_index", 0))
	var composite_visible := bool(options.get("composite_visible_layers", true))

	var layer_ids := doc.get_root_regular_layer_order()
	if layer_ids.is_empty():
		layer_ids = doc.layers_by_id.keys()

	var rgba := _compose_frame_rgba_straight(
		w, h,
		layer_ids,
		doc.layers_by_id,
		doc.frame_content_by_id,
		frame_index,
		composite_visible
	)

	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, rgba)
	return ImageTexture.create_from_image(img)

	
static func build_spriteframes(doc: PxTypes.PxDocument, options: Dictionary) -> SpriteFrames:
	var w := doc.canvas_size.x
	var h := doc.canvas_size.y

	var anim_name := String(options.get("animation_name", "default"))
	var fps := float(options.get("fps", 12))
	var frame_from := int(options.get("frame_from", 0))
	var frame_count_opt := int(options.get("frame_count", 0))
	var composite_visible := bool(options.get("composite_visible_layers", true))

	var layer_ids := doc.get_root_regular_layer_order()
	if layer_ids.is_empty():
		layer_ids = doc.layers_by_id.keys()

	var max_frames := doc.get_max_frame_count_for_layers(layer_ids)

	var frame_to := max_frames
	if frame_count_opt > 0:
		frame_to = min(max_frames, frame_from + frame_count_opt)

	var frames_rgba: Array[PackedByteArray] = []
	for fi in range(frame_from, frame_to):
		frames_rgba.append(_compose_frame_rgba_straight(
			w, h, layer_ids, doc.layers_by_id, doc.frame_content_by_id, fi, composite_visible
		))

	var sheet_bytes := _make_sheet_bytes(frames_rgba, w, h)
	var sheet_w := w * frames_rgba.size()
	var sheet_img := Image.create_from_data(sheet_w, h, false, Image.FORMAT_RGBA8, sheet_bytes)
	var sheet_tex := ImageTexture.create_from_image(sheet_img)

	var sf := SpriteFrames.new()
	sf.add_animation(anim_name)
	sf.set_animation_speed(anim_name, fps)
	sf.set_animation_loop(anim_name, true)

	for i in range(frames_rgba.size()):
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet_tex
		atlas.region = Rect2(i * w, 0, w, h)
		sf.add_frame(anim_name, atlas)

	return sf
