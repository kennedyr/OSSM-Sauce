extends Node

const PHYSICAL_RANGE_MIN = 0
const PHYSICAL_RANGE_MAX = 10000

static func safe_map_slider_value(percent:float, min_value:float, max_value:float):
	var value_map = snappedf(remap(percent, 0, 1, min_value, max_value), 1)
	var value = clamp(value_map, min_value, max_value)
	return value


static func safe_map_slider_percent(slider_pos:float, min_pos:float, max_pos:float):
	var percent_map = snappedf(remap(slider_pos, min_pos, max_pos, 0, 1), 0.01)
	var percent = clamp(percent_map, 0, 1)
	return percent


static func safe_map_physical_position(percent:float):
	var position_map = snappedf(percent * PHYSICAL_RANGE_MAX, 0.1)
	var position = clamp(position_map, PHYSICAL_RANGE_MIN, PHYSICAL_RANGE_MAX)
	return position
