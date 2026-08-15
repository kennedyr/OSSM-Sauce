extends Control

var app_version_number: String = ProjectSettings.get_setting("application/config/version")


var path_speed: int = 30

var _seek_dragging := false

var funscripts: Array = []

var buffer_size: int = 30
var buffer_sent: int
var play_offset_ms: int
var _seeking: bool


@onready var PATH_TOP = $PathDisplay/PathArea.position.y
@onready var PATH_BOTTOM = PATH_TOP + $PathDisplay/PathArea.size.y

var current_funscript:
	get:
		if Global.active_path_index >= 0 and Global.active_path_index < funscripts.size():
			return funscripts[Global.active_path_index]

func _ready():
	set_process(false)
	OS.request_permissions()
	
	var physics_ticks = "physics/common/physics_ticks_per_second"
	Global.ticks_per_second = ProjectSettings.get_setting(physics_ticks)
	
	Global.min_stroke_duration = $Menu/LoopSettings/MinStrokeDuration/Input.value
	Global.max_stroke_duration = $Menu/LoopSettings/MaxStrokeDuration/Input.value
	
	for node in [$Menu, $Settings, $SpeedPanel, $RangePanel]:
		node.self_modulate.a = 1.65
	
	$PathDisplay/Ball.position.x = $PathDisplay/PathArea.size.x / 2
	
	%FileUtil.check_root_directory()
	
	UserSettings.initialize()
	apply_user_settings()
	
	$Menu/VersionLabel.text = "v" + app_version_number
	%WebSocket.start_server()
	
	%VideoPlayer.player_played.connect(_on_video_player_played)
	%VideoPlayer.player_paused.connect(_on_video_player_paused)
	%VideoPlayer.player_seeked.connect(_on_video_player_seeked)
	
	if OS.get_name() != 'Android':
		var window_size = get_viewport().size
		var screen_size = DisplayServer.screen_get_size()
		var centered_position = Vector2(
			(screen_size.x - window_size.x) / 2,
			(screen_size.y - window_size.y) / 2)
		DisplayServer.window_set_position(centered_position)
		get_viewport().size_changed.connect(_on_window_size_changed)


var buffer_marker_index: int
var marker_index: int
func _physics_process(_delta) -> void:
	if Global.paused or Global.active_path_index == null:
		return

	if current_funscript.path.is_empty():
		return

	var total_frames: int = current_funscript.path.size()
	# End of current path
	if Global.frame >= total_frames - 1:
		# There is a next path in playlist
		if Global.active_path_index < funscripts.size() - 1:
			transition_to_path(Global.active_path_index + 1)
		elif $Menu.loop_playlist:
			# Loop the playlist
			transition_to_path(0)
		else:
			# Nothing to do
			Global.paused = true
			%OSSMCommand.pause()
			%VideoPlayer.pause_player()
			$Menu.show_play()
			$CircleSelection.show_restart()
		return
	
	var frames = current_funscript.frames
	var active_path = current_funscript.network_paths

	var current_marker = buffer_marker_index - buffer_sent
	if current_marker < frames.size() and Global.frame == frames[current_marker]:
		if %WebSocket.server_started:
			if buffer_marker_index < active_path.size():
				# send current frame to 
				%OSSMCommand.broadcast_binary(active_path[buffer_marker_index])
			elif Global.active_path_index < funscripts.size() - 1:
				var overreach_index = buffer_marker_index - active_path.size()
				var next_funscript = funscripts[Global.active_path_index + 1]
				var next_path = next_funscript.network_paths
				if overreach_index < next_path.size():
					%OSSMCommand.broadcast_binary(next_path[overreach_index])
			elif $Menu.loop_playlist:
				var overreach_index = buffer_marker_index - active_path.size()
				var next_path = funscripts[0].network_paths
				if overreach_index < next_path.size():
					%OSSMCommand.broadcast_binary(next_path[overreach_index])
		if current_marker < frames.size() - 1:
			buffer_marker_index += 1


	if marker_index < frames.size() - 1 and Global.frame == frames[marker_index]:
		var current_action = current_funscript.marker_data[frames[marker_index]]
		var next_action = current_funscript.marker_data[frames[marker_index + 1]]
		var speed = Util.get_base_move_speed_hz(next_action, current_action, Global.min_range_limit, Global.max_range_limit)
		var ball_color = Color.WHITE
		if speed > Global.speed_limit:
			ball_color = Color(1, 0.498039, 0.313726, 1) # orange

		$PathDisplay/Ball.self_modulate = ball_color
		marker_index += 1

	
	var depth: float = current_funscript.path[Global.frame]
	$PathDisplay/Paths.get_child(Global.active_path_index).position.x -= path_speed
	$PathDisplay/Ball.position.y = render_depth(depth)

	if not _seek_dragging:
		$SeekSlider.set_value_no_signal(float(Global.frame) / (total_frames - 1))
		update_time_display()

	Global.frame += 1


