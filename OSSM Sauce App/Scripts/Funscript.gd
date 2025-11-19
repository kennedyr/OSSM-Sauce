class_name Funscript

extends Node

var TICKS_PER_SECOND:int
var path_speed:int = 30

var _marker_data: Dictionary
var paths:PackedFloat32Array
var markers:Dictionary
var network_paths:Array
var chapters:Array
var PATH_TOP
var PATH_BOTTOM


func _init(filePath: String, ticks_per_second: int, path_top: float, path_bottom: float):
	TICKS_PER_SECOND = ticks_per_second
	PATH_TOP = path_top
	PATH_BOTTOM = path_bottom
	load_path(filePath)


func load_path(filePath:String) -> bool:
	var file_data = parse_file(filePath)
	_marker_data = file_data.actions
	var marker_data = _marker_data
	if not marker_data:
		printerr("Error: Failed to read file.")
		return false
	if marker_data.size() < 6:
		printerr("Error: Insufficient path data in file.")
		return false

	network_paths = create_network_packets(marker_data)
	create_path_lines(marker_data)
	chapters = create_chapters(file_data.chapters)

	return true


func parse_file(filePath: String) -> Dictionary:
	var file_data:Dictionary
	var chapt:Array
	var file = FileAccess.open(filePath, FileAccess.READ)
	var is_funscript = filePath.ends_with(".funscript")

	if file:
		if is_funscript:
			var file_text = file.get_as_text().replace("\n", "")
			var temp_file_data:Dictionary = JSON.parse_string(file_text)
			var action_data: Array
			if "actions" in temp_file_data:
				action_data = temp_file_data["actions"]
			elif "Actions" in temp_file_data:
				action_data = temp_file_data["Actions"]
			elif "rawActions" in temp_file_data:
				action_data = temp_file_data["rawActions"]
			elif "RawActions" in temp_file_data:
				action_data = temp_file_data["RawActions"]
			else:
				print("No actions data found in the funscript")

			if "metadata" in temp_file_data:
				var meta = temp_file_data["metadata"]
				if "chapters" in meta:
					chapt = meta["chapters"]
				
			if action_data:
				var actions_list = action_data
				var trans: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 1)
				@warning_ignore("shadowed_global_identifier")
				var ease: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2)
				file_data[0] = [0, trans, ease, 0]
				for action in actions_list:
					var frame: int = action.at / 16.66666
					var depth = round_to(clamp(action.pos / 100, 0, 1), 4)
					var aux = 0
					file_data[frame] = [depth, trans, ease, aux]
			else:
				print("Failed to parse funscript JSON")
		else:
			file_data = JSON.parse_string(file.get_line())
			if not file_data:
				printerr("Error: No JSON data found in file.")
	file.close()

	return { 
		"actions": file_data,
		"chapters": chapt
	}


func create_network_packets(marker_data: Dictionary):
	var previous_ms_timing:int
	var network_packets:Array
	for marker_frame in marker_data.keys():
		var ms_timing = round((float(marker_frame) / 60) * 1000)
		
		# override trans type for very short transitions
		if previous_ms_timing and ms_timing - previous_ms_timing <= 125:
			marker_data[marker_frame][1] = 0

		var depth = marker_data[marker_frame][0]
		var trans = marker_data[marker_frame][1]
		@warning_ignore("shadowed_global_identifier")
		var ease = marker_data[marker_frame][2]
		var auxiliary:int = marker_data[marker_frame][3]
		
		var network_packet = OSSMCommand.create_move_command(ms_timing, Util.safe_map_physical_position(depth), trans, ease, auxiliary)
		#if auxiliary & 1 << 1:
			#network_packet.resize(13)
			#network_packet.encode_u8(0, OSSM.Command.VIBRATE)
			#network_packet.encode_s32(1, -1)
			#network_packet.encode_u32(5, 10)
			#network_packet.encode_u16(9, round(remap(depth, 0, 1, 0, 10000)))
			#network_packet.encode_u8(11, 5)
			#network_packet.encode_u8(12, 100)
		#else:
		network_packets.append(network_packet)
		
		#adjusting for physics tick rate change from BounceX (60Hz to 50Hz)
		marker_data[round(int(marker_frame) / 1.2)] = marker_data[marker_frame]
		marker_data.erase(marker_frame)
		previous_ms_timing = ms_timing

	return network_packets


func create_path_lines(marker_data: Dictionary):
	var previous_depth:float
	var previous_frame:int
	var marker_list:Array = marker_data.keys()
	var path:PackedFloat32Array
	var path_new:Dictionary
	marker_list.sort()
	for marker_frame in marker_list:
		var depth = marker_data[marker_frame][0]
		var trans = marker_data[marker_frame][1]
		@warning_ignore("shadowed_global_identifier")
		var ease = marker_data[marker_frame][2]
		@warning_ignore("unused_variable")
		var auxiliary = marker_data[marker_frame][3]
		if marker_frame > 0:
			var steps:int = marker_frame - previous_frame
			var duration = (float(steps) / TICKS_PER_SECOND) * 1000
			var scaled_depth:int = round(clamp(depth, 0, 0.9999) * 10000)
			var headers:String = "M%sD%sT%sE%s"
			var message:String = headers%[scaled_depth, duration, trans, ease]
			path_new[previous_frame] = message
			for step in steps:
				var step_depth:float = Tween.interpolate_value(
						previous_depth,
						depth - previous_depth,
						step,
						steps,
						trans,
						ease)
				path.append(step_depth)
		previous_depth = depth
		previous_frame = marker_frame
	
	paths = path
	markers = path_new


@warning_ignore("shadowed_variable")
func create_chapters(chappy: Array):
	var chapters = chappy if chappy else []
	for chapter in chapters:
		chapter['chapterBeginSeconds'] = parse_time(chapter.startTime)
	chapters.sort_custom(chapter_sorter)

	return chapters


func chapter_sorter(a, b) -> bool:
	if a['chapterBeginSeconds'] < b['chapterBeginSeconds']:
		return true
	return false


func round_to(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor


func render_depth(depth) -> float:
	return PATH_BOTTOM + depth * (PATH_TOP - PATH_BOTTOM)


func _find_prev_marker_for_frame(frame: int):
	var marker_list_keys = markers.keys()
	var future_keys = marker_list_keys.filter(func(number): return number >= frame)
	future_keys.sort()
	var next_marker_frame = future_keys.pop_front()
	var next_marker_frame_index = marker_list_keys.find(next_marker_frame)
	if (next_marker_frame_index > 0):
		return next_marker_frame_index - 1
	return 0


func parse_time(time_string: String):
	var segments: PackedStringArray = time_string.split(":")
	var length = segments.size()
	var seconds
	var minutes
	var hours
	if length >= 1:
		seconds = segments[length - 1]
	if length >= 2:
		minutes = segments[length - 2]
	if length >= 3:
		hours = segments[length - 3]

	return float(seconds) + int(minutes) * 60 + int(hours) * 60 * 60


func get_current_chapter_name(ms_timing: int):
	var seconds: float = ms_timing / 1000.0
	var chapterName = ""
	for chapter in chapters:
		if seconds >= chapter['chapterBeginSeconds']:
			chapterName = chapter['name']
		
	return chapterName
	
