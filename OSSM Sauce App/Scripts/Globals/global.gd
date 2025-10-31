extends Node

const ANIM_TIME = 0.65

var paused:bool = true
var active_path_index
var frame:int

var max_speed:int = 25000
var max_acceleration:int = 500000

var min_stroke_duration:float
var max_stroke_duration:float

signal homing_complete


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
