tool
extends EditorProperty

const TYPE_BASE_ID = 100
const OBJ_MENU_LOAD = 0
const OBJ_MENU_EDIT = 1
const OBJ_MENU_CLEAR = 2
const OBJ_MENU_MAKE_UNIQUE = 3
const OBJ_MENU_SAVE = 4
const OBJ_MENU_SHOW_IN_FILE_SYSTEM = 9
const OBJ_MENU_COPY = 5
const OBJ_MENU_PASTE = 6

var assign := Button.new()
var preview := TextureRect.new()
var edit = Button.new()
var menu := PopupMenu.new()
var editorInterface:EditorInterface
var baseTypes:Array = []
var customBaseTypes:Array = []
var file:EditorFileDialog

func _init():
	var hbc = HBoxContainer.new()
	add_child(hbc)
	assign.size_flags_horizontal = SIZE_EXPAND_FILL
	assign.flat = true
	assign.clip_text = true
	assign.set_drag_forwarding(self)
	assign.connect("gui_input", self, "_on_buttons_input")
	assign.connect("pressed", self, "_on_assign_pressed")
	hbc.add_child(assign)
	add_focusable(assign)
	preview.expand = true
	preview.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	preview.margin_bottom = -1
	preview.margin_top = 1
	preview.margin_right = -1
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.hide()
	assign.add_child(preview)
	
	menu.connect("id_pressed", self, "_on_menu_id_pressed")
	menu.connect("popup_hide", edit, "set_pressed", [false])
	add_child(menu)
	
	edit.flat = true
	edit.toggle_mode = true
	edit.connect("pressed", self, "_on_edit_pressed")
	edit.connect("gui_input", self, "_on_buttons_input")
	hbc.add_child(edit)
	add_focusable(edit)
	
#	add_to_group("_editor_resource_properties")

func _resource_preview(p_path:String, p_preview:Texture, p_smallPreview:Texture, p_objId:int):
	var res = get_edited_object()[get_edited_property()]
	if res == null || not res is Resource || res.get_instance_id() != p_objId || p_preview == null:
		return
	
	preview.margin_left = assign.icon.get_size().x + assign.get_stylebox("normal").get_default_margin(MARGIN_LEFT) + get_constant("hseparation", "Button")
	var thumbnailSize = editorInterface.get_editor_settings().get_setting("filesystem/file_dialog/thumbnail_size")
	assign.rect_min_size = Vector2(preview.margin_left + thumbnailSize, thumbnailSize)
	assign.text = ""
	preview.texture = p_preview
	preview.show()

func _on_edit_pressed():
	show_menu()

func _get_base_type_icon(p_type:String):
	return get_icon(p_type, "EditorIcons") if has_icon(p_type, "EditorIcons") else null

func show_menu(p_pos = null):
	menu.clear()
	var classnames = []
	var icons = []
	var baseScripts
	
	for i in baseTypes:
		if ClassDB.is_class_enabled(i):
			classnames.append(i)
			icons.append(_get_base_type_icon(i))
		for j in ClassDB.get_inheriters_from_class(i):
			if classnames.find(j) >= 0:
				continue
			classnames.append(j)
			icons.append(_get_base_type_icon(j))
	
	if ProjectSettings.has_setting("_global_script_classes"):
		var classData = ProjectSettings.get_setting("_global_script_classes")
		baseScripts = _get_base_scripts()
		var script
		for i in classData:
			script = load(i["path"])
			if script:
				var r = script.new()
				if _is_handle_obj(r, baseScripts):
					classnames.append(i["class"])
		
		if icons.size() < classnames.size():
			if ProjectSettings.has_setting("_global_script_class_icons"):
				var iconData = ProjectSettings.get_setting("_global_script_class_icons")
				var dir = Directory.new()
				for i in range(icons.size(), classnames.size()):
					if iconData.has(classnames[i]) && iconData[classnames[i]] != "" && dir.file_exists(iconData[classnames[i]]):
						icons.append(load(iconData[classnames[i]]))
					else:
						icons.append(null)
			else:
				icons.resize(classnames.size())
	
	if classnames.size() == 0:
		return

	for i in classnames.size():
		if icons[i]:
			menu.add_icon_item(icons[i], classnames[i], TYPE_BASE_ID + i)
		else:
			menu.add_icon_item(_get_resource_icon(), classnames[i], TYPE_BASE_ID + i)
	
	if classnames.size() > 0:
		menu.add_separator()
	menu.add_icon_item(get_icon("Load", "EditorIcons"), tr("Load"), OBJ_MENU_LOAD)
	
	var res = get_edited_object()[get_edited_property()]
	if res != null:
		menu.add_icon_item(get_icon("Edit", "EditorIcons"), tr("Edit"), OBJ_MENU_EDIT)
		menu.add_icon_item(get_icon("Clear", "EditorIcons"), tr("Clear"), OBJ_MENU_CLEAR)
		menu.add_icon_item(get_icon("Duplicate", "EditorIcons"), tr("Make Unique"), OBJ_MENU_MAKE_UNIQUE)
		menu.add_icon_item(get_icon("Save", "EditorIcons"), tr("Save"), OBJ_MENU_SAVE)
		
		var dir = Directory.new()
		if res.resource_path != "" && dir.file_exists(res.resource_path):
			menu.add_separator()
			menu.add_item(tr("Show in FileSystem"), OBJ_MENU_SHOW_IN_FILE_SYSTEM)
	var cb
	var pasteVaild := false
	if ProjectSettings.has_setting("fixCustomResourceType/clipboard"):
		cb = ProjectSettings.get_setting("fixCustomResourceType/clipboard")
		if _is_handle_obj(cb, baseScripts):
			pasteVaild = true
	if res != null || pasteVaild:
		menu.add_separator()
		if res != null:
			menu.add_item(tr("Copy"), OBJ_MENU_COPY)
		
		if pasteVaild:
			menu.add_item(tr("Paste"), OBJ_MENU_PASTE)
	if p_pos == null:
		var rect = edit.get_global_rect()
		menu.set_as_minsize()
		p_pos = rect.end - Vector2(menu.get_combined_minimum_size().x, 0.0)
	menu.popup(Rect2(p_pos, menu.get_combined_minimum_size()))

