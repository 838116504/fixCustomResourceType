extends EditorInspectorPlugin

var editorInterface

func can_handle(object):
	return object.get_script() != null

func parse_property(object, type, path, hint, hint_text, usage):
	if hint != PROPERTY_HINT_RESOURCE_TYPE || hint_text.find(",") >= 0 || ClassDB.class_exists(hint_text):
		return false
	
	if ProjectSettings.has_setting("_global_script_classes"):
		var classData = ProjectSettings.get_setting("_global_script_classes")
		for i in classData:
			if i["class"] == hint_text:
				var resourceProperty = preload("resourceProperty.gd").new()
				resourceProperty.setup(hint_text)
				resourceProperty.editorInterface = editorInterface
				add_property_editor(path, resourceProperty)
				return true
	return false