func transition_to_path(next_index: int):
	var overreach_sent = maxi(buffer_marker_index - current_funscript.network_paths.size(), 0)
	var next_path = funscripts[next_index].network_paths
	Global.active_path_index = next_index
	display_active_path_index(false, false)
	# Top up buffer if overreach didn't cover it
	buffer_marker_index = overreach_sent
	buffer_sent = overreach_sent
	while buffer_sent < buffer_size and buffer_marker_index < next_path.size():
		%OSSMCommand.broadcast_binary(next_path[buffer_marker_index])
		buffer_marker_index += 1
		buffer_sent += 1
	var path_list = $Menu/Playlist/Scroll/VBox
	$Menu/Playlist._on_item_selected(path_list.get_child(next_index))
	path_list.get_child(next_index).set_active()


func home_to(target_position: int):
	if %WebSocket.ossm_connected:
		%CircleSelection.show_hourglass()
		%ActionPanel.disable_buttons(true)
		var displays = [
			%PathDisplay,
			%PositionControls,
			%LoopControls,
			%VibrationControls,
			%BridgeControls,
			%ActionPanel,
			%VideoPlayer,
			%Settings,
			%AddFile,
			%Menu]
		for display in displays:
			display.modulate.a = 0.05
		%OSSMCommand.home_to(abs(Global.motor_direction * 10000 - target_position))


func play():
	if AppMode.active == AppMode.MOVE and Global.active_path_index != null:
		Global.paused = false
		play_offset_ms = int(Global.frame * 1000.0 / Global.ticks_per_second)
	if %WebSocket.ossm_connected:
		if AppMode.active == AppMode.MOVE:
			%OSSMCommand.set_acceleration_limit(60000)
		%OSSMCommand.play(play_offset_ms)
		# Restore user's acceleration after a comfortable ramp-up
		$PathDisplay/AccelTimer.start(0.8)


func pause():
	Global.paused = true
	if not %WebSocket.ossm_connected:
		return
	%OSSMCommand.pause()

	if Global.active_path_index == null:
		return
	if AppMode.active != AppMode.MOVE or current_funscript.path.is_empty():
		return
	
	# Sync OSSM to current path position
	var current_depth: float = current_funscript.path[Global.frame]
	%OSSMCommand.reset()
	home_to(round(current_depth * 10000))
	await Global.homing_complete
	if not %WebSocket.ossm_connected:
		return
	
	# Find cascade and buffer start for current frame
	var frames = current_funscript.frames
	var buffer_start := 0
	var cascade_index := 0
	for i in frames.size():
		if frames[i] <= Global.frame:
			cascade_index = i
			buffer_start = i + 1
		else:
			break
	
	# Send cascade packet + buffer
	%OSSMCommand.broadcast_binary(current_funscript.network_paths[cascade_index])
	buffer_marker_index = buffer_start
	buffer_sent = 0
	while buffer_sent < buffer_size and buffer_marker_index < current_funscript.network_paths.size():
		%OSSMCommand.broadcast_binary(current_funscript.network_paths[buffer_marker_index])
		buffer_marker_index += 1
		buffer_sent += 1
	
	# Reduce acceleration and nudge in both directions to force direction change
	%OSSMCommand.set_acceleration_limit(60000)
	var depth_val: int = abs(Global.motor_direction * 10000 - round(current_depth * 10000))
	var nudge: PackedByteArray
	nudge.resize(10)
	nudge.encode_u8(0, OSSM.Command.SMOOTH_MOVE)
	nudge.encode_u8(7, 0) # TRANS_LINEAR
	nudge.encode_u8(8, 0) # EASE_IN
	nudge.encode_u8(9, 0)
	# Nudge out
	nudge.encode_u32(1, 100)
	nudge.encode_u16(5, clampi(depth_val + 500, 0, 10000))
	%OSSMCommand.broadcast_binary(nudge)
	await get_tree().create_timer(0.15).timeout
	# Nudge in (guaranteed direction change)
	nudge.encode_u16(5, clampi(depth_val - 500, 0, 10000))
	%OSSMCommand.broadcast_binary(nudge)
	await get_tree().create_timer(0.15).timeout
	# Return to position
	nudge.encode_u16(5, clampi(depth_val, 0, 10000))
	%OSSMCommand.broadcast_binary(nudge)


