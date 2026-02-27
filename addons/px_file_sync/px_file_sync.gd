@tool
extends EditorPlugin

const SETTINGS_KEY := "px_sync/source_path_abs"
const DST_RES := "res://."
const SHORTCUT_NAME := "px_sync/sync_now"

const SUBMENU_NAME := "PX Sync"

var _submenu: PopupMenu
var _file_dialog: EditorFileDialog


enum MenuId {
	SYNC_NOW,
	SET_SOURCE
}

func _enter_tree() -> void:
	# Create submenu
	_submenu = PopupMenu.new()
	_submenu.add_item("Sync Now", MenuId.SYNC_NOW)
	_submenu.set_item_shortcut(
		MenuId.SYNC_NOW,
		_create_shortcut(),
		true
	)
	_submenu.add_separator()
	_submenu.add_item("Set Source…", MenuId.SET_SOURCE)
	_submenu.id_pressed.connect(_on_submenu_pressed)

	add_tool_submenu_item(SUBMENU_NAME, _submenu)

	# Folder picker
	_file_dialog = EditorFileDialog.new()
	_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	_file_dialog.title = "Select PX Source Top Folder"
	_file_dialog.dir_selected.connect(_on_dir_selected)
	EditorInterface.get_base_control().add_child(_file_dialog)

func _create_shortcut() -> Shortcut:
	var shortcut := Shortcut.new()

	var key_event := InputEventKey.new()
	key_event.ctrl_pressed = true
	key_event.shift_pressed = true
	key_event.alt_pressed = true
	key_event.keycode = KEY_Y # Ctrl+Shift+ALT+Y

	shortcut.events = [key_event]

	# Register so it appears in Editor Settings → Shortcuts
	EditorInterface.get_editor_settings().add_shortcut(SHORTCUT_NAME, shortcut)

	return EditorInterface.get_editor_settings().get_shortcut(SHORTCUT_NAME)

func _exit_tree() -> void:
	remove_tool_menu_item(SUBMENU_NAME)
	if _submenu:
		_submenu.queue_free()
	if _file_dialog:
		_file_dialog.queue_free()

func _on_submenu_pressed(id: int) -> void:
	match id:
		MenuId.SYNC_NOW:
			_sync()
		MenuId.SET_SOURCE:
			_set_source()

func _set_source() -> void:
	var current := _get_source_path()
	if not current.is_empty():
		_file_dialog.current_dir = current
	_file_dialog.popup_centered_ratio(0.7)

func _on_dir_selected(dir_abs: String) -> void:
	EditorInterface.get_editor_settings().set_setting(SETTINGS_KEY, dir_abs)
	print("PX Sync", "Source set to:\n%s" % dir_abs)

func _sync() -> void:
	var src_abs := _get_source_path()
	var stats := PxSync.sync_tree_px(src_abs, DST_RES)
	print(
		"PX Sync Found: %d, Copied: %d, Unchanged: %d, Errors: %d" % [
			stats["total_px_found"], stats["copied"], stats["unchanged"], stats["errors"]
		]
	)
	var fs = EditorInterface.get_resource_filesystem()
	if not fs.is_scanning():
		fs.scan()

func _get_source_path() -> String:
	var es := EditorInterface.get_editor_settings()
	if es.has_setting(SETTINGS_KEY):
		return str(es.get_setting(SETTINGS_KEY))
	return ""
