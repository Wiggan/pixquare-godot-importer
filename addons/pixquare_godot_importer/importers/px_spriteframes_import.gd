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
# animation_name
#   Name of the animation created in the SpriteFrames resource.
#   This is the key used by AnimatedSprite2D.play().
#
# fps
#   Playback speed (frames per second) for the animation.
#   Stored as SpriteFrames animation speed.
#
# frame_from
#   Zero-based index of the first Pixquare frame to import.
#   Use this to skip setup frames or split animations from one timeline.
#
# frame_count
#   Number of frames to import.
#   0 means "import all available frames starting at frame_from".
#
# composite_visible_layers
#   If true, only layers marked as visible in Pixquare are composited.
#   If false, all regular layers are composited regardless of visibility.
func _get_import_options(path, preset_index):
	return [
		{"name": "animation_name", "default_value": "default"},
		{"name": "fps", "default_value": 12},
		{"name": "frame_from", "default_value": 0},
		{"name": "frame_count", "default_value": 0},
		{"name": "composite_visible_layers", "default_value": true},
	]


func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	return PxCore.import_spriteframes(source_file, save_path, options, platform_variants, gen_files, _get_save_extension())
