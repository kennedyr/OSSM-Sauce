class_name OSSMCommand
extends Node


# MOVE Command (0x01)
# Controls point-to-point motion with easing curves.
# 
# **Packet Size:** 10 bytes
# 
# ┌────┬───────────┬────────┬────────┬────────┬────────┐
# │ 0  │    1-4    │  5-6   │   7    │   8    │   9    │
# ├────┼───────────┼────────┼────────┼────────┼────────┤
# │CMD │  TIME_MS  │  POS   │ TRANS  │  EASE  │  AUX   │
# │0x01│   (u32)   │ (u16)  │  (u8)  │  (u8)  │  (u8)  │
# └────┴───────────┴────────┴────────┴────────┴────────┘
# 
# CMD     - Command type (MOVE = 0x01)
# TIME_MS - Move completion time in milliseconds (u32)
# POS     - Target position 0-10000 (u16)
# TRANS   - Transition type (u8)
# EASE    - Easing type (u8)
# AUX     - Auxiliary functions bitmask (u8)
# 
# **Transition Types:**
# - 0: LINEAR
# - 1: SINE
# - 2: CIRC
# - 3: EXPO
# - 4: QUAD
# - 5: CUBIC
# - 6: QUART
# - 7: QUINT
# 
# **Easing Types:**
# - 0: EASE_IN
# - 1: EASE_OUT
# - 2: EASE_IN_OUT
# - 3: EASE_OUT_IN
@warning_ignore("shadowed_global_identifier")
static func create_move_command(ms_timing: int, target_position: int, trans: int, ease: int, auxiliary: int):
	var network_packet:PackedByteArray
	network_packet.resize(10)

	network_packet.encode_u8(0, OSSM.Command.MOVE)
	network_packet.encode_u32(1, ms_timing)
	network_packet.encode_u16(5, target_position)
	network_packet.encode_u8(7, trans)
	network_packet.encode_u8(8, ease)
	network_packet.encode_u8(9, auxiliary)

	return network_packet


# LOOP Command (0x02)
# Defines a continuous back-and-forth motion pattern.
#
# **Packet Size:** 19 bytes
#
# ┌────┬────────────────────┬───────────────────────┐
# │ 0  │   1-9              │   10-18               │
# ├────┼────────────────────┴───────────────────────┤
# │CMD │   PUSH_STROKE      │   PULL_STROKE         │
# │0x02│   (9 bytes)        │   (9 bytes)           │
# └────┴────────────────────┴───────────────────────┘
#
# Each stroke contains:
# ┌─────────────┬────────┬────────┬────────┬────────┐
# │   0-3       │  4-5   │   6    │   7    │   8    │
# ├─────────────┼────────┼────────┼────────┼────────┤
# │ DURATION_MS │  POS   │ TRANS  │  EASE  │  AUX   │
# │    (u32)    │ (u16)  │  (u8)  │  (u8)  │  (u8)  │
# └─────────────┴────────┴────────┴────────┴────────┘
static func create_loop_command(in_duration: float, in_trans: int, in_ease: int, in_auxiliary: int, out_duration: float, out_trans: int, out_ease: int, out_auxiliary: int):
	var network_packet: PackedByteArray
	network_packet.resize(19)

	network_packet.encode_u8(0, OSSM.Command.LOOP)
	network_packet.encode_u32(1, in_duration * 1000)
	network_packet.encode_u16(5, 10000)
	network_packet.encode_u8(7, in_trans)
	network_packet.encode_u8(8, in_ease)
	network_packet.encode_u8(9, in_auxiliary)
	network_packet.encode_u32(10, out_duration * 1000)
	network_packet.encode_u16(14, 0)
	network_packet.encode_u8(16, out_trans)
	network_packet.encode_u8(17, out_ease)
	network_packet.encode_u8(18, out_auxiliary)

	return network_packet


