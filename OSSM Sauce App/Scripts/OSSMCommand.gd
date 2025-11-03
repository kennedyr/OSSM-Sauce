extends Node

const DEBUG = false

## MOVE Command (0x01)
## Controls point-to-point motion with easing curves.
func move(ms_timing: int, target_position: int, trans: int, ease: int, auxiliary: int):
	if DEBUG:
		print("Sending smooth move command: timing=%d, target_position=%d, trans=%d, ease=%d, aux=%d" % [ms_timing, target_position, trans, ease, auxiliary])
	
	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_move_command(ms_timing, target_position, trans, ease, auxiliary)
		%WebSocket.server.broadcast_binary(command)


## LOOP Command (0x02)
## Defines a continuous back-and-forth motion pattern.
func loop(in_duration: float, in_trans: int, in_ease: int, out_duration: float, out_trans: int, out_ease: int):
	if DEBUG:
		print("Sending loop command: in_duration=%d, in_trans=%d, in_ease=%d, out_duration=%d, out_ease=%d, out_aux=%d" % [in_duration * 1000, in_trans, in_ease, out_duration * 1000, out_trans, out_ease])
	var in_auxiliary: int
	var out_auxiliary: int
	
	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_loop_command(in_duration, in_trans, in_ease, in_auxiliary, out_duration, out_trans, out_ease, out_auxiliary)
		%WebSocket.server.broadcast_binary(command)


## POSITION Command (0x03)
## Direct position control for manual operation.
func position(target_position: int):
	if DEBUG:
		print("Sending position command: target_position=%d" % [target_position])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_position_command(target_position)
		%WebSocket.server.broadcast_binary(command)


## VIBRATE Command (0x04)
## Configures vibration pattern with adjustable waveform.
func vibrate(duration: int, half_period_ms: int, origin_position: int, range_percent: int, waveform: int):
	if DEBUG:
		print("Sending vibrate command: duration=%d" % [duration])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_vibrate_command(duration, half_period_ms, origin_position, range_percent, waveform)
		%WebSocket.server.broadcast_binary(command)


## PLAY Command (0x05)
## Starts playback in specified mode.
func play(play_time_ms = null):
	if DEBUG:
		print("Sending play command: play_time_ms=%d" % [play_time_ms])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_play_command(play_time_ms)
		%WebSocket.server.broadcast_binary(command)


## PAUSE Command (0x06)
## Pauses current motion.
func pause():
	if DEBUG:
		print("Sending pause command")

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_pause_command()
		%WebSocket.server.broadcast_binary(command)


## RESET Command (0x07)
## Clears motion queue and resets playback.
func reset():
	if DEBUG:
		print("Sending reset command")

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_reset_command()
		%WebSocket.server.broadcast_binary(command)


## HOMING Command (0x08)
## Initiates homing to specified position.
func home_to(target_position: int):
	if DEBUG:
		print("Sending Homing command: target_position=%d" % [target_position])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_homing_command(target_position)
		%WebSocket.server.broadcast_binary(command)


## CONNECTION Command (0x09)
## Handshake/connection verification.
func connection():
	if DEBUG:
		print("Sending connection command")

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_connection_command()
		%WebSocket.server.broadcast_binary(command)


## SET_SPEED_LIMIT Command (0x0A)
## Sets motor speed limit across all app modes.
func set_speed_limit(steps_per_sec: int):
	if DEBUG:
		print("Sending set speed limit command: steps_per_sec=%d" % [steps_per_sec])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_set_speed_limit_command(steps_per_sec)
		%WebSocket.server.broadcast_binary(command)


## SET_GLOBAL_ACCELERATION Command (0x0B)
## Sets motor acceleration limit across all app modes.
## acceleration - Maximum acceleration in steps/sec²
func set_acceleration_limit(acceleration: int):
	if DEBUG:
		print("Sending set acceleration limit command: acceleration=%d" % [acceleration])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_set_global_acceleration_command(acceleration)
		%WebSocket.server.broadcast_binary(command)


## SET_RANGE_LIMIT Command (0x0C)
## Sets motion range limits for either end of the rail.
func set_range_limit(range_limit_type: OSSM.RangeLimitType, range_limit: int):
	if DEBUG:
		print("Sending set range limit command: type=%s range=%d" % [OSSM.RangeLimitType.keys()[range_limit_type], range_limit])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_set_range_limit_command(range_limit_type, range_limit)
		%WebSocket.server.broadcast_binary(command)


## SET_RANGE_LIMIT MAX
## Sets motion range limits for either end of the rail.
func set_range_limit_min(range_limit: int):
	set_range_limit(OSSM.RangeLimitType.MIN_RANGE, range_limit)


## SET_RANGE_LIMIT MAX
## Sets motion range limits for either end of the rail.
func set_range_limit_max(range_limit: int):
	set_range_limit(OSSM.RangeLimitType.MAX_RANGE, range_limit)


## SET_HOMING_SPEED Command (0x0D)
## Sets position syncing movement speed.
func set_homing_speed(steps_per_sec: int):
	if DEBUG:
		print("Sending set homing speed command: steps_per_sec=%d" % [steps_per_sec])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_set_homing_speed_command(steps_per_sec)
		%WebSocket.server.broadcast_binary(command)


## SET_HOMING_TRIGGER Command (0x0E)
## Sets power spike threshold for sensorless homing. (Lower = more sensitive)
func set_homing_trigger(threshold_voltage: int):
	if DEBUG:
		print("Sending set homing trigger command: threshold_voltage=%d" % [threshold_voltage])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_set_homing_trigger_command(threshold_voltage)
		%WebSocket.server.broadcast_binary(command)


## SMOOTH_MOVE Command (0x0F)
## Controls point-to-point motion with easing curves.
func smooth_move(ms_duration: int, target_position: int, trans: int, ease: int, auxiliary: int):
	if DEBUG:
		print("Sending smooth move command: duration=%d, target_position=%d, trans=%d, ease=%d, aux=%d" % [ms_duration, target_position, trans, ease, auxiliary])

	if %WebSocket.ossm_connected:
		var command = OSSMCommand.create_smooth_move_command(ms_duration, target_position, trans, ease, auxiliary)
		%WebSocket.server.broadcast_binary(command)
