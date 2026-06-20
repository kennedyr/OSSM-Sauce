extends Panel

var lastPath = null;
var lastPlaylist = null;

func _ready() -> void:
	self_modulate.a = 2
	if OS.get_name() != 'Android':
		$FileDialog.file_selected.connect(_on_file_selected)
		$FileDialog.canceled.connect(_on_cancel)

func create_file_list(category: String, file_types: PackedStringArray):
	for file_name in %FileUtil.list_files(category, file_types):
		$FileList.add_item(file_name)


func show_paths():
	$FileList.clear()
	$FileList.mode = $FileList.Mode.PATH
	$HBox/AddPath.disabled = true
	$HBox/AddPath.show()
	$HBox/LoadPlaylist.hide()

	if OS.get_name() != 'Android':
		$FileDialog.clear_filters()
		$FileDialog.current_dir = lastPath if lastPath else Global.paths_dir
		$FileDialog.filters = ["*.funscript"]
		$FileDialog.show()
	else:
		show()
		create_file_list("paths", [".bx", ".funscript"])
		$Label.text = %FileUtil.get_storage_label("paths")


func show_playlists():
	$FileList.clear()
	$FileList.mode = $FileList.Mode.PLAYLIST
	$HBox/LoadPlaylist.disabled = true
	$HBox/LoadPlaylist.show()
	$HBox/AddPath.hide()

	if OS.get_name() != 'Android':
		$FileDialog.clear_filters()
		$FileDialog.current_dir = lastPlaylist if lastPlaylist else Global.playlists_dir
		$FileDialog.filters = ["*.bxpl"]
		$FileDialog.show()
	else:
		show()
		create_file_list("playlists", [".bxpl"])
		$Label.text = %FileUtil.get_storage_label("playlists")


func _on_file_selected(path: String):
	$HBox/AddPath.disabled = false
	if $FileList.mode == $FileList.Mode.PLAYLIST:
		_on_load_playlist(path)
	else:
		_on_add_path(path)
	close()


func _on_add_path_pressed():
	var file_name: String = $FileList.get_item_text($FileList.selected_index)
	if owner.load_path(file_name):
		%Menu/Playlist.add_item(file_name)
	close()


func _on_add_path(file_path: String):
	lastPath = file_path.get_base_dir()
	if owner.load_path(file_path):
		%Menu/Playlist.add_item(file_path.get_file(), file_path)


func _on_cancel():
	close()
func _on_load_playlist_pressed():
	var file_name: String = $FileList.get_item_text($FileList.selected_index)
	_on_load_playlist(file_name)

func _on_load_playlist(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	lastPlaylist = file_path.get_base_dir()
	%Menu/Playlist.clear()
	while file.get_position() < file.get_length():
		var line: String = file.get_line()
		if line.begins_with('delay(') and line.ends_with(')'):
			var begin_index = line.find("(") + 1
			var end_index = line.find(")") - begin_index
			var delay_duration = float(line.substr(begin_index, end_index))
			owner.create_delay(delay_duration)
		elif owner.load_path(line):
			%Menu/Playlist.add_item(line.get_file(), line)
	%OSSMCommand.reset()
	close()


func _on_back_pressed():
	close()

func close():
	$HBox/AddPath.disabled = false
	if OS.get_name() != 'Android':
		$FileDialog.hide()
	else:
		hide()
	%Menu.show()