# POSITION Command (0x03)
# Direct position control for manual operation.
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │  POSITION  │
# │0x03│   (u32)    │
# └────┴────────────┘
#
# POSITION - Target position 0-10000 (u32)
static func create_position_command(target_position: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u8(0, OSSM.Command.POSITION)
	network_packet.encode_u32(1, target_position)

	return network_packet


# VIBRATE Command (0x04)
# Configures vibration pattern with adjustable waveform.
#
# **Packet Size:** 13 bytes
#
# ┌────┬─────────────┬─────────────┬────────┬────────┬────────┐
# │ 0  │    1-4      │    5-8      │  9-10  │   11   │   12   │
# ├────┼─────────────┼─────────────┼────────┼────────┼────────┤
# │CMD │ DURATION_MS │ HALF_PERIOD │  POS   │ RANGE  │ SMOOTH │
# │0x04│    (s32)    │    (u32)    │ (u16)  │  (u8)  │  (u8)  │
# └────┴─────────────┴─────────────┴────────┴────────┴────────┘
#
# DURATION_MS  - Duration (-1=infinite, 0=stop) (s32)
# HALF_PERIOD  - Half period in ms (frequency) (u32)
# POS          - Origin position 0-10000 (u16)
# RANGE        - Stroke range 0-100% (u8)
# SMOOTH       - Waveform smoothing 100-200 (u8)
#               100 = Triangle wave
#               200 = Square wave
#               101-199 = Interpolated
static func create_vibrate_command(duration: int, half_period_ms: int, origin_position: int, range_percent: int, waveform: int):
	var network_packet: PackedByteArray
	network_packet.resize(13)

	network_packet.encode_u8(0, OSSM.Command.VIBRATE)
	network_packet.encode_s32(1, duration)
	network_packet.encode_u32(5, half_period_ms)
	network_packet.encode_u16(9, origin_position)
	network_packet.encode_u8(11, range_percent)
	network_packet.encode_u8(12, waveform)

	return network_packet


# PLAY Command (0x05)
# Starts playback in specified mode.
#
# **Packet Size:** 2 or 6 bytes
#
# Basic (2 bytes):
# ┌────┬────────┐
# │ 0  │   1    │
# ├────┼────────┤
# │CMD │  MODE  │
# │0x05│  (u8)  │
# └────┴────────┘
#
# With timestamp - start from given ms (6 bytes):
# ┌────┬────────┬────────────┐
# │ 0  │   1    │    2-5     │
# ├────┼────────┼────────────┤
# │CMD │  MODE  │  TIME_MS   │
# │0x05│  (u8)  │   (u32)    │
# └────┴────────┴────────────┘
#
# MODE values:
# 0 - IDLE
# 1 - HOMING
# 2 - MOVE
# 3 - POSITION
# 4 - LOOP
# 5 - VIBRATE
static func create_play_command(play_time_ms = null):
	var network_packet: PackedByteArray

	if play_time_ms != null:
		network_packet.resize(6)
		network_packet.encode_u8(0, OSSM.Command.PLAY)
		network_packet.encode_u8(1, AppMode.active)
		network_packet.encode_u32(2, play_time_ms)
	else:
		network_packet.resize(2)
		network_packet.encode_u8(0, OSSM.Command.PLAY)
		network_packet.encode_u8(1, AppMode.active)
	
	return network_packet


# PAUSE Command (0x06)
# Pauses current motion.
#
# **Packet Size:** 1 byte
#
# ┌────┐
# │ 0  │
# ├────┤
# │CMD │
# │0x06│
# └────┘
static func create_pause_command():
	var network_packet: PackedByteArray
	network_packet.resize(1)

	network_packet[0] = OSSM.Command.PAUSE
	
	return network_packet


# RESET Command (0x07)
# Clears motion queue and resets playback.
#
# **Packet Size:** 1 byte
#
# ┌────┐
# │ 0  │
# ├────┤
# │CMD │
# │0x07│
# └────┘
static func create_reset_command():
	var network_packet: PackedByteArray
	network_packet.resize(1)

	network_packet[0] = OSSM.Command.RESET
	
	return network_packet


# HOMING Command (0x08)
# Initiates homing to specified position.
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │  POSITION  │
# │0x08│   (u32)    │
# └────┴────────────┘
#
#POSITION - Target home position 0-10000 (u32)
static func create_homing_command(target_position: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u8(0, OSSM.Command.HOMING)
	network_packet.encode_s32(1, target_position)

	return network_packet


# CONNECTION Command (0x09)
# Handshake/connection verification.
#
# **Packet Size:** 1 byte
#
# ┌────┐
# │ 0  │
# ├────┤
# │CMD │
# │0x09│
# └────┘
static func create_connection_command():
	var network_packet: PackedByteArray
	network_packet.resize(1)

	network_packet[0] = OSSM.Command.CONNECTION

	return network_packet


# SET_SPEED_LIMIT Command (0x0A)
# Sets motor speed limit across all app modes.
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │  SPEED_HZ  │
# │0x0A│   (u32)    │
# └────┴────────────┘
#
# SPEED_HZ - Maximum speed in steps/sec (u32)
static func create_set_speed_limit_command(steps_per_sec: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u8(0, OSSM.Command.SET_SPEED_LIMIT)
	network_packet.encode_u32(1, steps_per_sec)

	return network_packet


# SET_GLOBAL_ACCELERATION Command (0x0B)
# Sets motor acceleration limit across all app modes.
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │   ACCEL    │
# │0x0B│   (u32)    │
# └────┴────────────┘
#
# ACCEL - Maximum acceleration in steps/sec² (u32)
static func create_set_global_acceleration_command(acceleration: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u8(0, OSSM.Command.SET_GLOBAL_ACCELERATION)
	network_packet.encode_u32(1, acceleration)

	return network_packet


# SET_RANGE_LIMIT Command (0x0C)
# Sets motion range limits for either end of the rail.
#
# **Packet Size:** 4 bytes
#
# ┌────┬────────┬────────┐
# │ 0  │   1    │  2-3   │
# ├────┼────────┼────────┤
# │CMD │ RANGE  │ LIMIT  │
# │0x0C│  (u8)  │ (u16)  │
# └────┴────────┴────────┘
#
# RANGE - 0 = MIN_RANGE, 1 = MAX_RANGE (u8)
# LIMIT - Position limit 0-10000 (u16)
static func create_set_range_limit_command(range_limit_type: OSSM.RangeLimitType, range_limit: int):
	var network_packet: PackedByteArray
	network_packet.resize(4)

	network_packet.encode_u8(0, OSSM.Command.SET_RANGE_LIMIT)
	network_packet.encode_u8(1, range_limit_type)
	network_packet.encode_u16(2, range_limit)

	return network_packet


# SET_HOMING_SPEED Command (0x0D)
# Sets position syncing movement speed.
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │  SPEED_HZ  │
# │0x0D│   (u32)    │
# └────┴────────────┘

# SPEED_HZ - Position syncing speed in steps/sec (u32)
static func create_set_homing_speed_command(steps_per_sec: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u32(0, OSSM.Command.SET_HOMING_SPEED)
	network_packet.encode_u32(1, steps_per_sec)
	
	return network_packet


# SET_HOMING_TRIGGER Command (0x0E)
# Sets power spike threshold for sensorless homing. (Lower = more sensitive)
#
# **Packet Size:** 5 bytes
#
# ┌────┬────────────┐
# │ 0  │    1-4     │
# ├────┼────────────┤
# │CMD │ THRESHOLD  │
# │0x0E│   (u32)    │
# └────┴────────────┘
#
# THRESHOLD - Voltage threshold for edge detection (u32)
static func create_set_homing_trigger_command(threshold_voltage: int):
	var network_packet: PackedByteArray
	network_packet.resize(5)

	network_packet.encode_u32(0, OSSM.Command.SET_HOMING_TRIGGER)
	network_packet.encode_u32(1, threshold_voltage)

	return network_packet


## SMOOTH_MOVE Command (0x0F)
## Controls point-to-point motion with easing curves.
## 
## **Packet Size:** 10 bytes
## 
## ┌────┬───────────┬────────┬────────┬────────┬────────┐
## │ 0  │    1-4    │  5-6   │   7    │   8    │   9    │
## ├────┼───────────┼────────┼────────┼────────┼────────┤
## │CMD │DURATION_MS│  POS   │ TRANS  │  EASE  │  AUX   │
## │0x0F│   (u32)   │ (u16)  │  (u8)  │  (u8)  │  (u8)  │
## └────┴───────────┴────────┴────────┴────────┴────────┘
## 
## CMD         - Command type (SMOOTH_MOVE = 0x0F)
## DURATION_MS - Move duration time in milliseconds (u32)
## POS         - Target position 0-10000 (u16)
## TRANS       - Transition type (u8)
## EASE        - Easing type (u8)
## AUX         - Auxiliary functions bitmask (u8)
## 
## **Transition Types:**
## - 0: LINEAR
## - 1: SINE
## - 2: CIRC
## - 3: EXPO
## - 4: QUAD
## - 5: CUBIC
## - 6: QUART
## - 7: QUINT
## 
## **Easing Types:**
## - 0: EASE_IN
## - 1: EASE_OUT
## - 2: EASE_IN_OUT
## - 3: EASE_OUT_IN
static func create_smooth_move_command(ms_duration: int, target_position: int, trans: int, ease: int, auxiliary: int):
	var network_packet: PackedByteArray
	network_packet.resize(10)

	network_packet.encode_u8(0, OSSM.Command.SMOOTH_MOVE)
	network_packet.encode_u32(1, ms_duration)
	command.encode_u16(5, abs(Global.motor_direction * 10000 - target_position))
	network_packet.encode_u8(7, trans)
	network_packet.encode_u8(8, ease)
	network_packet.encode_u8(9, auxiliary)

	return network_packet
