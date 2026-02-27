@tool
extends RefCounted
class_name ArtSync

const EXT := "px"

static func sync_tree_px(src_abs: String, dst_res: String) -> Dictionary:
	var dst_abs := ProjectSettings.globalize_path(dst_res)

	var stats := {
		"ok": true,
		"source_missing": false,
		"total_px_found": 0,
		"copied": 0,
		"unchanged": 0,
		"errors": 0,
		"error_paths": PackedStringArray(),
	}

	if src_abs.is_empty() or not DirAccess.dir_exists_absolute(src_abs):
		stats["source_missing"] = true
		return stats

	DirAccess.make_dir_recursive_absolute(dst_abs)

	_sync_dir_px(src_abs, dst_abs, stats)

	return stats

static func _sync_dir_px(src_dir: String, dst_dir: String, stats: Dictionary) -> void:
	var dir := DirAccess.open(src_dir)
	if dir == null:
		stats["errors"] += 1
		stats["error_paths"].append(src_dir)
		return

	dir.include_hidden = false
	dir.include_navigational = false

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break

		var src_path := src_dir.path_join(name)
		var dst_path := dst_dir.path_join(name)

		if dir.current_is_dir():
			DirAccess.make_dir_recursive_absolute(dst_path)
			_sync_dir_px(src_path, dst_path, stats)
			continue

		if name.get_extension().to_lower() != EXT:
			continue

		stats["total_px_found"] += 1

		if _same_file_quick(src_path, dst_path):
			stats["unchanged"] += 1
			continue

		if _copy_file_atomic(src_path, dst_path):
			stats["copied"] += 1
		else:
			stats["errors"] += 1
			stats["error_paths"].append(src_path)

	dir.list_dir_end()

static func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var n := int(f.get_length())
	f.close()
	return n

static func _same_file_quick(a: String, b: String) -> bool:
	if not FileAccess.file_exists(b):
		return false

	var sa := _file_size(a)
	var sb := _file_size(b)
	if sa < 0 or sb < 0:
		return false
	if sa != sb:
		return false
	
	var hs := _hash_file(a)
	var hd := _hash_file(b)
	
	return hs == hd

static func _is_file_stable(path: String, wait_ms: int) -> bool:
	var s1 := _file_size(path)
	OS.delay_msec(wait_ms)
	var s2 := _file_size(path)
	return s1 > 0 and s1 == s2

static func _copy_file_atomic(src_path: String, dst_path: String) -> bool:
	# Avoid iCloud partial reads
	if not _is_file_stable(src_path, 150):
		return false

	var f := FileAccess.open(src_path, FileAccess.READ)
	if f == null:
		return false
	var bytes := f.get_buffer(f.get_length())
	f.close()

	DirAccess.make_dir_recursive_absolute(dst_path.get_base_dir())

	var tmp_path := dst_path + ".tmp"

	var out := FileAccess.open(tmp_path, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(bytes)
	out.flush()
	out.close()

	# Replace destination
	if FileAccess.file_exists(dst_path):
		var rm_err := DirAccess.remove_absolute(dst_path)
		if rm_err != OK:
			DirAccess.remove_absolute(tmp_path)
			return false

	var rn_err := DirAccess.rename_absolute(tmp_path, dst_path)
	if rn_err != OK:
		DirAccess.remove_absolute(tmp_path)
		return false

	# efter copy:
	var hs := _hash_file(src_path)
	var hd := _hash_file(dst_path)
	if hs != hd:
		push_error("PX sync hash mismatch: %s" % src_path)

	return true

static func _hash_file(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var bytes := f.get_buffer(int(f.get_length()))
	f.close()
	return hash(bytes)