func apply_user_settings():
	var cfg_version_number = UserSettings.get_value(UserSettings.Section.app_settings, 'version_number')
	if cfg_version_number.naturalcasecmp_to("1.5") < 0:
		UserSettings.clear()
		UserSettings.set_value(UserSettings.Section.app_settings, 'version_number', app_version_number)
		UserSettings.save()

	if OS.get_name() != 'Android':
		DisplayServer.window_set_size(UserSettings.get_value(UserSettings.Section.window, 'size', Vector2(435, 774)))
		
		$Settings/VBox/AlwaysOnTop.button_pressed = UserSettings.get_value(UserSettings.Section.window, 'always_on_top', false)

		# $Settings/Window/TransparentBg/CheckBox.button_pressed = UserSettings.get_value(UserSettings.Section.window, 'transparent_background', false)

	if UserSettings.get_value(UserSettings.Section.app_settings, 'show_splash', true):
		$Splash.show()
	
	_check_storage_setup()
	
	var port_number = UserSettings.get_value(UserSettings.Section.network, 'port', %WebSocket.port)
	$Settings/VBox/Network/Port/Input.value = port_number
	%WebSocket.port = port_number
	
	var motor_direction = UserSettings.get_value(UserSettings.Section.device_settings, 'motor_direction', 0)
	$Settings/VBox/ReverseMotorDirection.button_pressed = bool(motor_direction)
	
	apply_device_settings()
	
	$PositionControls/Smoothing/HSlider.set_value(UserSettings.get_value(UserSettings.Section.app_settings, 'smoothing_slider', 16.0))
	$Menu.set_min_stroke_duration(UserSettings.get_value(UserSettings.Section.stroke_settings, 'min_duration', 0.2))
	$Menu.set_max_stroke_duration(UserSettings.get_value(UserSettings.Section.stroke_settings, 'max_duration', 10.0))
	$Menu.set_stroke_duration_display_mode(UserSettings.get_value(UserSettings.Section.stroke_settings, 'display_mode', 0))
	
	$LoopControls/In/AccelerationControls/Transition.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 1))
	Global.transition = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 1)
	$LoopControls/In/AccelerationControls/Easing.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2))
	Global.easing = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2)
	$LoopControls/Out/AccelerationControls/Transition.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'out_trans', 1))
	$LoopControls/Out/AccelerationControls/Easing.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'out_ease', 2))

	$LoopControls.draw_easing()
	
	if UserSettings.get_value(UserSettings.Section.bridge_settings, 'min_move_duration') \
			or UserSettings.get_value(UserSettings.Section.bridge_settings, 'max_move_duration'):
		%BridgeControls.set_move_duration_limits(
				UserSettings.get_value(UserSettings.Section.bridge_settings, 'min_move_duration', 500),
				UserSettings.get_value(UserSettings.Section.bridge_settings, 'max_move_duration', 6000))
	if UserSettings.get_value(UserSettings.Section.bridge_settings, 'bridge_mode'):
		var bridge_mode = UserSettings.get_value(UserSettings.Section.bridge_settings, 'bridge_mode')
		%Menu/BridgeSettings/BridgeMode/ModeSelection.selected = bridge_mode
		$Menu._on_bridge_mode_selected(bridge_mode)
	if UserSettings.get_value(UserSettings.Section.bridge_settings, 'logging_enabled'):
		%Menu/BridgeSettings/LoggingEnabled.button_pressed = UserSettings.get_value(UserSettings.Section.bridge_settings, 'logging_enabled')
	
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'server_address'):
		%Menu/BridgeSettings/BPIO/ServerAddress/Input.text = UserSettings.get_value(UserSettings.Section.bpio_settings, 'server_address')
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'server_port'):
		%Menu/BridgeSettings/BPIO/Ports/ServerPort/Input.value = UserSettings.get_value(UserSettings.Section.bpio_settings, 'server_port')
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'wsdm_port'):
		%Menu/BridgeSettings/BPIO/Ports/WSDMPort/Input.value = UserSettings.get_value(UserSettings.Section.bpio_settings, 'wsdm_port')
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'identifier'):
		%Menu/BridgeSettings/BPIO/Identifier/Input.text = UserSettings.get_value(UserSettings.Section.bpio_settings, 'identifier')
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'client_name'):
		%Menu/BridgeSettings/BPIO/ClientName/Input.text = UserSettings.get_value(UserSettings.Section.bpio_settings, 'client_name')
	if UserSettings.get_value(UserSettings.Section.bpio_settings, 'address'):
		%Menu/BridgeSettings/BPIO/Address/Input.text = UserSettings.get_value(UserSettings.Section.bpio_settings, 'address')
	
	if UserSettings.get_value(UserSettings.Section.xtoys_settings, 'port'):
		%Menu/BridgeSettings/XToys/Port/Input.value = UserSettings.get_value(UserSettings.Section.xtoys_settings, 'port')
	if UserSettings.get_value(UserSettings.Section.xtoys_settings, 'max_msg_frequency'):
		%Menu/BridgeSettings/XToys/MaxMsgFrequency/Input.set_value_no_signal(
				UserSettings.get_value(UserSettings.Section.xtoys_settings, 'max_msg_frequency'))
	if UserSettings.get_value(UserSettings.Section.xtoys_settings, 'use_command_duration'):
		%Menu/BridgeSettings/XToys/UseCommandDuration.button_pressed = UserSettings.get_value(UserSettings.Section.xtoys_settings, 'use_command_duration')
	
	if UserSettings.get_value(UserSettings.Section.video_player, 'player_address'):
		%VideoPlayer.player_address = UserSettings.get_value(UserSettings.Section.video_player, 'player_address')
		%VideoPlayer/Main/PlayerAddress/Input.text = %VideoPlayer.player_address
	if UserSettings.get_value(UserSettings.Section.video_player, 'vlc_password'):
		%VideoPlayer.vlc_password = UserSettings.get_value(UserSettings.Section.video_player, 'vlc_password')
		%VideoPlayer/Main/VLCPassword/Input.text = %VideoPlayer.vlc_password
	if UserSettings.get_value(UserSettings.Section.video_player, 'video_offset_ms'):
		%VideoPlayer/Main/VideoOffset/Input.value = UserSettings.get_value(UserSettings.Section.video_player, 'video_offset_ms')
	if UserSettings.get_value(UserSettings.Section.video_player, 'vlc_seek_correction'):
		%VideoPlayer/Main/VLCSeekCorrection/Input.value = UserSettings.get_value(UserSettings.Section.video_player, 'vlc_seek_correction')
	if UserSettings.get_value(UserSettings.Section.video_player, 'player_type'):
		var vp_type: int = UserSettings.get_value(UserSettings.Section.video_player, 'player_type')
		if OS.get_name() != "Android" and vp_type == 4:
			vp_type = 0
		%VideoPlayer/Main/PlayerSelection.select(vp_type)
		%VideoPlayer._on_player_selection_item_selected(vp_type)
	
	$Menu.select_mode(UserSettings.get_value(UserSettings.Section.app_settings, 'mode', 1))


