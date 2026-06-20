class_name MPV

extends Node


static func play():
	# Sleep for 0.2s to sync
	#await get_tree().create_timer(0.2).timeout
	#
	print("playing")
	var command = r'echo { "command": ["set_property", "pause", false] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", command])


static func pause():
	print("pausing")
	var command = r'echo { "command": ["set_property", "pause", true] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", command])


static func restart():
	pause()
	seek_to(0)


static func seek_to(time_ms: int):
	var seconds = time_ms / 1000.0
	print("seek to ", "%.4f" % seconds)
	var commandSeek = r'echo { "command": ["seek", ' + ("%.4f" % seconds) + r', "absolute"] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", commandSeek])


static func try_load_video(file_path:String):
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


static func _load_video(path:String):
	print("loading ", path)
	var command = r'mpv "' + path + r'"'
	OS.create_process("cmd", ["/c", command])
