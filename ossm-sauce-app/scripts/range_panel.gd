extends Panel

enum {MIN_RANGE, MAX_RANGE}

var min_range_pos: float
var max_range_pos: float
var min_range_limit: int
var max_range_limit: int

@onready var min_slider: TextureRect = $RangeBar/MinSlider
@onready var max_slider: TextureRect = $RangeBar/MaxSlider


func _ready():
	$LabelTop.self_modulate.a = 0
	$LabelBot.self_modulate.a = 0
	$BackTexture.self_modulate.a = 0
	$BackTexture.show()
	min_range_pos = min_slider.position.y
	max_range_pos = max_slider.position.y


func _on_min_slider_gui_input(event):
	if 'relative' in event and event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			var drag_pos = min_slider.position.y + event.relative.y
			var max_range = max_slider.position.y + max_slider.size.y
			var new_slider_position = clamp(drag_pos, max_range, min_range_pos)
			if(new_slider_position == min_slider.position.y):
				return

			min_slider.position.y = new_slider_position
			if AppMode.active == AppMode.POSITION:
				update_min_range(true)
			else:
				update_min_range()


func _on_max_slider_gui_input(event):
	if 'relative' in event and event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			var drag_pos = max_slider.position.y + event.relative.y
			var min_range = min_slider.position.y - min_slider.size.y
			var new_slider_position = clamp(drag_pos, max_range_pos, min_range)
			if(new_slider_position == max_slider.position.y):
				return

			max_slider.position.y = new_slider_position
			if AppMode.active == AppMode.POSITION:
				update_max_range(true)
			else:
				update_max_range()


func update_min_range(label_only := false):
	var slider_pos = min_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, min_range_pos, max_range_pos)
	min_range_limit = Util.safe_map_physical_position(percent)
	if not label_only:
		UserSettings.set_value(UserSettings.Section.range_slider_min, 'position_percent', percent)
		if $DebounceTimer.is_stopped():
			$DebounceTimer.start()

	var text_value = str(round(percent * 100))
	$LabelBot.text = "Min Position:\n" + text_value + "%"

	%SpeedPanel.update_speed(true)


func update_max_range(label_only := false):
	var slider_pos = max_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, min_range_pos, max_range_pos)
	max_range_limit = Util.safe_map_physical_position(percent)
	if not label_only:
		UserSettings.set_value(UserSettings.Section.range_slider_max, 'position_percent', percent)
		if $DebounceTimer.is_stopped():
			$DebounceTimer.start()
	$LabelTop.text = "Max Position:\n" + str(snapped(percent * 100, 0.01)) + "%"


func send_range_limits():
	var min_range = abs(Global.motor_direction * 10000 - min_range_limit)
	var max_range = abs(Global.motor_direction * 10000 - max_range_limit)
	if Global.motor_direction == 0:
		%OSSMCommand.set_range_limit_min(min_range)
		%OSSMCommand.set_range_limit_max(max_range)
	else:
		%OSSMCommand.set_range_limit_min(max_range)
		%OSSMCommand.set_range_limit_max(min_range)

	if %WebSocket.ossm_connected:
		if AppMode.active == AppMode.VIBRATE:
			if %VibrationControls.pulse_active:
				%VibrationControls.pulse_controller()
			else:
				%VibrationControls.send_vibrate_command()

	%SpeedPanel.update_speed(true)


func get_min_slider_percent():
	var slider_pos = min_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, min_range_pos, max_range_pos)
	return percent


func set_min_slider_percent(percent):
	min_slider.position.y = Util.safe_map_slider_position(percent, min_range_pos, max_range_pos)
	update_min_range()


func get_max_slider_percent():
	var slider_pos = max_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, min_range_pos, max_range_pos)
	return percent


func set_max_slider_percent(percent):
	max_slider.position.y = Util.safe_map_slider_position(percent, min_range_pos, max_range_pos)
	update_max_range()


func get_range_percent():
	return get_max_slider_percent() - get_min_slider_percent()


func tween(activating:bool = true):
	var tween = get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	var viewport_right_edge = get_viewport_rect().size.x
	var viewport_middle = get_viewport_rect().size.x / 2
	var outside_pos := Vector2(viewport_right_edge, position.y)
	var inside_pos := Vector2(viewport_middle, outside_pos.y)
	var positions: Array = [outside_pos, inside_pos]
	if not activating:
		positions.reverse()
	tween.tween_method(set_position, position, positions[1], Global.ANIM_TIME)
	var start_color: Color = $BackTexture.self_modulate
	var end_color: Color = start_color
	start_color.a = 0
	end_color.a = 1
	var colors: Array = [start_color, end_color]
	if not activating:
		colors.reverse()
		$BackButton.hide()
		tween.tween_callback(anim_finished).set_delay(Global.ANIM_TIME)
	else:
		$BackButton.show()
	var visuals = [$BackTexture, $LabelBot, $LabelTop]
	for node in visuals:
		tween.tween_method(
				node.set_self_modulate,
				colors[0],
				colors[1],
				Global.ANIM_TIME)


func anim_finished():
	%ActionPanel/Range/Selection.hide()
	%ActionPanel.self_modulate.a = 1
	$BackButton.hide()


func _on_back_button_pressed():
	if %WebSocket.ossm_connected and AppMode.active == AppMode.POSITION:
		update_min_range()
		update_max_range()
		$DebounceTimer.stop()
		send_range_limits()
		%CircleSelection.show_hourglass()
		%PositionControls.modulate.a = 0.05
		owner.home_to(abs(Global.motor_direction * 10000 - %PositionControls.last_position))
	$BackButton.hide()
	tween(false)
	%ActionPanel.show()