func _on_menu_id_pressed(p_id):
	match p_id:
		OBJ_MENU_LOAD:
			if !file:
				file = EditorFileDialog.new()
				file.connect("file_selected", self, "_on_file_selected")
				add_child(file)
			file.set_mode(EditorFileDialog.MODE_OPEN_FILE)
#			var extensions := []
#			extensions = ResourceLoader.get_recognized_extensions_for_type(baseType)
			file.clear_filters()
#			for i in extensions:
#				file.add_filter("*." + i + " ; " + i.to_upper())
			file.popup_centered_ratio()
		OBJ_MENU_EDIT:
			var res = get_edited_object()[get_edited_property()]
			if res != null:
				emit_signal("resource_selected", get_edited_property(), res)
		OBJ_MENU_CLEAR:
			emit_changed(get_edited_property(), Object())
			update_property()
		OBJ_MENU_MAKE_UNIQUE:
			var res = get_edited_object()[get_edited_property()]
			if res:
				emit_changed(get_edited_property(), res.duplicate())
				update_property()
		OBJ_MENU_SAVE:
			var res = get_edited_object()[get_edited_property()]
			if res:
				if res.resource_path != "":
					ResourceSaver.save(res.resource_path, res)
				else:
					if !file:
						file = EditorFileDialog.new()
						file.connect("file_selected", self, "_on_file_selected")
						add_child(file)
					file.set_mode(EditorFileDialog.MODE_SAVE_FILE)
#					var extensions := []
#					extensions = ResourceSaver.get_recognized_extensions(res)
					file.clear_filters()
#					for i in extensions:
#						file.add_filter("*." + i + " ; " + i.to_upper())
					file.popup_centered_ratio()
		OBJ_MENU_SHOW_IN_FILE_SYSTEM:
			var res = get_edited_object()[get_edited_property()]
			if res:
				editorInterface.get_file_system_dock().navigate_to_path(res.resource_path)
				editorInterface.get_file_system_dock().get_parent().current_tab = editorInterface.get_file_system_dock().get_index()
		OBJ_MENU_COPY:
			var res = get_edited_object()[get_edited_property()]
			ProjectSettings.set_setting("fixCustomResourceType/clipboard", res)
		OBJ_MENU_PASTE:
			var res = ProjectSettings.get_setting("fixCustomResourceType/clipboard")
			emit_changed(get_edited_property(), res)
			update_property()
		_:
			var classname = menu.get_item_text(menu.get_item_index(p_id))
			var res
			if ClassDB.class_exists(classname):
				if ClassDB.can_instance(classname):
					res = ClassDB.instance(classname)
			elif ProjectSettings.has_setting("_global_script_classes"):
				var classData = ProjectSettings.get_setting("_global_script_classes")
				for i in classData:
					if i["class"] == classname:
						res = load(i["path"]).new()
						break
			if res:
				emit_changed(get_edited_property(), res)
				update_property()

func _on_file_selected(p_path:String):
	if file.get_mode() == EditorFileDialog.MODE_SAVE_FILE:
		var res = get_edited_object()[get_edited_property()]
		if res:
			ResourceSaver.save(p_path, res)
	else:
		var res = ResourceLoader.load(p_path)
		if res:
			emit_changed(get_edited_property(), res)
			update_property()

func _on_buttons_input(p_event):
	if p_event is InputEventMouseButton:
		if p_event.button_index == BUTTON_RIGHT && not p_event.pressed:
			show_menu(get_global_mouse_position())

