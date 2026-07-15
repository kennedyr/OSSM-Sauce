extends Node

const ANIM_TIME = 0.65
var ticks_per_second: int = 50

var paused: bool = true
var _active_path_index
var active_path_index:
	get:
		return _active_path_index
	set(value):
		_active_path_index = value
		emit_signal("active_path_index_changed")

var frame: int

var max_speed: int = 25000
var speed_limit: int
var max_acceleration: int = 500000
var acceleration_limit: int

var min_stroke_duration: float
var max_stroke_duration: float

var motor_direction: int = 0

var _min_range_limit: int
var min_range_limit:
	get:
		return abs(Global.motor_direction * 10000 - _min_range_limit)
	set(value):
		_min_range_limit = value

var _max_range_limit: int
var max_range_limit:
	get:
		return abs(Global.motor_direction * 10000 - _max_range_limit)
	set(value):
		_max_range_limit = value

var _transition: int = 1
var transition:
	get:
		return _transition
	set(value):
		if value != _transition:
			_transition = value
			emit_signal("transition_changed")

var _easing: int = 2
var easing:
	get:
		return _easing
	set(value):
		if value != _easing:
			_easing = value
			emit_signal("easing_changed")

@warning_ignore("unused_signal")
signal homing_complete
signal active_path_index_changed
signal transition_changed
signal easing_changed


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
