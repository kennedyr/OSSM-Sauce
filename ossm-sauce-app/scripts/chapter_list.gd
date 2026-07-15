extends Panel

@onready var ChapterTemplate: TextureRect = $ChapterTick


func _ready():
	remove_child(ChapterTemplate)


func initialize(chapters: Array, total_frames: int) -> void:
	clear()

	if chapters:
		var height := size.y
		var tick_height := ChapterTemplate.size.y
		var margin_height := 4
		var effective_range := height - tick_height - margin_height * 2
		for chapter in chapters:
			var target_frame = chapter.get_begin_frame()
			var percent_value = (float(target_frame) / (total_frames - 1))
			var y_pos = effective_range * (1 - percent_value) + margin_height
			add_item(chapter.name, y_pos)


func add_item(title: String, y_pos: float):
	var chapterTick = ChapterTemplate.duplicate()
	chapterTick.tooltip_text = title
	chapterTick.set_position(Vector2(ChapterTemplate.position.x, y_pos))
	add_child(chapterTick)


func clear():
	for chapterTick in get_children():
		remove_child(chapterTick)
