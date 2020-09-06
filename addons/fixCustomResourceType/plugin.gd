tool
extends EditorPlugin

var inspectorPlugin

func _enter_tree():
	inspectorPlugin = preload("customResourceInspectorPlugin.gd").new()
	inspectorPlugin.editorInterface = get_editor_interface()
	add_inspector_plugin(inspectorPlugin)


func _exit_tree():
	remove_inspector_plugin(inspectorPlugin)
	if ProjectSettings.has_setting("fixCustomResourceType/clipboard"):
		ProjectSettings.clear("fixCustomResourceType/clipboard")
