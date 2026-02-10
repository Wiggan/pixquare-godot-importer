extends RefCounted
class_name PxZlib

static func inflate_pixquare_zlib(compressed: PackedByteArray) -> PackedByteArray:
	# Pixquare FrameContent.color_data is zlib-wrapped deflate. (78 9C ...)
	# StreamPeerGZIP in deflate mode expects deflate stream (often raw deflate),
	# so try stripping zlib wrapper first: 2-byte header + 4-byte Adler32.
	if compressed.size() < 6:
		return PackedByteArray()

	var candidates: Array[PackedByteArray] = []
	candidates.append(compressed)  # full zlib stream

	for data in candidates:
		var out := inflate_with_streampeergzip_no_finish(data, true) # use_deflate=true
		if not out.is_empty():
			return out

	return PackedByteArray()


static func inflate_with_streampeergzip_no_finish(data: PackedByteArray, use_deflate: bool) -> PackedByteArray:
	var sp := StreamPeerGZIP.new()
	var err := sp.start_decompression(use_deflate)
	if err != OK:
		return PackedByteArray()

	var out := PackedByteArray()

	# Feed in chunks, and drain output as we go.
	var offset := 0
	while offset < data.size():
		var end := min(offset + 4096, data.size())
		var chunk := data.slice(offset, end)

		var res := sp.put_partial_data(chunk) # [Error, bytes_written]
		if res[0] != OK:
			return PackedByteArray()
		var wrote := int(res[1])
		if wrote <= 0:
			return PackedByteArray()
		offset += wrote

		# Drain any produced bytes
		while true:
			var avail := sp.get_available_bytes()
			if avail <= 0:
				break
			var got := sp.get_partial_data(avail) # [Error, PackedByteArray]
			if got[0] != OK:
				return PackedByteArray()
			out.append_array(got[1])

	# IMPORTANT: do NOT call finish() when decompressing (docs say it's for compressing only).
	# :contentReference[oaicite:1]{index=1}
	return out
