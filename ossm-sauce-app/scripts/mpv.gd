extends Node


func play():
	# Sleep for 0.2s to sync
	await get_tree().create_timer(0.2).timeout
	print("playing")
	var command = r'echo { "command": ["set_property", "pause", false] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", command])


func pause():
	print("pausing")
	var command = r'echo { "command": ["set_property", "pause", true] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", command])


func restart():
	print("restarting")
	var commandPause = r'echo { "command": ["set_property", "pause", true] } > \\.\pipe\mpv-launcher-pipe'
	var commandSeek = r'echo { "command": ["seek", 0, "absolute"] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", commandPause])
	OS.execute("cmd", ["/c", commandSeek])


func try_load_video(file_path:String):
	var extensionless_path = file_path.get_basename()
	var filePath: String
	var mp4Path = extensionless_path + ".mp4"
	var mkvPath = extensionless_path + ".mkv"
	if FileAccess.file_exists(mp4Path):
		filePath = mp4Path
	elif FileAccess.file_exists(mkvPath):
		filePath = mkvPath
	if filePath:
		_load_video(filePath)	

func _load_video(path:String):
	print("loading ", path)
	#var command = r'mpv "' + path + r'"'
	#OS.execute("cmd", ["/c", command])
