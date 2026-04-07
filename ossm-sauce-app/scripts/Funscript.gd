class_name Funscript

extends Node

var TICKS_PER_SECOND:int
var path_speed:int = 30

var _marker_data: Dictionary
var paths:PackedFloat32Array
var marker_frames:Dictionary
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
	var parsed_data = parse_file(filePath)
	var is_funscript = filePath.ends_with(".funscript")
	var file_data = parsed_data
	if is_funscript:
		file_data = map_funscript_data(parsed_data)
	else:
		file_data = map_other_data(parsed_data)
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
	chapters = create_chapters(file_data.chapters, parsed_data.actions.back().at)

	return true


func parse_file(filePath: String) -> Dictionary:
	var file_data:Dictionary
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file:
		var file_text = file.get_as_text().replace("\n", "")
		file_data = JSON.parse_string(file_text)
		if not file_data:
			printerr("Error: No JSON data found in file.")
	file.close()		

	return file_data

	
func map_funscript_data(parsed_data: Dictionary) -> Dictionary:
	var file_data:Dictionary
	var chapt:Array
	var inverted := false

	if parsed_data:
		var action_data: Array
		if "actions" in parsed_data:
			action_data = parsed_data["actions"]
		elif "Actions" in parsed_data:
			action_data = parsed_data["Actions"]
		elif "rawActions" in parsed_data:
			action_data = parsed_data["rawActions"]
		elif "RawActions" in parsed_data:
			action_data = parsed_data["RawActions"]
		else:
			print("No actions data found in the funscript")

		if parsed_data.get("inverted", false):
			inverted = true
		if "metadata" in parsed_data:
			var meta = parsed_data["metadata"]
			if "chapters" in meta:
				chapt = meta["chapters"]
			
		if action_data:
			var actions_list = action_data
			var first_depth = round_to(clamp(actions_list[0].pos / 100, 0, 1), 4)
			if inverted:
				first_depth = round_to(1.0 - first_depth, 4)
			var trans: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 1)
			@warning_ignore("shadowed_global_identifier")
			var ease: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2)
			file_data[0] = [first_depth, trans, ease, 0]
			for action in actions_list:
				var frame: int = action.at / (1000.0 / 60.0)
				var depth = round_to(clamp(action.pos / 100, 0, 1), 4)
				if inverted:
					depth = round_to(1.0 - depth, 4)
				var aux = 0
				file_data[frame] = [depth, trans, ease, aux]

		else:
			print("Failed to parse funscript JSON")

	return { 
		"actions": file_data,
		"chapters": chapt
	}


func map_other_data(parsed_data: Dictionary) -> Dictionary:
	if parsed_data:
	if parsed_data.has("meta"):
		var meta = file_data["meta"]
		if meta is Dictionary and meta.has("video_offset_ms"):
			%VideoPlayer/Main/VideoOffset/Input.value = meta["video_offset_ms"]

	return { 
		"actions": file_data["markers"],
		"chapters": []
	}
	
func create_network_packets(marker_data: Dictionary):
	var previous_ms_timing:int
	var network_packets: Array

	var sorted_keys := marker_data.keys()
	sorted_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	for marker_frame in sorted_keys:
		var marker = marker_data[marker_frame]
		var ms_timing := int(round((float(marker_frame) / 60) * 1000))
		
		# override trans type for very short transitions
		if previous_ms_timing and ms_timing - previous_ms_timing <= 125:
			marker[1] = 0

		var depth = marker[0]
		var trans = marker[1]
		@warning_ignore("shadowed_global_identifier")
		var ease = marker[2]
		var auxiliary:int = marker[3]
		var network_packet = OSSMCommand.create_move_command(ms_timing, Util.safe_map_physical_position(depth), trans, ease, auxiliary)
		network_packets.append(network_packet)
		# Adjust for physics tick rate change from BounceX (60Hz to 50Hz)
		marker_data[round(int(marker_frame) / 1.2)] = marker
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
	marker_frames = path_new


func format_time(msTime: int):
	var hours = int(msTime / 3600000.0)
	var remainder = msTime - hours * 3600000
	var minutes = int(remainder / 60000.0)
	remainder = remainder - minutes * 60000
	var seconds = int(remainder / 1000.0)
	remainder = remainder - seconds * 1000
	var timeString =  "%d:%d:%d.%d" % [hours, minutes, seconds, remainder]
	return timeString


@warning_ignore("shadowed_variable")
func create_chapters(chappy: Array, lastAt: int):
	var chapters = chappy if chappy else []
	if chappy.is_empty():
		chapters.append({
			"name": "Beginning",
			"startTime": format_time(0),
			"chapterBeginSeconds": 0
		})
		for n in range(300000, lastAt, 300000):
			var minutes = int(n/60000.0)
			chapters.append({
				"name": "%d minutes" % minutes,
				"startTime": "00:%d:00.000" % minutes,
				"chapterBeginSeconds": n / 1000.0
			})
		chapters.append({
			"name": "End",
			"startTime": format_time(lastAt),
			"chapterBeginSeconds": lastAt / 1000.0 - 1
		})
	else:
		for chapter in chapters:
			chapter['chapterBeginSeconds'] = parse_time(chapter.startTime)
			chapter['chapterEndSeconds'] = parse_time(chapter.endTime)
	
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
	var marker_list_keys = marker_frames.keys()
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
			if (!chapter.has('chapterEndSeconds') or seconds < chapter['chapterEndSeconds']):
				chapterName = chapter['name']
		
	return chapterName
	

func get_next_chapter_name(ms_timing: int):
	var seconds: float = ms_timing / 1000.0
	for chapter in chapters:
		if seconds < chapter['chapterBeginSeconds']:
			return chapter['name']
	return ""
