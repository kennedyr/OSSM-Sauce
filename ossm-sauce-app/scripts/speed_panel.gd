extends Panel

var speed_slider_min_pos: float
var speed_slider_max_pos: float
var speed_limit: int
@onready var speed_slider: TextureRect = $SpeedBar/Slider
@onready var speed_bottom: TextureRect = $SpeedBar/SliderBottom

var accel_slider_min_pos: float
var accel_slider_max_pos: float
var acceleration_limit: int
@onready var acceleration_slider: TextureRect = $AccelerationBar/Slider
@onready var acceleration_bottom: TextureRect = $AccelerationBar/SliderBottom


func _ready():
	$LabelTop.self_modulate.a = 0
	$LabelBot.self_modulate.a = 0
	$BackTexture.self_modulate.a = 0
	$BackTexture.show()
	speed_slider_max_pos = speed_slider.position.y
	speed_slider_min_pos = speed_bottom.position.y
	accel_slider_max_pos = acceleration_slider.position.y
	accel_slider_min_pos = acceleration_bottom.position.y


func get_speed_slider_percent():
	var slider_pos = speed_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, speed_slider_min_pos, speed_slider_max_pos)
	return percent


func set_speed_slider_pos(percent):
	speed_slider.position.y = Util.safe_map_slider_position(
		percent,
		speed_slider_min_pos,
		speed_slider_max_pos)
	update_speed(true)


func set_speed_slider_percent(percent):
	set_speed_slider_pos(percent)
	send_speed_limits()


func get_acceleration_slider_percent():
	var slider_pos = acceleration_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, accel_slider_min_pos, accel_slider_max_pos)
	return percent


func set_acceleration_slider_pos(percent):
	acceleration_slider.position.y = Util.safe_map_slider_position(
		percent,
		accel_slider_min_pos,
		accel_slider_max_pos)
	update_acceleration(true)


func set_acceleration_slider_percent(percent):
	set_acceleration_slider_pos(percent)
	send_speed_limits()


func update_speed(label_only := false):
	var slider_pos = speed_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, speed_slider_min_pos, speed_slider_max_pos)
	speed_limit = Util.safe_map_value(
		percent,
		0,
		Global.max_speed)
	var text_value = str(round(percent * 100))
	$LabelTop.text = "Max Speed:\n" + text_value + "%"
	# $LabelTop.text = "Max Speed:\n" + str(speed_limit) + " steps/sec"
	if not label_only:
		UserSettings.set_value(UserSettings.Section.speed_slider, 'position_percent', percent)
		if $DebounceTimer.is_stopped():
			$DebounceTimer.start()


func update_acceleration(label_only := false):
	var slider_pos = acceleration_slider.position.y
	var percent = Util.safe_map_slider_percent(slider_pos, accel_slider_min_pos, accel_slider_max_pos)
	acceleration_limit = Util.safe_map_value(
		percent,
		1000,
		Global.max_acceleration)
	var text_value = str(round(percent * 100))
	$LabelBot.text = "Acceleration:\n" + text_value + "%"
	# $LabelBot.text = "Acceleration:\n" + str(acceleration_limit) + " steps/sec²"
	if not label_only:
		UserSettings.set_value(UserSettings.Section.accel_slider, 'position_percent', percent)
		if $DebounceTimer.is_stopped():
			$DebounceTimer.start()


func send_speed_limits():
	%OSSMCommand.set_speed_limit(speed_limit)
	%OSSMCommand.set_acceleration_limit(acceleration_limit)
	if %WebSocket.ossm_connected:
		if AppMode.active == AppMode.VIBRATE:
			%VibrationControls.send_vibrate_command()


func _on_speed_slider_gui_input(event):
	if 'relative' in event and event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			var drag_pos = speed_slider.position.y + event.relative.y
			var new_slider_pos = clamp(
				drag_pos,
				speed_slider_max_pos,
				speed_slider_min_pos)
			if(new_slider_pos == speed_slider.position.y):
				return

			speed_slider.position.y = new_slider_pos
			update_speed()


func _on_acceleration_slider_gui_input(event):
	if 'relative' in event and event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_LEFT:
			var drag_pos = acceleration_slider.position.y + event.relative.y
			var new_slider_pos = clamp(
				drag_pos,
				accel_slider_max_pos,
				accel_slider_min_pos)
			if(new_slider_pos == acceleration_slider.position.y):
				return

			acceleration_slider.position.y = new_slider_pos
			update_acceleration()


func tween(activating := true):
	var tween_tmp = get_tree().create_tween()
	tween_tmp.set_trans(Tween.TRANS_QUART)
	tween_tmp.set_ease(Tween.EASE_OUT)
	tween_tmp.set_parallel()
	var outside_pos := Vector2(-size.x, position.y)
	var inside_pos := Vector2(0, outside_pos.y)
	var positions: Array = [outside_pos, inside_pos]
	if not activating:
		positions.reverse()
	tween_tmp.tween_method(set_position, position, positions[1], Global.ANIM_TIME)
	var start_color: Color = $BackTexture.self_modulate
	var end_color: Color = start_color
	start_color.a = 0
	end_color.a = 1
	var colors: Array = [start_color, end_color]
	if not activating:
		colors.reverse()
		$BackButton.hide()
		tween_tmp.tween_callback(anim_finished).set_delay(Global.ANIM_TIME)
	else:
		$BackButton.show()
	var visuals = [$BackTexture, $LabelTop, $LabelBot]
	for node in visuals:
		tween_tmp.tween_method(
			node.set_self_modulate,
			colors[0],
			colors[1],
			Global.ANIM_TIME)


func anim_finished():
	%ActionPanel/Speed/Selection.hide()
	%ActionPanel.self_modulate.a = 1
	$BackButton.hide()


func _on_back_button_pressed():
	tween(false)
	$BackButton.hide()
	%ActionPanel.show()
