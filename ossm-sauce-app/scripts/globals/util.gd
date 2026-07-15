extends Node

class_name Util

const PHYSICAL_RANGE_MIN = 0
const PHYSICAL_RANGE_MAX = 10000

static func safe_map_slider_position(percent: float, min_pos: float, max_pos: float):
	var position_map = remap(percent, 0, 1, min_pos, max_pos)
	var position = round(position_map)
	if min_pos < max_pos:
		return clamp(position, min_pos, max_pos)
	else:
		return clamp(position, max_pos, min_pos)


static func safe_map_slider_percent(slider_pos: float, min_pos: float, max_pos: float):
	var percent_map = remap(slider_pos, min_pos, max_pos, 0, 1)
	var percent = snappedf(percent_map, 0.0001)
	return clamp(percent, 0, 1)
	

static func safe_map_physical_position(percent: float):
	var position_map = remap(percent, 0, 1, PHYSICAL_RANGE_MIN, PHYSICAL_RANGE_MAX)
	var position = round(position_map)
	return clamp(position, PHYSICAL_RANGE_MIN, PHYSICAL_RANGE_MAX)


static func safe_map_value(percent: float, min_value: float, max_value: float):
	var position_map = remap(percent, 0, 1, min_value, max_value)
	var position = round(position_map)
	return clamp(position, min_value, max_value)


static func parse_time(time_string: String) -> float:
	var segments: PackedStringArray = time_string.split(":")
	var length = segments.size()
	var seconds = 0
	var minutes = 0
	var hours = 0
	if length >= 1:
		seconds = segments[length - 1]
	if length >= 2:
		minutes = segments[length - 2]
	if length >= 3:
		hours = segments[length - 3]

	return float(seconds) + int(minutes) * 60 + int(hours) * 3600


func format_time(msTime: int) -> String:
	var hours = int(msTime / 3600000.0)
	var remainder = msTime - hours * 3600000
	var minutes = int(remainder / 60000.0)
	remainder = remainder - minutes * 60000
	var seconds = int(remainder / 1000.0)
	remainder = remainder - seconds * 1000
	var timeString = "%d:%d:%d.%d" % [hours, minutes, seconds, remainder]
	return timeString
