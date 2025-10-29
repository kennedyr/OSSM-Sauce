extends Node

class_name Util

const PHYSICAL_RANGE_MIN = 0
const PHYSICAL_RANGE_MAX = 10000

static func safe_map_slider_position(percent:float, min_pos:float, max_pos:float):
	var position_map = remap(percent, 0, 1, min_pos, max_pos)
	var position = round(position_map)
	return position


static func safe_map_slider_percent(slider_pos:float, min_pos:float, max_pos:float):
	var percent_map = remap(slider_pos, min_pos, max_pos, 0, 1)
	var percent = snappedf(percent_map, 0.0001)
	return percent
	

static func safe_map_physical_position(percent:float):
	var position_map = remap(percent, 0, 1, PHYSICAL_RANGE_MIN, PHYSICAL_RANGE_MAX)
	var position = round(position_map)
	return clamp(position, PHYSICAL_RANGE_MIN, PHYSICAL_RANGE_MAX)


static func safe_map_value(percent:float, min_value:float, max_value:float):
	var position_map = remap(percent, 0, 1, min_value, max_value)
	var position = round(position_map)
	return clamp(position, min_value, max_value)
