@tool
extends EditorImportPlugin

func _get_importer_name():
	return "fwdab.px.import.spriteframes"

func _get_visible_name():
	return "SpriteFrames"

func _get_recognized_extensions():
	return ["px"]
	
func _get_save_extension():
	return "tres"

func _get_resource_type():
	return "SpriteFrames"

func _get_preset_count():
	return 1

func _get_preset_name(preset_index):
	return "Default"
	
# Import options for Pixquare SpriteFrames importer.
#
# composite_visible_layers
#   If true, only layers marked as visible in Pixquare are composited.
#   If false, all regular layers are composited regardless of visibility.
func _get_import_options(path, preset_index):
	return [
		{"name": "composite_visible_layers", "default_value": true},
	]


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var doc := PxCore.load_document(source_file)
	if doc == null:
		return FAILED

	var sf := PxCore.build_spriteframes(doc, options)
	return ResourceSaver.save(sf, save_path + "." + _get_save_extension())
