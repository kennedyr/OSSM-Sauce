extends Panel

var mode = "PATH";

func _ready() -> void:
	$FileDialog.file_selected.connect(_on_file_selected)
	$FileDialog.canceled.connect(_on_cancel)


func show_paths():
	show()
	mode = "PATH"
	$FileDialog.clear_filters()
	$HBox/AddPath.disabled = true
	$HBox/AddPath.show()
	$HBox/LoadPlaylist.hide()
	$FileDialog.current_dir = owner.paths_dir
	$FileDialog.filename_filter = "*.funscript"
	$FileDialog.show()


func show_playlists():
	show()
	mode = "PLAYLIST"
	$FileDialog.clear_filters()
	$HBox/LoadPlaylist.disabled = true
	$HBox/LoadPlaylist.show()
	$HBox/AddPath.hide()
	$FileDialog.current_dir = owner.playlists_dir
	$FileDialog.filename_filter = "*.bxpl"
	$FileDialog.show()


func _on_cancel():
	$HBox/AddPath.disabled = false
	%Menu.show()
	hide()


func _on_file_selected(path: String):
	$HBox/AddPath.disabled = false
	if mode == "PLAYLIST":
		_on_load_playlist(path)
	else:
		_on_add_path(path)
	%Menu.show()
	hide()


func _on_add_path(file_path: String):
	if owner.load_path(file_path):
		%Menu/Playlist.add_item(file_path.get_file(), file_path)


func _on_load_playlist(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	%Menu/Playlist.clear()
	while file.get_position() < file.get_length():
		var line:String = file.get_line()
		if line.begins_with('delay(') and line.ends_with(')'):
			var begin_index = line.find("(") + 1
			var end_index = line.find(")") - begin_index
			var delay_duration = float(line.substr(begin_index, end_index))
			owner.create_delay(delay_duration)
		elif owner.load_path(line):
			%Menu/Playlist.add_item(line.get_file(), line)
	owner.send_command(OSSM.Command.RESET)


func _on_back_pressed():
	$FileDialog.hide()
	%Menu.show()
	hide()