func apply_device_settings():
	Global.max_speed = UserSettings.get_value(UserSettings.Section.speed_slider, 'max_speed', 25000)
	Global.max_acceleration = UserSettings.get_value(UserSettings.Section.accel_slider, 'max_acceleration', 500000)
	$SpeedPanel.set_speed_slider_pos(UserSettings.get_value(UserSettings.Section.speed_slider, 'position_percent', 0.6))
	$SpeedPanel.set_acceleration_slider_pos(UserSettings.get_value(UserSettings.Section.accel_slider, 'position_percent', 0.4))
	$RangePanel.set_min_slider_pos(UserSettings.get_value(UserSettings.Section.range_slider_min, 'position_percent', 0))
	$RangePanel.set_max_slider_pos(UserSettings.get_value(UserSettings.Section.range_slider_max, 'position_percent', 1))
	$Settings.set_syncing_speed(UserSettings.get_value(UserSettings.Section.device_settings, 'syncing_speed', 1000))
	$Settings.set_homing_trigger(UserSettings.get_value(UserSettings.Section.device_settings, 'homing_trigger', 1.5))

	$SpeedPanel.send_speed_limits()
	$RangePanel.send_range_limits()


func load_path_file_name(file_name: String) -> bool:
	var file_path = %FileUtil._resolve_storage_path(file_name, "paths")
	return load_path(file_path)

