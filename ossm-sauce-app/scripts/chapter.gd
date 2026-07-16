class_name Chapter


func _init(name: String, start_at: int, end_at: int = -1) -> void:
	self.name = name
	self.start_at = start_at
	self.end_at = end_at

var name: String:
	get:
		return name

var start_at: int:
	get:
		return start_at

var end_at: int:
	get:
		return end_at

var begin_frame: int:
	get:
		return ceili((start_at / 1000.0) * Global.ticks_per_second)

var end_frame:
	get:
		if end_at > 0:
			return ceili((end_at / 1000.0) * Global.ticks_per_second)
		return null


static func from_meta(meta: Dictionary) -> Chapter:
	var name = meta["name"]
	var start_time = meta["startTime"]
	var end_time = meta["endTime"]
	var start_at = int(round(Util.parse_time(str(start_time)) * 1000))
	if end_time:
		var end_at = int(round(Util.parse_time(str(end_time)) * 1000))
		return Chapter.new(name, start_at, end_at)
	return Chapter.new(name, start_at)
