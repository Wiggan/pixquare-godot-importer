@tool
extends EditorImportPlugin

func _get_importer_name():
	return "fwdab.px.import.tilesetatlassource"

func _get_visible_name():
	return "Texture2D (TileSet Atlas)"

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
	
# Import options for Pixquare TileSetAtlasSource importer.
func _get_import_options(path, preset_index):
	return [
		{"name": "tileset_index", "default_value": 0},
	]

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var doc := PxCore.load_document(source_file)
	if doc == null:
		return FAILED

	var ts := PxCore.build_tileset(doc, options)
	return ResourceSaver.save(ts, save_path + "." + _get_save_extension())