func load_raw(file_text: String) -> bool:
	var funscript = Funscript.new()
	funscript.load_string(file_text, true)
	if not funscript.marker_data:
		printerr("Error: Failed to read file.")
		return false

	if funscript.marker_data.size() < buffer_size:
		printerr("Error: Insufficient path data in file.")
		return false

	funscripts.append(funscript)
	create_path_line(funscript.path)
	var index = %Menu/Playlist.add_item("virtual")
	%Menu/Playlist.select_item_index(index)

	return true

func load_path(file_path: String) -> bool:
	var funscript = Funscript.new()
	funscript.load_path(file_path)
	if not funscript.marker_data:
		printerr("Error: Failed to read file.")
		return false

	if funscript.marker_data.size() < buffer_size:
		printerr("Error: Insufficient path data in file.")
		return false

	funscripts.append(funscript)
	create_path_line(funscript.path)

	return true

func create_path_line(path: PackedFloat32Array):
	var path_line := Line2D.new()
	path_line.width = 15
	path_line.hide()
	for step in len(path):
		var step_depth = path[step]
		var x_pos = step * path_speed
		var y_pos = render_depth(step_depth)
		path_line.add_point(Vector2(x_pos, y_pos))
	$PathDisplay/Paths.add_child(path_line)

#TODO
func create_delay(duration: float):
	if Global.active_path_index == null:
		return

	var delay_path: PackedFloat32Array
	var path_line := Line2D.new()
	path_line.hide()
	for point in round(duration * Global.ticks_per_second):
		delay_path.append(-1)
	var frames: PackedInt32Array
	var network_packets: Array
	for timing in buffer_size:
		var move_command = OSSMCommand.create_move_command(timing, 0, 0, 0, 0)
		network_packets.append(move_command)
		frames.append(timing)
	var end_move = OSSMCommand.create_move_command(int(duration * 1000), 0, 0, 0, 0)
	network_packets.append(end_move)
	current_funscript.network_paths.append(network_packets)
	current_funscript.path.append(delay_path)
	current_funscript.frames.append(frames)
	$PathDisplay/Paths.add_child(path_line)
	$Menu/Playlist.add_item("delay(%s)" % [duration])


