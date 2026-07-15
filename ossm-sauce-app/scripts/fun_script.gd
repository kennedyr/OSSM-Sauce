extends Node

class_name Funscript

var marker_data: Dictionary[int, Marker]
var path: PackedFloat32Array
var frames: PackedInt32Array
var network_paths: Array[PackedByteArray]
var chapters: Array[Chapter]


# An action at a single point in time
class Marker:
	var at: int:
		get:
			return at

	var depth: float:
		get:
			return depth

	var _auxiliary: int = 0

	func _init(at_val: int, depth_val: float) -> void:
		self.at = at_val
		self.depth = depth_val
	
	func get_marker_frame_60hz() -> int:
		return get_marker_frame(60)

	func get_marker_frame(ticks_per_second = Global.ticks_per_second) -> int:
		return int(at / (1000.0 / ticks_per_second))

	func get_network_packet() -> PackedByteArray:
		return OSSMCommand.create_move_command(at, Util.safe_map_physical_position(depth), Global.transition, Global.easing, _auxiliary)


class Chapter:
	var name: String:
		get:
			return name

	var start_at: int:
		get:
			return start_at

	var end_at: int:
		get:
			return end_at

	func get_begin_frame(ticks_per_second = Global.ticks_per_second) -> int:
		return ceili((start_at / 1000.0) * ticks_per_second)

	func get_end_frame(ticks_per_second = Global.ticks_per_second):
		if end_at > 0:
			return ceili((end_at / 1000.0) * ticks_per_second)
		return null

	func _init(name: String, start_at: int, end_at: int = -1) -> void:
		self.name = name
		self.start_at = start_at
		self.end_at = end_at

	static func from_meta(meta: Dictionary) -> Chapter:
		var name = meta["name"]
		var start_time = meta["startTime"]
		var end_time = meta["endTime"]
		var start_at = int(round(Util.parse_time(str(start_time)) * 1000))
		if end_time:
			var end_at = int(round(Util.parse_time(str(end_time)) * 1000))
			return Chapter.new(name, start_at, end_at)
		return Chapter.new(name, start_at)


func _init(file_path: String):
	load_path(file_path)


func load_path(file_path: String) -> bool:
	var parsed_data = parse_file(file_path)
	var is_funscript = file_path.ends_with(".funscript")
	var file_data: Dictionary
	if is_funscript:
		file_data = map_funscript_data(parsed_data)
	else:
		file_data = map_other_data(parsed_data)
	var raw_marker_data: Array[Marker] = file_data.actions
	if not raw_marker_data:
		printerr("Error: Failed to read file.")
		return false
	if raw_marker_data.size() < 6:
		printerr("Error: Insufficient path data in file.")
		return false
	network_paths.assign(raw_marker_data.map(func(m): m.get_network_packet()))
	raw_marker_data.map(func(m): marker_data[m.get_marker_frame()] = m)
	path = create_path_lines(marker_data)
	var raw_chapter_data: Array[Chapter] = file_data.chapters
	if raw_chapter_data.is_empty():
		chapters = create_virtual_chapters(marker_data)
	else:
		chapters = raw_chapter_data

	return true


func parse_file(file_path: String) -> Dictionary:
	var file_data: Dictionary
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var file_text = file.get_as_text().replace("\n", "")
		file_data = JSON.parse_string(file_text)
		if not file_data:
			printerr("Error: No JSON data found in file.")
		file.close()

	return file_data

	
func map_funscript_data(parsed_data: Dictionary):
	var file_data: Array[Marker]
	var chapter_data: Array[Chapter]
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
				for chapt in meta["chapters"]:
					chapter_data.append(Chapter.from_meta(chapt))
			
		if action_data:
			var created_first_action = false
			for action in action_data:
				var depth = round_to(clamp(action.pos / 100, 0, 1), 4)
				if inverted:
					depth = round_to(1.0 - depth, 4)
				if !created_first_action:
					if action.at > 0:
						var virtual_action = Marker.new(0, depth)
						file_data.append(virtual_action)
					created_first_action = true

				file_data.append(Marker.new(action.at, depth))

		else:
			print("Failed to parse funscript JSON")

	file_data.sort_custom(marker_sorter)
	chapter_data.sort_custom(chapter_sorter)
	
	return {
		"actions": file_data,
		"chapters": chapter_data
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


func create_path_lines(marker_data: Dictionary[int, Marker]):
	var path_lines: PackedFloat32Array

	var marker_frames: Array = marker_data.keys()
	marker_frames.sort()
	var previous_depth: float
	var previous_frame: int
	for marker_frame in marker_frames:
		var marker = marker_data[marker_frame]
		if marker_frame > 0:
			var steps: int = marker_frame - previous_frame
			frames.append(previous_frame)
			for step in steps:
				var step_depth: float = Tween.interpolate_value(
						previous_depth,
						marker.depth - previous_depth,
						step,
						steps,
						Global.transition,
						Global.easing)
				path_lines.append(step_depth)
		previous_depth = marker.depth
		previous_frame = marker_frame
	return path_lines


func create_virtual_chapters(marker_data: Dictionary[int, Marker]) -> Array[Chapter]:
	var chapter_data: Array[Chapter]
	var marker_frames = marker_data.keys()
	marker_frames.sort()
	for n in range(18000, marker_frames.back(), 18000):
		var idx = marker_frames.bsearch(n)
		if idx < marker_frames.size():
			var frame = marker_frames[idx]
			var marker = marker_data[frame]
			var minutes = int(frame / 3600.0)
			chapter_data.append(Chapter.new("%d minutes" % minutes, marker.at))
	
	return chapter_data


func marker_sorter(a: Marker, b: Marker) -> bool:
	if a.at < b.at:
		return true
	return false


func chapter_sorter(a: Chapter, b: Chapter) -> bool:
	if a.start_at < b.start_at:
		return true
	return false


func round_to(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor


func get_nearest_chapter(frame: int):
	var total_frames = path.size()
	var delta = int(total_frames / 70.0)
	
	var idx = get_chapter_idx(frame)
	if idx >= 0:
		var chapter = chapters[idx]
		var chapter_begin_frame = chapter.get_begin_frame()
		if chapter_begin_frame > frame - delta and chapter_begin_frame < frame + delta:
			return {
				"chapter": chapter,
				"index": idx
			}

	if idx < chapters.size() - 1:
		var chapter = chapters[idx + 1]
		var chapter_begin_frame = chapter.get_begin_frame()
		if chapter_begin_frame > frame - delta and chapter_begin_frame < frame + delta:
			return {
				"chapter": chapter,
				"index": idx + 1
			}


func get_current_chapter(frame: int):
	var idx = get_chapter_idx(frame)
	if idx >= 0:
		var chapter = chapters[idx]
		var chapter_end_frame = chapter.get_end_frame()
		if chapter_end_frame == null or frame < chapter_end_frame:
			return chapter
	

func get_chapter_idx(frame: int) -> int:
	var at = int((float(frame) / Global.ticks_per_second) * 1000.0)
	var idx = chapters.bsearch_custom(Chapter.new("", at), chapter_sorter, false)
	if idx == 0:
		return idx

	if chapters[idx].start_at == at and idx < chapters.size():
		return idx

	return idx - 1


func get_next_chapter(frame: int):
	var idx = get_chapter_idx(frame)
	if idx < chapters.size() - 1:
		return chapters[idx + 1]
