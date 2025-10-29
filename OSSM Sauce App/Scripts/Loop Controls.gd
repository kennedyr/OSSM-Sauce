extends Control

var active:bool

enum Trans {
	LINEAR,
	SINE,
	CIRC,
	EXPO,
	QUAD,
	CUBIC,
	QUART,
	QUINT
}

var tween_map:Dictionary = {
	Trans.LINEAR : 0,
	Trans.SINE : 1,
	Trans.CIRC : 8,
	Trans.EXPO : 5,
	Trans.QUAD : 4,
	Trans.CUBIC : 7,
	Trans.QUART : 3,
	Trans.QUINT : 2
}

var slider_resist:float = 0.8

var A:Vector2
var B:Vector2
var C:Vector2


func _ready():
	A.x = $Control.position.x
	A.y = $Control.position.y + $Control.size.y
	B.x = $Control.position.x + $Control.size.x / 2
	B.y = $Control.position.y
	C.x = $Control.position.x + $Control.size.x
	C.y = $Control.position.y + $Control.size.y
	_on_link_speed_sliders_toggled(true)


func rmt(input:int):
	return tween_map[input]


func draw_easing():
	$Line2D.clear_points()
	var x_pos = A.x
	
	for i in 383:
		var w = Tween.interpolate_value(
			A.y,
			(B.y - A.y),
			float(i) / 383,
			1,
			rmt($In/AccelerationControls/Transition.selected),
			$In/AccelerationControls/Easing.selected)
		$Line2D.add_point(Vector2(x_pos, w - 25))
		x_pos += 1
	
	for i in 383:
		var w = Tween.interpolate_value(
			B.y,
			-(B.y - C.y),
			float(i) / 383,
			1,
			rmt($Out/AccelerationControls/Transition.selected),
			$Out/AccelerationControls/Easing.selected)
		$Line2D.add_point(Vector2(x_pos, w - 25))
		x_pos += 1


func send_command():
	draw_easing()
	var in_duration:float = $In.stroke_duration
	var in_trans:int = $In/AccelerationControls/Transition.selected
	var in_ease:int = $In/AccelerationControls/Easing.selected
	var in_auxiliary:int
	var out_duration:float = $Out.stroke_duration
	var out_trans:int = $Out/AccelerationControls/Transition.selected
	var out_ease:int = $Out/AccelerationControls/Easing.selected
	var out_auxiliary:int
	UserSettings.set_value(UserSettings.Section.stroke_settings, 'in_trans', in_trans)
	UserSettings.set_value(UserSettings.Section.stroke_settings, 'in_ease', in_ease)
	UserSettings.set_value(UserSettings.Section.stroke_settings, 'out_trans', out_trans)
	UserSettings.set_value(UserSettings.Section.stroke_settings, 'out_ease', out_ease)
	
	%OSSMCommand.loop(in_duration, in_trans, in_ease, out_duration, out_trans, out_ease)
	if in_duration + out_duration == 0:
		owner.pause()
		active = false
	elif not active:
		owner.play()
		active = true


func reset_stroke_duration_sliders():
	$In.reset_stroke_duration_slider()
	$Out.reset_stroke_duration_slider()


func update_stroke_duration_text():
	$In.update_stroke_duration_text()
	$Out.update_stroke_duration_text()


func _on_link_speed_sliders_toggled(toggled_on):
	if toggled_on:
		$LinkSpeedSliders/Label.set_modulate('00b97d')
	else:
		$LinkSpeedSliders/Label.set_modulate(Color.WHITE)


func activate():
	$In.touch_pos = $In.slider_max_pos
	$Out.touch_pos = $Out.slider_max_pos
	$In/StrokeDurationSlider/Slider.position.y = $In.slider_max_pos
	$Out/StrokeDurationSlider/Slider.position.y = $Out.slider_max_pos
	$In.stroke_duration = 0
	$Out.stroke_duration = 0
	update_stroke_duration_text()
	$In.set_physics_process(true)
	$Out.set_physics_process(true)
	$In.input_active = false
	$Out.input_active = false
	active = false
	%Menu/LoopSettings.show()
	show()


func deactivate():
	$In.set_physics_process(false)
	$Out.set_physics_process(false)
	%Menu/LoopSettings.hide()
	hide()