func display_active_path_index(pause_now := true, send_buffer := true):
	if Global.active_path_index == null:
		return

	Global.paused = pause_now
	Global.frame = 0
	marker_index = 0
	buffer_marker_index = 0
	play_offset_ms = 0
	init_seek_slider()
	update_time_display()
	if send_buffer:
		if %WebSocket.ossm_connected:
			%OSSMCommand.reset()
			var start_depth: float = current_funscript.path[0]
			home_to(round(start_depth * 10000))
			await Global.homing_complete
			if not %WebSocket.ossm_connected:
				return
			buffer_sent = 0
			while buffer_sent < buffer_size and buffer_marker_index < current_funscript.network_paths.size():
				%OSSMCommand.broadcast_binary(current_funscript.network_paths[buffer_marker_index])
				buffer_marker_index += 1
				buffer_sent += 1
	else:
		buffer_marker_index = buffer_size
		buffer_sent = buffer_size
	
	$ActionPanel.clear_selections()
	if pause_now:
		$ActionPanel/Pause.hide()
		$ActionPanel/Play.show()
	for path in $PathDisplay/Paths.get_children():
		path.hide()
	var path = $PathDisplay/Paths.get_child(Global.active_path_index)
	path.position.x = ($PathDisplay/PathArea.size.x / 2) + path_speed
	path.show()
	$PathDisplay/Ball.position.y = render_depth(current_funscript.path[0])
	$PathDisplay/Ball.show()
	$PathDisplay.show()

	if %VideoPlayer.is_active() and AppMode.active == AppMode.MOVE:
		%VideoPlayer.sync_seek(0.0)


func init_seek_slider():
	$SeekSlider.set_value_no_signal(0.0)
	var total_frames: int = current_funscript.path.size()
	$SeekSlider/ChapterList.initialize(current_funscript.chapters, total_frames)


func seek(snap = true) -> void:
	if Global.active_path_index == null or _seeking:
		return
	_seeking = true
	if not Global.paused:
		Global.paused = true
		%OSSMCommand.pause()
		%ActionPanel.clear_selections()
		%ActionPanel/Pause.hide()
		%ActionPanel/Play.show()
		%CircleSelection.hide()
	
	var active_path = current_funscript.path
	if active_path.is_empty():
		_seeking = false
		return
	
	var value = $SeekSlider.value
	
	var total_frames: int = active_path.size()
	var target_frame := clampi(roundi(value * (total_frames - 1)), 0, total_frames - 1)

	if snap:
		var nearest_chapter_result = current_funscript.get_nearest_chapter(target_frame)
		if nearest_chapter_result:
			var new_target_frame = nearest_chapter_result["chapter"].begin_frame
			$SeekSlider.set_value_no_signal(float(new_target_frame) / (total_frames - 1))
			var snapped_chapter_tick: TextureRect = $SeekSlider/ChapterList.get_child(nearest_chapter_result["index"])
			if snapped_chapter_tick:
				snapped_chapter_tick.flash()
			target_frame = new_target_frame

	var target_depth: float = active_path[target_frame]
	play_offset_ms = int(target_frame * 1000.0 / Global.ticks_per_second)

	# Find the first marker_frame index AFTER target_frame
	var frames = current_funscript.frames
	var buffer_start := 0
	var cascade_index := 0
	for i in frames.size():
		if frames[i] <= target_frame:
			cascade_index = i
			buffer_start = i + 1
		else:
			break
	
	# Update display
	Global.frame = target_frame
	marker_index = buffer_start
	var path_line = $PathDisplay/Paths.get_child(Global.active_path_index)
	path_line.position.x = ($PathDisplay/PathArea.size.x / 2) + path_speed - (target_frame * path_speed)
	$PathDisplay/Ball.position.y = render_depth(target_depth)
	update_time_display()
	
	if %WebSocket.ossm_connected:
		%OSSMCommand.reset()
		home_to(round(target_depth * 10000))
		await Global.homing_complete
		if not %WebSocket.ossm_connected:
			_seeking = false
			return
		# Send cascade packet (timestamp <= play_offset, firmware immediately skips it)
		var cascade_packet = current_funscript.network_paths[cascade_index]
		%OSSMCommand.broadcast_binary(cascade_packet)
		# Send buffer packets from seek position
		buffer_marker_index = buffer_start
		buffer_sent = 0
		while buffer_sent < buffer_size and buffer_marker_index < current_funscript.network_paths.size():
			var packet = current_funscript.network_paths[buffer_marker_index]
			%OSSMCommand.broadcast_binary(packet)
			buffer_marker_index += 1
			buffer_sent += 1
	
	if %VideoPlayer.is_active():
		%VideoPlayer.pause_and_seek(play_offset_ms / 1000.0)
	
	_seeking = false
	_seek_dragging = false


