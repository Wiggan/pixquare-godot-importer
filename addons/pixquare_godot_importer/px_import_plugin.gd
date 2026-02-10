@tool
extends EditorPlugin

var import_texture2d
var import_spriteframes

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	import_texture2d = preload("uid://d0yx37chho6vu").new()
	import_spriteframes = preload("uid://by2s7oyx4nlju").new()
	add_import_plugin(import_texture2d)
	add_import_plugin(import_spriteframes)


func _exit_tree() -> void:
	remove_import_plugin(import_texture2d)
	remove_import_plugin(import_spriteframes)
	import_texture2d = null
	import_spriteframes = null
