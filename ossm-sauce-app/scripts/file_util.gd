class_name FileUtil

extends Node

const SAF_CONFIG_PATH := "user://saf_storage.cfg"
var saf_storage := ConfigFile.new()
var saf_paths_uri: String = ""
var saf_mpv_bridge_uri: String = ""
var _saf_paths_subdir_exists: bool = false
var _saf_playlists_subdir_exists: bool = false
var _saf_file_subdirs: Dictionary = {}


func check_root_directory():
	if OS.get_name() == 'Android':
		return
	var dir = DirAccess.open(Global.storage_dir)
	if not dir.dir_exists("OSSM Sauce"):
		dir.make_dir("OSSM Sauce")
	dir.change_dir("OSSM Sauce")
	for directory in ["Paths", "Playlists"]:
		if not dir.dir_exists(directory):
			dir.make_dir(directory)


func check_storage_setup() -> bool:
	if OS.get_name() != 'Android':
		return true
	saf_paths_uri = _load_saf_paths_uri()
	saf_mpv_bridge_uri = _load_saf_mpv_bridge_uri()
	_refresh_saf_subdirs()
	return !saf_paths_uri.is_empty()


func storage_folder_picked(paths: PackedStringArray) -> void:
	if paths.is_empty():
		return
	saf_paths_uri = paths[0]
	_save_saf_paths_uri(saf_paths_uri)
	take_persistable_uri_permission(saf_paths_uri)
	_refresh_saf_subdirs()


func _handle_dead_saf_grant() -> void:
	push_warning("SAF grant on saved URI is dead, clearing and re-prompting")
	saf_paths_uri = ""
	_save_saf_paths_uri("")
	_saf_file_subdirs.clear()
	_saf_paths_subdir_exists = false
	_saf_playlists_subdir_exists = false
	owner.show_pick_storage_folder()


func take_persistable_uri_permission(uri_str: String) -> void:
	if OS.get_name() != 'Android' or uri_str.is_empty():
		return
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var ActivityThread = JavaClassWrapper.wrap("android.app.ActivityThread")
	if Uri == null or Intent == null or ActivityThread == null:
		return
	var uri_obj = Uri.parse(uri_str)
	var flags = Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_GRANT_WRITE_URI_PERMISSION
	var resolver = ActivityThread.currentActivityThread().getApplication().getContentResolver()
	resolver.takePersistableUriPermission(uri_obj, flags)


func _load_saf_paths_uri() -> String:
	if not FileAccess.file_exists(SAF_CONFIG_PATH):
		return ""
	if saf_storage.load(SAF_CONFIG_PATH) != OK:
		return ""
	return saf_storage.get_value("storage", "paths_uri", "")


func _save_saf_paths_uri(uri: String) -> void:
	saf_storage.set_value("storage", "paths_uri", uri)
	saf_storage.save(SAF_CONFIG_PATH)


func _load_saf_mpv_bridge_uri() -> String:
	if not FileAccess.file_exists(SAF_CONFIG_PATH):
		return ""
	if saf_storage.load(SAF_CONFIG_PATH) != OK:
		return ""
	return saf_storage.get_value("storage", "mpv_bridge_uri", "")


func save_saf_mpv_bridge_uri(uri: String) -> void:
	saf_storage.set_value("storage", "mpv_bridge_uri", uri)
	saf_storage.save(SAF_CONFIG_PATH)


# func paths_open_read(file_name: String) -> FileAccess:
	# return FileAccess.open(_resolve_storage_path(file_name, "paths"), FileAccess.READ)


# func playlists_open_read(file_name: String) -> FileAccess:
	# return FileAccess.open(_resolve_storage_path(file_name, "playlists"), FileAccess.READ)


func playlists_open_write(file_name: String) -> FileAccess:
	if OS.get_name() == 'Android' and _saf_playlists_subdir_exists:
		_saf_file_subdirs[file_name] = "Playlists"
	return FileAccess.open(_resolve_storage_path(file_name, "playlists"), FileAccess.WRITE)


func list_files(category: String, extensions: PackedStringArray) -> PackedStringArray:
	if OS.get_name() == 'Android':
		return _list_files_saf(extensions, category)
	
	var result: PackedStringArray = []
	var dir_path := _resolve_storage_dir(category)
	if dir_path.is_empty():
		return result
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	for file_name in dir.get_files():
		for ext in extensions:
			if file_name.ends_with(ext):
				result.append(file_name)
				break
	return result


# Detects whether legacy "Paths" and "Playlists" subdirs exist at the SAF
# tree root. Called at startup and after folder pick so the existence flags
# are correct before any list_files or write call.
func _refresh_saf_subdirs() -> void:
	_saf_paths_subdir_exists = false
	_saf_playlists_subdir_exists = false
	if OS.get_name() != 'Android' or saf_paths_uri.is_empty():
		return
	
	var DocumentsContract = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var ActivityThread = JavaClassWrapper.wrap("android.app.ActivityThread")
	if DocumentsContract == null or Uri == null or ActivityThread == null:
		return
	var tree_uri_obj = Uri.parse(saf_paths_uri)
	if tree_uri_obj == null:
		return
	var root_doc_id = DocumentsContract.getTreeDocumentId(tree_uri_obj)
	var children_uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree_uri_obj, root_doc_id)
	if children_uri == null:
		return
	var resolver = ActivityThread.currentActivityThread().getApplication().getContentResolver()
	var cursor = resolver.query(children_uri,
			PackedStringArray(["_display_name", "mime_type"]),
			"", PackedStringArray(), "", null)
	if cursor == null:
		return
	var name_col = cursor.getColumnIndex("_display_name")
	var mime_col = cursor.getColumnIndex("mime_type")
	while cursor.moveToNext():
		if cursor.getString(mime_col) == "vnd.android.document/directory":
			match cursor.getString(name_col):
				"Paths": _saf_paths_subdir_exists = true
				"Playlists": _saf_playlists_subdir_exists = true
	cursor.close()