func _on_seek_slider_drag_started() -> void:
	_seek_dragging = true


func _on_seek_slider_value_changed(value: float) -> void:
	if Global.active_path_index == null:
		return
	update_time_display(value)


func update_time_display(percent: float = -1) -> void:
	var frame: int
	var total_frames: int = current_funscript.path.size()
	if percent < 0 or percent > 1:
		frame = Global.frame
	else:
		frame = clampi(roundi(percent * (total_frames - 1)), 0, total_frames - 1)
	var current_sec := int(frame / float(Global.ticks_per_second))
	var total_sec := int((total_frames - 1) / float(Global.ticks_per_second))
	if total_sec >= 3600:
		$TimeDisplay.text = "%d:%02d:%02d / %d:%02d:%02d" % [
			int(current_sec / 3600.0), int(current_sec % 3600 / 60.0), current_sec % 60,
			int(total_sec / 3600.0), int(total_sec % 3600 / 60.0), total_sec % 60]
	else:
		$TimeDisplay.text = "%d:%02d / %d:%02d" % [
			int(current_sec / 60.0), current_sec % 60,
			int(total_sec / 60.0), total_sec % 60]

	var chapter = current_funscript.get_current_chapter(frame)
	var next_chapter = current_funscript.get_next_chapter(frame)
	$ChapterDisplay.text = "%s / %s" % [
		chapter.name if chapter else "",
		next_chapter.name if next_chapter else ""]


func render_depth(depth) -> float:
	return PATH_BOTTOM + depth * (PATH_TOP - PATH_BOTTOM)


func activate_move_mode():
	set_physics_process(true)
	%ActionPanel/Play.show()
	%ActionPanel/Pause.hide()
	%PathDisplay/PathArea.show()
	%PathDisplay/Paths.show()
	%PathDisplay/Ball.show()
	$SeekSlider.show()
	$TimeDisplay.show()
	$ChapterDisplay.show()
	%Menu/Main/PlaylistButtons.show()
	%Menu/Main/PathButtons.show()
	%Menu/Main/LoopAndVideoButtons/LoopPlaylistButton.show()
	%Menu/Main/LoopAndVideoButtons/VideoPlayerSync.show()
	%Menu/PathControls.show()
	%Menu/Playlist.show()
	if Global.active_path_index != null:
		display_active_path_index()
	%Menu.refresh_selection()


func deactivate_move_mode():
	set_physics_process(false)
	%ActionPanel/Play.hide()
	%ActionPanel/Pause.show()
	%PathDisplay.hide()
	%PathDisplay/Paths.hide()
	%PathDisplay/PathArea.hide()
	%PathDisplay/Ball.hide()
	$SeekSlider.hide()
	$TimeDisplay.hide()
	$ChapterDisplay.hide()
	%Menu/Main/PlaylistButtons.hide()
	%Menu/Main/PathButtons.hide()
	%Menu/Main/LoopAndVideoButtons/LoopPlaylistButton.hide()
	%Menu/Main/LoopAndVideoButtons/VideoPlayerSync.hide()
	%Menu/PathControls.hide()
	%Menu/Playlist.hide()


