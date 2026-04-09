@tool
extends EditorImportPlugin

func _get_importer_name():
	return "fwdab.px.import.spritesheet"

func _get_visible_name():
	return "Texture2D (Animation Sheet)"

func _get_recognized_extensions():
	return ["px"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "Texture2D"

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"

func _get_import_options(path, preset_index):
	return [
		{
			"name": "animation_tag",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": _get_animation_tag_hint(path),
		},
		{
			"name": "sheet_columns",
			"default_value": _get_default_sheet_columns(path),
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "1,512,1,or_greater",
		},
		{"name": "composite_visible_layers", "default_value": true},
	]

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var doc := PxCore.load_document(source_file)
	if doc == null:
		return FAILED

	var tex := PxCore.build_animation_sheet_texture(doc, options)
	return ResourceSaver.save(tex, save_path + "." + _get_save_extension())

func _get_animation_tag_hint(path: String) -> String:
	var options := PackedStringArray(["All Frames"])
	var doc := PxCore.load_document(path)
	if doc == null:
		return ",".join(options)

	for i in range(doc.tags.size()):
		var tag := doc.tags[i]
		var tag_name := tag.name.replace(",", " ")
		if tag_name.is_empty():
			tag_name = "Tag %d" % (i + 1)
		options.append(tag_name)

	return ",".join(options)

func _get_default_sheet_columns(path: String) -> int:
	var doc := PxCore.load_document(path)
	if doc == null:
		return 1

	var layer_ids := doc.get_root_regular_layer_order()
	if layer_ids.is_empty():
		for key in doc.layers_by_id.keys():
			layer_ids.append(String(key))

	var frame_count := doc.get_max_frame_count_for_layers(layer_ids)
	if frame_count <= 1:
		return 1

	return maxi(1, ceili(sqrt(float(frame_count))))