func _on_assign_pressed():
	var res = get_edited_object()[get_edited_property()]
	if res == null:
		edit.pressed = true
		show_menu()
	else:
		emit_signal("resource_selected", get_edited_property(), res)
		editorInterface.get_inspector().refresh()
		editorInterface.get_inspector().queue_sort()

func _get_base_scripts():
	var ret = []
	if ProjectSettings.has_setting("_global_script_classes"):	
		var classData = ProjectSettings.get_setting("_global_script_classes")
		for i in classData:
			if i["class"] in customBaseTypes:
				ret.append(load(i["path"]))
	return ret

func _is_handle_obj(p_res, p_baseScripts = null) -> bool:
	if p_res == null || not p_res is Resource:
		return false
	
	for i in baseTypes:
		if p_res.get_class() == i || ClassDB.is_parent_class(p_res.get_class(), i):
			return true
	
	if p_baseScripts == null:
		p_baseScripts = _get_base_scripts()
	
	for i in p_baseScripts:
		if p_res is i:
			return true
	
	return false

func _is_drop_valid(p_data:Dictionary) -> bool:
	if p_data.has("type"):
		var res
		if String(p_data["type"]) == "resource":
			res = p_data["resource"]
		elif String(p_data["type"] == "files"):
			var files = p_data["files"]
			if files.size() == 1:
				res = ResourceLoader.load(files[0])
		return _is_handle_obj(res)
	return false

func can_drop_data_fw(p_position, p_data, p_from):
	return _is_drop_valid(p_data)

func drop_data_fw(p_position, p_data, p_from):
	if !_is_drop_valid(p_data):
		return
	
	if p_data.has("type"):
		if String(p_data["type"]) == "resource":
			emit_changed(get_edited_property(), p_data["resource"])
		elif String(p_data["type"]) == "files":
			emit_changed(get_edited_property(), ResourceLoader.load(p_data["files"][0]))
		update_property()

func get_drag_data_fw(p_position, p_from):
	var res = get_edited_object()[get_edited_property()]
	if res:
		var dragPreview = Control.new()
		var tex = get_icon("FileBigThumb", "EditorIcons")
		var img = tex.get_data().duplicate()
		img.resize(48, 48)
		var imgTex = ImageTexture.new()
		imgTex.create_from_image(img)
		var icon = TextureRect.new()
		icon.texture = imgTex
		dragPreview.add_child(icon)
		var text = Label.new()
		if res.resource_path != "":
			text.text = res.resource_path.get_file()
		elif res.resource_name != "":
			text.text = res.resource_name
		elif res.get_script() != null && ProjectSettings.has_setting("_global_script_classes"):
			var classData = ProjectSettings.get_setting("_global_script_classes")
			for i in classData:
				if i["path"] == res.get_script().get_path():
					text.text = i["class"]
					break
		else:
			text.text = res.get_class()
		dragPreview.add_child(text)
		set_drag_preview(dragPreview)
		text.rect_position = Vector2((icon.rect_size.x - text.get_minimum_size()) / 2.0, icon.rect_size.y)
		return { "type":"resource", "resource":res, "from":p_from }
	return null

func setup(p_baseTypes:Array, p_customBaseTypes:Array):
	baseTypes = p_baseTypes
	customBaseTypes = p_customBaseTypes

func _get_resource_icon():
	return get_icon("ResourcePreloader", "EditorIcons") if has_icon("ResourcePreloader", "EditorIcons") else null

func update_property():
	var res = get_edited_object()[get_edited_property()]
	if res == null || not res is Resource:
		assign.icon = null
		assign.text = tr("[empty]")
	else:
		var classname = ""
		var icon
		if res.get_script() == null:
			classname = res.get_class()
			icon = _get_base_type_icon(classname)
		elif res.get_script() is NativeScript:
			classname = res.get_script().script_class_name
			var dir = Directory.new()
			if dir.file_exists(res.get_script().script_class_icon_path):
				icon = load(res.get_script().script_class_icon_path)
				if not icon is Texture:
					icon = null
		else:
			if ProjectSettings.has_setting("_global_script_classes"):
				var classData = ProjectSettings.get_setting("_global_script_classes")
				for i in classData:
					if i["path"] == res.get_script().get_path():
						classname = i["class"]
						break
				if classname != "" && ProjectSettings.has_setting("_global_script_class_icons"):
					var iconData = ProjectSettings.get_setting("_global_script_class_icons")
					if iconData.has(classname) && iconData[classname] != "":
						icon = load(iconData[classname])
			
			if classname == "":
				classname = "Resource"
		
		if icon == null:
			icon = _get_resource_icon()
		
		assign.icon = icon
		assign.text = classname
		assign.rect_min_size = Vector2.ZERO
		preview.hide()
		
		editorInterface.get_resource_previewer().queue_edited_resource_preview(res, self, "_resource_preview", res.get_instance_id())

func _notification(what):
	if what == NOTIFICATION_ENTER_TREE || what == NOTIFICATION_THEME_CHANGED:
		edit.icon = get_icon("select_arrow", "Tree")
