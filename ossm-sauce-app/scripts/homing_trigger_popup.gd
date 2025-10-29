extends Panel


func _ready() -> void:
	self_modulate.a = 3


func _on_yes_button_pressed() -> void:
	var new_value: float = %Settings/VBox/HomingTrigger/Input.value
	owner.user_settings.set_value('device_settings', 'homing_trigger', new_value)
	send_homing_trigger()
	hide()


func _on_no_button_pressed() -> void:
	if owner.user_settings.has_section_key('device_settings', 'homing_trigger'):
		var previous_value = owner.user_settings.get_value('device_settings', 'homing_trigger', 1.5)
		%Settings/VBox/HomingTrigger/Input.set_value_no_signal(previous_value)
		send_homing_trigger()
	else:
		%Settings/VBox/HomingTrigger/Input.set_value_no_signal(1.5)
	hide()


func send_homing_trigger():
	var homing_trigger = %Settings/VBox/HomingTrigger/Input.value
	%OSSMCommand.set_homing_trigger(homing_trigger)
