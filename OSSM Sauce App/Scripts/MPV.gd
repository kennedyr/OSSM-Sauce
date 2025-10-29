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


func load(path:String):
	print("loading ", path)
	var command = r'echo { "command": ["loadfile", "' + path + r'"] } > \\.\pipe\mpv-launcher-pipe'
	OS.execute("cmd", ["/c", command])
