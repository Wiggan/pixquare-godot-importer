@tool
extends EditorPlugin

const IMPORTS = [
	preload("uid://by2s7oyx4nlju"),
	preload("uid://d0yx37chho6vu"),
	preload("uid://usxbx8dldokt"),
]

var imports = []

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	for i in IMPORTS:
		var importer = i.new()
		imports.append(importer)
		add_import_plugin(importer)

func _exit_tree() -> void:
	for i in imports:
		remove_import_plugin(i)
	imports.clear()
	
