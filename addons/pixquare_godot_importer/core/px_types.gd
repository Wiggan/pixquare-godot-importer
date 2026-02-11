extends RefCounted
class_name PxTypes

const ENTRY_TYPE_REGULAR_LAYER := 0
const BLEND_NORMAL := 0

class PxEntry:
	var entry_type: int
	var id: String

class PxFrame:
	var id: String = ""
	var content_id: String = ""
	var duration_ms: int = 0
	var selected: bool = false
	var opacity_f16: int = 0
	var z_index: int = 0

class PxTag:
	var name: String = ""
	var from_frame: int = 0
	var to_frame: int = 0
	var direction: int = 0 # 0=forward, 1=reverse, 2=pingpong
	var loop_count: int = 0 # 0=infinite

class PxLayer:
	var id: String = ""
	var name: String = ""
	var visible: bool = true
	var blend: int = BLEND_NORMAL
	var frames: Array[PxFrame] = []

class PxDocument:
	var source_path: String = ""
	var artwork_id: String = ""
	var canvas_size: Vector2i = Vector2i.ZERO

	# Root entry list in order (for later: groups, etc).
	var entries: Array[PxEntry] = []

	# Regular layers keyed by id
	var layers_by_id: Dictionary = {} # String -> PxLayer

	# Frame content raw blobs keyed by id (compressed zlib bytes)
	var frame_content_by_id: Dictionary = {} # String -> PackedByteArray

	# Optional palette (ARGBColor bytes as stored)
	var palette: PackedByteArray = PackedByteArray()

	# Tags
	var tags: Array[PxTag] = []

	func get_root_regular_layer_order() -> Array[String]:
		var out: Array[String] = []
		for e in entries:
			if e.entry_type == ENTRY_TYPE_REGULAR_LAYER:
				out.append(e.id)
		return out

	func get_max_frame_count_for_layers(layer_ids: Array[String]) -> int:
		var max_frames := 0
		for id in layer_ids:
			var lay: PxLayer = layers_by_id.get(id, null)
			if lay != null:
				max_frames = max(max_frames, lay.frames.size())
		return max_frames

	func get_duration_ms_for_frame(layer_id: String, frame_idx: int) -> int:
		var lay: PxLayer = layers_by_id.get(layer_id, null)
		if lay != null and frame_idx < lay.frames.size():
			return lay.frames[frame_idx].duration_ms
		return 0
