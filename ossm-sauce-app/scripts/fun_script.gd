extends Node

class_name Funscript

var TICKS_PER_SECOND: int
var path_speed: int = 30

var marker_data: Dictionary[int, Array]
var path: PackedFloat32Array
var frames: PackedInt32Array
var network_paths: Array[PackedByteArray]
var chapters: Array
var PATH_TOP
var PATH_BOTTOM


func _init(filePath: String, ticks_per_second: int, path_top: float, path_bottom: float):
	TICKS_PER_SECOND = ticks_per_second
	PATH_TOP = path_top
	PATH_BOTTOM = path_bottom
	load_path(filePath)


func load_path(filePath: String) -> bool:
	var parsed_data = parse_file(filePath)
	var is_funscript = filePath.ends_with(".funscript")
	var file_data: Dictionary
	if is_funscript:
		file_data = map_funscript_data(parsed_data)
	else:
		file_data = map_other_data(parsed_data)
	marker_data = file_data.actions
	if not marker_data:
		printerr("Error: Failed to read file.")
		return false
	if marker_data.size() < 6:
		printerr("Error: Insufficient path data in file.")
		return false

	network_paths = create_network_packets()
	path = create_path_lines()
	chapters = create_chapters(file_data.chapters)

	return true


func parse_file(filePath: String) -> Dictionary:
	var file_data: Dictionary
	var file = FileAccess.open(filePath, FileAccess.READ)
	if file:
		var file_text = file.get_as_text().replace("\n", "")
		file_data = JSON.parse_string(file_text)
		if not file_data:
			printerr("Error: No JSON data found in file.")
		file.close()

	return file_data

	
func map_funscript_data(parsed_data: Dictionary) -> Dictionary:
	var file_data: Dictionary[int, Array]
	var chapt: Array
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
				var frame: int = int(action.at / (1000.0 / 60.0))
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
	if parsed_data.has("meta"):
		var meta = parsed_data["meta"]
		if meta is Dictionary and meta.has("video_offset_ms"):
			%VideoPlayer/Main/VideoOffset/Input.value = meta["video_offset_ms"]

	return {
		"actions": parsed_data["markers"],
		"chapters": []
	}


func create_network_packets():
	var previous_ms_timing: int
	var network_packets: Array[PackedByteArray]

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
		var auxiliary: int = marker[3]
		var network_packet = OSSMCommand.create_move_command(ms_timing, Util.safe_map_physical_position(depth), trans, ease, auxiliary)
		network_packets.append(network_packet)
		# Adjust for physics tick rate change from BounceX (60Hz to 50Hz)
		var corrected_frame: int = int(round(marker_frame / 1.2))
		marker_data[corrected_frame] = marker
		marker_data.erase(marker_frame)
		previous_ms_timing = ms_timing

	return network_packets


func create_path_lines():
	var path_lines: PackedFloat32Array

	var previous_depth: float
	var previous_frame: int
	var marker_list: Array = marker_data.keys()
	marker_list.sort()
	for marker_frame in marker_list:
		var marker = marker_data[marker_frame]
		var depth = marker[0]
		var trans = marker[1]
		@warning_ignore("shadowed_global_identifier")
		var ease = marker[2]
		if marker_frame > 0:
			var steps: int = marker_frame - previous_frame
			frames.append(previous_frame)
			for step in steps:
				var step_depth: float = Tween.interpolate_value(
						previous_depth,
						depth - previous_depth,
						step,
						steps,
						trans,
						ease)
				path_lines.append(step_depth)
		previous_depth = depth
		previous_frame = marker_frame
	return path_lines


func format_time(msTime: int) -> String:
	var hours = int(msTime / 3600000.0)
	var remainder = msTime - hours * 3600000
	var minutes = int(remainder / 60000.0)
	remainder = remainder - minutes * 60000
	var seconds = int(remainder / 1000.0)
	remainder = remainder - seconds * 1000
	var timeString = "%d:%d:%d.%d" % [hours, minutes, seconds, remainder]
	return timeString


func create_chapters(chappy: Array) -> Array:
	var chapter_data = chappy if chappy else []
	
	var sorted_keys : Array[int] = marker_data.keys()
	sorted_keys.sort_custom(func(a, b): return int(a) < int(b))
	
	if chapter_data.is_empty():
		for n in range(300, sorted_keys.back(), 300):
			var idx = sorted_keys.bsearch(n)
			if idx < sorted_keys.size():
				var frame = sorted_keys[idx]
				var minutes = int(frame / 3600.0)
				chapter_data.append({
					"name": "%d minutes" % minutes,
					"beginFrame": frame,
				})
	else:
		for chapter in chapter_data:
			chapter['beginFrame'] = find_frame_for_time_string(chapter.startTime, sorted_keys)
			chapter['endFrame'] = find_frame_for_time_string(chapter.endTime, sorted_keys)
	
	chapter_data.sort_custom(chapter_sorter)

	return chapter_data


func chapter_sorter(a, b) -> bool:
	if a['beginFrame'] < b['beginFrame']:
		return true
	return false


func round_to(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor


func render_depth(depth) -> float:
	return PATH_BOTTOM + depth * (PATH_TOP - PATH_BOTTOM)


func find_prev_marker_for_frame(frame: int) -> int:
	var idx = frames.bsearch(frame)
	if (idx > 0):
		return idx - 1
	return 0


func parse_time(time_string: String) -> float:
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

	return float(seconds) + int(minutes) * 60 + int(hours) * 3600


func find_frame_for_time_string(time_string: String, marker_list: Array[int]) -> int:
	var frame = parse_time(time_string) * 60.0
	var idx = marker_list.bsearch(frame)
	if idx < marker_list.size():
		return marker_list[idx]
	return marker_list[-1]


func get_current_chapter(frame: int):
	var idx = get_chapter_idx(frame)
	if idx < chapters.size() - 1:
		var chapter = chapters[idx + 1]
		if frame < chapter['endFrame']:
			return chapter
	

func get_chapter_idx(frame: int) -> int:
	var idx = chapters.bsearch_custom(frame, chapter_sorter)
	return idx


func get_next_chapter(frame: int):
	var idx = get_chapter_idx(frame)
	if idx < chapters.size() - 1:
		return chapters[idx + 1]
