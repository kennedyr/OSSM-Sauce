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


static func scale_physical_depth(depth: float, range_min: int, range_max: int):
	var constrained_position = safe_map_physical_position(depth)
	return remap(constrained_position, 0, 10000, range_min, range_max)


static func get_base_move_speed_hz(action: Marker, prev_action: Marker, range_min: int, range_max: int):
	var target_position = scale_physical_depth(action.depth, range_min, range_max)
	var prev_position = scale_physical_depth(prev_action.depth, range_min, range_max)
	var move_delta = target_position - prev_position
	var move_duration = action.at - prev_action.at
	var linear_speed = abs(move_delta) / (move_duration * 0.001);
	return linear_speed


# Amplify base move speed to match traversal time with linear move
static func get_move_speed_hz(target_position, prev_position, move_duration: int, trans_type = OSSM.TransType.LINEAR):
	var move_delta = target_position - prev_position
	var linear_speed = abs(move_delta) / (move_duration * 0.001);
	var speed = round(linear_speed * get_trans_type_multiplier(trans_type))
	return speed


static func get_trans_type_multiplier(trans_type):
	match trans_type:
		OSSM.TransType.SINE:
			return 2.73
		OSSM.TransType.CIRC:
			return 4.46
		OSSM.TransType.EXPO:
			return 6.9
		OSSM.TransType.QUAD:
			return 2.98
		OSSM.TransType.CUBIC:
			return 3.9
		OSSM.TransType.QUART:
			return 4.85
		OSSM.TransType.QUINT:
			return 5.79
		_:
			return 1


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
