class_name UserSettings
extends Node

enum Section {
	app_settings,
	device_settings,
	window,
	network,
	stroke_settings,
	speed_slider,
	accel_slider,
	range_slider_min,
	range_slider_max,
	buttplug,
	bridge_settings,
	bpio_settings,
	xtoys_settings,
	mcp_settings
}

static var _user_settings_path: String = ""
static var _user_settings: ConfigFile = null
static var user_settings: ConfigFile:
	get:
		if _user_settings == null:
			initialize() 
		return _user_settings


func _init():
	initialize()


static func initialize():
	if _user_settings == null:
		var storage_dir: String
		if OS.get_name() == 'Android':
			storage_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
		else:
			storage_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		_user_settings_path = storage_dir + "/OSSM Sauce/UserSettings.cfg"

		_user_settings = ConfigFile.new()
		_user_settings.load(_user_settings_path)
	return _user_settings

static func get_value(section: Section, key: String, default: Variant = ""):
	var sectionKey = Section.keys()[section]
	return user_settings.get_value(sectionKey, key, default)

static func set_value(section: Section, key: String, value: Variant):
	var sectionKey = Section.keys()[section]
	user_settings.set_value(sectionKey, key, value)

static func clear():
	user_settings.clear()

static func save():
	user_settings.save(_user_settings_path)