func _input(event: InputEvent) -> void: # Handle ui element outside click
	var pressed = (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	for spin_box in get_tree().get_nodes_in_group("spinboxes"):
		var line_edit: LineEdit = spin_box.get_line_edit()
		if not line_edit.has_focus():
			continue
		if not spin_box.get_global_rect().has_point(event.position):
			line_edit.release_focus()
	for line_edit in get_tree().get_nodes_in_group("lineedits"):
		if not line_edit.has_focus():
			continue
		if not line_edit.get_global_rect().has_point(event.position):
			line_edit.text_submitted.emit(line_edit.text)
			line_edit.release_focus()


func _on_window_size_changed():
	if OS.get_name() != "Android":
		var window_size = DisplayServer.window_get_size()
		UserSettings.set_value(UserSettings.Section.window, 'size', window_size)


func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		exit()
	# NOTIFICATION_WM_GO_BACK_REQUEST:  # Android back button
	# NOTIFICATION_APPLICATION_PAUSED:  # App going to background
	# NOTIFICATION_APPLICATION_FOCUS_OUT:


func exit():
	UserSettings.save()
	%BPIOBridge.stop_client()
	%BPIOBridge.stop_device()
	%XToysBridge.stop_xtoys()
	if %WebSocket.ossm_connected:
		Global.paused = true
		%OSSMCommand.pause()
		if Global.motor_direction == 0:
			%OSSMCommand.set_range_limit_min(Global.motor_direction * 10000)
		else:
			%OSSMCommand.set_range_limit_max(Global.motor_direction * 10000)
		home_to(1500)


func _on_video_player_played(video_time_seconds: float, from_stopped: bool):
	if Global.active_path_index == null or not Global.paused or AppMode.active != AppMode.MOVE:
		return
	if from_stopped:
		var path_time = float(Global.frame) / Global.ticks_per_second
		%VideoPlayer.pause_and_seek(path_time)
		return
	var total_frames: int = current_funscript.path.size()
	if total_frames == 0:
		return
	
	var target_frame = clampi(int(video_time_seconds * Global.ticks_per_second), 0, total_frames - 1)
	Global.frame = target_frame
	
	# Realign buffer tracking to new frame position
	var frames = current_funscript.frames
	var cascade_index := 0
	for i in frames.size():
		if frames[i] <= target_frame:
			cascade_index = i
		else:
			break
	marker_index = mini(cascade_index + 1, current_funscript.network_paths.size())
	buffer_marker_index = mini(cascade_index + 1 + buffer_sent, current_funscript.network_paths.size())
	
	# Update display
	var path_line = $PathDisplay/Paths.get_child(Global.active_path_index)
	path_line.position.x = ($PathDisplay/PathArea.size.x / 2) + path_speed - (target_frame * path_speed)
	$PathDisplay/Ball.position.y = render_depth(current_funscript.path[target_frame])
	$SeekSlider.set_value_no_signal(float(target_frame) / (total_frames - 1))
	update_time_display()
	
	# Play
	%ActionPanel.clear_selections()
	%ActionPanel/Play.hide()
	%ActionPanel/Pause.show()
	%CircleSelection.hide()
	play()


func _on_video_player_paused():
	if Global.paused or AppMode.active != AppMode.MOVE:
		return
	%ActionPanel.clear_selections()
	%ActionPanel/Pause.hide()
	%ActionPanel/Play.show()
	pause()


func _on_video_player_seeked(video_time_seconds: float):
	if Global.active_path_index == null or AppMode.active != AppMode.MOVE:
		return
	var total_frames: int = current_funscript.path.size()
	if total_frames == 0:
		return
	var target_frame = clampi(int(video_time_seconds * Global.ticks_per_second), 0, total_frames - 1)
	$SeekSlider.set_value_no_signal(float(target_frame) / (total_frames - 1))
	seek(false)


func _check_storage_setup() -> void:
	if !%FileUtil.check_storage_setup():
		show_pick_storage_folder()

func show_pick_storage_folder() -> void:
	$FolderPickSplash.show()

func pick_storage_folder() -> void:
	var err := DisplayServer.file_dialog_show(
			"Pick a folder for paths and playlists",
			"",
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
			PackedStringArray(),
			_on_storage_folder_picked)
	if err != OK:
		push_error("file_dialog_show failed: %s" % err)


func _on_storage_folder_picked(
		status: bool,
		_paths: PackedStringArray,
		_filter_idx: int) -> void:
	if not status or _paths.is_empty():
		return
	%FileUtil.storage_folder_picked(_paths)
	$FolderPickSplash.hide()


# func get_speed(prevMarker, prevDepth, marker, depth):
# 	var prevAt = prevMarker * 16.66666
# 	var at = marker * 16.66666
# 	var timeDiff = abs(at - prevAt);
# 	if timeDiff <= 0:
# 		return 0

# 	return 100000 * (abs(depth - prevDepth ) / timeDiff);
