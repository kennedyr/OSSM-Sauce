extends Panel

var mode = "PATH";
var lastPath = null;
var lastPlaylist = null;


func _ready() -> void:
	$FileDialog.file_selected.connect(_on_file_selected)
	$FileDialog.canceled.connect(_on_cancel)


func show_paths():
	mode = "PATH"
	$FileDialog.clear_filters()
	$HBox/AddPath.disabled = true
	$HBox/AddPath.show()
	$HBox/LoadPlaylist.hide()
	$FileDialog.current_dir = lastPath if lastPath else owner.paths_dir
	$FileDialog.filters = ["*.funscript"]
	$FileDialog.show()


func show_playlists():
	mode = "PLAYLIST"
	$FileDialog.clear_filters()
	$HBox/LoadPlaylist.disabled = true
	$HBox/LoadPlaylist.show()
	$HBox/AddPath.hide()
	$FileDialog.current_dir = lastPlaylist if lastPlaylist else owner.playlists_dir
	$FileDialog.filters = ["*.bxpl"]
	$FileDialog.show()


func _on_cancel():
	$HBox/AddPath.disabled = false
	%Menu.show()


func _on_file_selected(path: String):
	$HBox/AddPath.disabled = false
	if mode == "PLAYLIST":
		_on_load_playlist(path)
	else:
		_on_add_path(path)
	%Menu.show()


func _on_add_path(file_path: String):
	lastPath = file_path.get_base_dir()
	if owner.load_path(file_path):
		%Menu/Playlist.add_item(file_path.get_file(), file_path)
		%MPV.try_load_video(file_path)


func _on_load_playlist(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return
	lastPlaylist = file_path.get_base_dir()
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
	%OSSMCommand.reset()


func _on_back_pressed():
	$FileDialog.hide()
	%Menu.show()
