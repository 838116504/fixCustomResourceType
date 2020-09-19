tool
extends EditorInspectorPlugin

var editorInterface

func can_handle(object):
	return object.get_script() != null

func parse_property(object, type, path, hint, hint_text:String, usage):
	if hint != PROPERTY_HINT_RESOURCE_TYPE:
		return false
	var array =  hint_text.split(",")
	if array.size() < 1:
		return false
	
	var findCustomRes = false
	var baseTypes := []
	var customTypes := []
	for i in array.size():
		array[i] = array[i].strip_edges()
		if ClassDB.class_exists(array[i]):
			if baseTypes.find(array[i]) < 0:
				baseTypes.append(array[i])
		else:
			if customTypes.find(array[i]) < 0:
				customTypes.append(array[i])
	
	if customTypes.size() <= 0:
		return false
	
	var resourceProperty = preload("resourceProperty.gd").new()
	resourceProperty.setup(baseTypes, customTypes)
	resourceProperty.editorInterface = editorInterface
	add_property_editor(path, resourceProperty)
	return true