func _list_files_saf(extensions: PackedStringArray, category: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if saf_paths_uri.is_empty():
		return result
	
	var DocumentsContract = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var ActivityThread = JavaClassWrapper.wrap("android.app.ActivityThread")
	if DocumentsContract == null or Uri == null or ActivityThread == null:
		return result
	
	var tree_uri_obj = Uri.parse(saf_paths_uri)
	if tree_uri_obj == null:
		return result
	
	var current_thread = ActivityThread.currentActivityThread()
	if current_thread == null:
		return result
	var app = current_thread.getApplication()
	if app == null:
		return result
	var resolver = app.getContentResolver()
	if resolver == null:
		return result
	
	var subdir_name := "Paths" if category == "paths" else "Playlists"
	var root_doc_id = DocumentsContract.getTreeDocumentId(tree_uri_obj)
	var root_children_uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree_uri_obj, root_doc_id)
	if root_children_uri == null:
		return result
	
	# Pass 1: scan root for matching files; record the relevant subdir's
	# document_id if found; opportunistically refresh both existence flags.
	var cursor = resolver.query(root_children_uri,
			PackedStringArray(["_display_name", "mime_type", "document_id"]),
			"", PackedStringArray(), "", null)
	if cursor == null:
		_handle_dead_saf_grant()
		return result
	
	var combined: Dictionary = {}
	var name_col = cursor.getColumnIndex("_display_name")
	var mime_col = cursor.getColumnIndex("mime_type")
	var id_col = cursor.getColumnIndex("document_id")
	var subdir_doc_id := ""
	while cursor.moveToNext():
		var _name: String = cursor.getString(name_col)
		var mime: String = cursor.getString(mime_col)
		if mime == "vnd.android.document/directory":
			match _name:
				"Paths": _saf_paths_subdir_exists = true
				"Playlists": _saf_playlists_subdir_exists = true
			if _name == subdir_name:
				subdir_doc_id = cursor.getString(id_col)
		else:
			for ext in extensions:
				if _name.ends_with(ext):
					combined[_name] = ""
					break
	cursor.close()
	
	# Pass 2: scan the category subdir if present. Subdir entries override
	# root entries (per design: "subdir wins" on name conflict).
	if not subdir_doc_id.is_empty():
		var sub_children_uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree_uri_obj, subdir_doc_id)
		if sub_children_uri != null:
			var sub_cursor = resolver.query(sub_children_uri,
					PackedStringArray(["_display_name"]),
					"", PackedStringArray(), "", null)
			if sub_cursor != null:
				var sub_name_col = sub_cursor.getColumnIndex("_display_name")
				while sub_cursor.moveToNext():
					var _name: String = sub_cursor.getString(sub_name_col)
					for ext in extensions:
						if _name.ends_with(ext):
							combined[_name] = subdir_name
							break
				sub_cursor.close()
	
	for _name in combined:
		_saf_file_subdirs[_name] = combined[_name]
		result.append(_name)
	return result


func _resolve_storage_path(file_name: String, category: String) -> String:
	if OS.get_name() == 'Android':
		if saf_paths_uri.is_empty():
			return ""
		var subdir: String = _saf_file_subdirs.get(file_name, "")
		if subdir.is_empty():
			return saf_paths_uri + "#" + file_name
		return saf_paths_uri + "#" + subdir + "/" + file_name
	return _resolve_storage_dir(category) + file_name


func _resolve_storage_dir(category: String) -> String:
	if OS.get_name() == 'Android':
		if saf_paths_uri.is_empty():
			return ""
		return _saf_tree_uri_to_fs_path(saf_paths_uri)
	return Global.paths_dir if category == "paths" else Global.playlists_dir


func _saf_tree_uri_to_fs_path(tree_uri: String) -> String:
	var prefix := "content://com.android.externalstorage.documents/tree/"
	if not tree_uri.begins_with(prefix):
		return ""
	var doc_id := tree_uri.substr(prefix.length()).uri_decode()
	var colon := doc_id.find(":")
	if colon < 0:
		return ""
	var volume := doc_id.substr(0, colon)
	var rel_path := doc_id.substr(colon + 1)
	if volume == "primary":
		return "/storage/emulated/0/" + rel_path + "/"
	return "/storage/" + volume + "/" + rel_path + "/"


func get_storage_label(category: String) -> String:
	var subdir_name := "Paths" if category == "paths" else "Playlists"
	if OS.get_name() == 'Android':
		var base := _saf_uri_to_friendly_path(saf_paths_uri)
		if base.is_empty():
			return ""
		var subdir_present := _saf_paths_subdir_exists if category == "paths" \
				else _saf_playlists_subdir_exists
		return base + "/" + subdir_name if subdir_present else base
	return "Documents/OSSM Sauce/" + subdir_name


func _saf_uri_to_friendly_path(tree_uri: String) -> String:
	var prefix := "content://com.android.externalstorage.documents/tree/"
	if not tree_uri.begins_with(prefix):
		return ""
	var doc_id := tree_uri.substr(prefix.length()).uri_decode()
	var colon := doc_id.find(":")
	if colon < 0:
		return ""
	var volume := doc_id.substr(0, colon)
	var rel_path := doc_id.substr(colon + 1)
	if volume == "primary":
		return "Internal Storage/" + rel_path
	return volume + "/" + rel_path
