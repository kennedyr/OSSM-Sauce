extends Node

const ANIM_TIME = 0.65

var paused:bool = true
var _active_path_index
var active_path_index:
	get:
		return _active_path_index
	set(value):
		_active_path_index = value
		emit_signal("active_path_index_changed")

var frame:int

var max_speed:int = 25000
var max_acceleration:int = 500000

var min_stroke_duration:float
var max_stroke_duration:float

var _next_play_time_ms
var next_play_time_ms:
	get:
		var value = _next_play_time_ms
		_next_play_time_ms = null
		return value
	set(value):
		_next_play_time_ms = value

signal homing_complete
signal active_path_index_changed


static var storage_dir: String:
	get:
		if OS.get_name() == 'Android':
			return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		else:
			return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)


static var paths_dir: String:
	get:
		return storage_dir + "/OSSM Sauce/Paths/"


static var playlists_dir: String:
	get:
		return storage_dir + "/OSSM Sauce/Playlists/"


static var cfg_path: String:
	get:
		return storage_dir + "/OSSM Sauce/UserSettings.cfg"
