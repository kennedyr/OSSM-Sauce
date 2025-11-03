extends Control

var app_version_number:String = "1.4.4"

var ticks_per_second:int

var path_speed:int = 30

var funscripts: Array

@onready var PATH_TOP = $PathDisplay/PathArea.position.y
@onready var PATH_BOTTOM = PATH_TOP + $PathDisplay/PathArea.size.y

@onready var ossm_connection_timeout:Timer = $Settings/Network/ConnectionTimeout


func _ready():	
	OS.request_permissions()

	var physics_ticks = "physics/common/physics_ticks_per_second"
	ticks_per_second = ProjectSettings.get_setting(physics_ticks)
	set_process(false)
	$PositionControls.set_physics_process(false)
	
	Global.min_stroke_duration = $Menu/LoopSettings/MinStrokeDuration/SpinBox.value
	Global.max_stroke_duration = $Menu/LoopSettings/MaxStrokeDuration/SpinBox.value
	
	Global.max_speed = int($Settings/Sliders/MaxSpeed/TextEdit.text)
	Global.max_acceleration = int($Settings/Sliders/MaxAcceleration/TextEdit.text)
	
	for node in [$Menu, $Settings, $SpeedPanel, $RangePanel]:
		node.self_modulate.a = 1.65
	
	$PathDisplay/Ball.position.x = $PathDisplay/PathArea.size.x / 2
	
	check_root_directory()
	
	UserSettings.initialize()
	apply_user_settings()

	%WebSocket.start_server()
	
	if OS.get_name() != 'Android':
		var window_size = get_viewport().size
		var screen_size = DisplayServer.screen_get_size()
		var centered_position = Vector2(
			(screen_size.x - window_size.x) / 2,
			(screen_size.y - window_size.y) / 2)
		DisplayServer.window_set_position(centered_position)
		get_viewport().size_changed.connect(_on_window_size_changed)


var marker_index:int
func _physics_process(_delta):
	if Global.paused or Global.active_path_index == null:
		return
	if funscripts[Global.active_path_index].paths.is_empty():
		return

	var current_funscript = funscripts[Global.active_path_index]
	# End of current path
	if Global.frame >= current_funscript.paths.size() - 1:
		# There is a next path in playlist
		if Global.active_path_index < funscripts.size() - 1:
			var next_funscript = funscripts[Global.active_path_index + 1]
			var overreach_index = marker_index - current_funscript.network_paths.size() + 1
			var next_path = next_funscript.network_paths
			%WebSocket.server.broadcast_binary(next_path[overreach_index])
			var path_list = $Menu/Playlist/Scroll/VBox
			var next_index = Global.active_path_index + 1
			var next_path_item = path_list.get_child(next_index) 
			Global.active_path_index = next_index
			display_active_path_index(false, false)
			$Menu/Playlist._on_item_selected(next_path_item)
			path_list.get_child(next_index).set_active()
		else:
			# Loop the playlist
			if $Menu.loop_playlist:
				var overreach_index = marker_index - current_funscript.network_paths.size() + 1
				var next_funscript = funscripts[0]
				var next_path = next_funscript.network_paths
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
				var path_list = $Menu/Playlist/Scroll/VBox
				var next_path_item = path_list.get_child(0) 
				Global.active_path_index = 0
				display_active_path_index(false, false)
				$Menu/Playlist._on_item_selected(next_path_item)
				path_list.get_child(0).set_active()
			# Nothing to do
			else:
				pause()
				$Menu.show_play()
				$CircleSelection.show_restart()
				Global.paused = true
		return
	
	var marker_list = current_funscript.markers
	var active_path = current_funscript.network_paths
	var current_marker = marker_index - 6
	var current_marker_frame = int(marker_list.keys()[current_marker])
	if Global.frame == current_marker_frame:
		if %WebSocket.server_started:
			if marker_index < active_path.size():
				# send current frame to 
				%WebSocket.server.broadcast_binary(active_path[marker_index])
			elif Global.active_path_index < funscripts.size() - 1:
				var overreach_index = marker_index - active_path.size()
				var next_path = funscripts[Global.active_path_index + 1].network_paths
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
			elif $Menu.loop_playlist:
				var overreach_index = marker_index - active_path.size()
				var next_path = funscripts[0].network_paths
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
		if current_marker < marker_list.size() - 1:
			marker_index += 1
	
	var depth:float = current_funscript.paths[Global.frame]
	var ms_timing: int = round((float(Global.frame) / 50) * 1000)
	var minutes: int = floori(ms_timing / 60000.0)
	var seconds: int = floori((ms_timing % 60000) / 1000.0)
	Global.frame += 1

	$PathDisplay/Paths.get_child(Global.active_path_index).position.x -= path_speed
	$PathDisplay/Ball.position.y = render_depth(depth)
	$PathDisplay/TimeLabel.text = "%02d:%02d" % [minutes, seconds]
	var chapter = current_funscript.get_current_chapter_name(ms_timing)
	if chapter:
		$PathDisplay/TimeLabel.text += " - " + chapter

func home_to(target_position:int):
	if %WebSocket.ossm_connected:
		$CircleSelection.show_hourglass()
		var displays = [
			$PositionControls,
			$LoopControls,
			$PathDisplay,
			$ActionPanel,
			$Menu]
		for display in displays:
			display.modulate.a = 0.05
		%OSSMCommand.home_to(target_position)


func play():
	var play_time_ms = null
	var next_play_time_ms = Global.next_play_time_ms
	if next_play_time_ms:
		play_time_ms = next_play_time_ms

	%OSSMCommand.play(play_time_ms)
	if AppMode.active == AppMode.MOVE and Global.active_path_index != null:
		Global.paused = false
		MPV.play()


func pause():
	if AppMode.active == AppMode.MOVE and Global.active_path_index != null:
		MPV.pause()
	%OSSMCommand.pause()
	Global.paused = true


func seek_to(play_time_ms:int):
	print("seek_to ", play_time_ms)
	if not Global.paused:
		print("Must be paused to seek")
		return

	var current_funscript = funscripts[Global.active_path_index]
	var frame = round((play_time_ms / 1000.0) * 50)
	print("seek_to frame", frame)
	Global.frame = frame
	marker_index = current_funscript._find_prev_marker_for_frame(frame)
	if %WebSocket.ossm_connected:
		%OSSMCommand.reset()
		%WebSocket.server.broadcast_binary(current_funscript.network_paths[marker_index])
		marker_index += 1
		#while marker_index < 6:
			#%WebSocket.server.broadcast_binary(network_paths[Global.active_path_index][marker_index])
			#marker_index += 1
	Global.next_play_time_ms = play_time_ms
	MPV.seek_to(play_time_ms)
	var original_path_start_position = ($PathDisplay/PathArea.size.x / 2) + path_speed
	$PathDisplay/Paths.get_child(Global.active_path_index).position.x = original_path_start_position - (frame * path_speed)
	var new_current_depth = render_depth(current_funscript.paths[(frame - 1 if frame > 0 else 0)])
	$PathDisplay/Ball.position.y = new_current_depth
	
	var minutes: int = floori(play_time_ms / 60000.0)
	var seconds: int = floori((play_time_ms % 60000) / 1000.0)

	$PathDisplay/TimeLabel.text = "%02d:%02d" % [minutes, seconds]
	var chapter = current_funscript.get_current_chapter_name(play_time_ms)
	if chapter:
		$PathDisplay/TimeLabel.text += " - " + chapter

func check_root_directory():
	var dir = DirAccess.open(Global.storage_dir)
	if not dir.dir_exists("OSSM Sauce"):
		dir.make_dir("OSSM Sauce")
	dir.change_dir("OSSM Sauce")
	for directory in ["Paths", "Playlists"]:
		if not dir.dir_exists(directory):
			dir.make_dir(directory)


func apply_user_settings():
	var cfg_version_number = UserSettings.get_value(UserSettings.Section.app_settings, 'version_number')
	if cfg_version_number != app_version_number:
		UserSettings.clear()
		UserSettings.set_value(UserSettings.Section.app_settings, 'version_number', app_version_number)
		UserSettings.save()
	
	if OS.get_name() != 'Android':
		DisplayServer.window_set_size(UserSettings.get_value(UserSettings.Section.window, 'size', Vector2(435, 774)))
		
	$Settings/Window/AlwaysOnTop/CheckBox.button_pressed = UserSettings.get_value(UserSettings.Section.window, 'always_on_top', false)
	$Settings/Window/TransparentBg/CheckBox.button_pressed = UserSettings.get_value(UserSettings.Section.window, 'transparent_background', false)
	if UserSettings.get_value(UserSettings.Section.app_settings, 'show_splash', true):
		$Splash.show()
	
	var port_number = UserSettings.get_value(UserSettings.Section.network, 'port', %WebSocket.port)
	$Settings/Network/Port/TextEdit.text = str(port_number)
	%WebSocket.port = port_number
	
	apply_device_settings()
	
	$PositionControls/Smoothing/HSlider.set_value(UserSettings.get_value(UserSettings.Section.app_settings, 'smoothing_slider', 16.0))
	$Menu.set_min_stroke_duration(UserSettings.get_value(UserSettings.Section.stroke_settings, 'min_duration', 0.2))
	$Menu.set_max_stroke_duration(UserSettings.get_value(UserSettings.Section.stroke_settings, 'max_duration', 10.0))
	$Menu.set_stroke_duration_display_mode(UserSettings.get_value(UserSettings.Section.stroke_settings, 'display_mode', 0))
	
	$LoopControls/In/AccelerationControls/Transition.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 1))
	$LoopControls/In/AccelerationControls/Easing.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2))
	$LoopControls/Out/AccelerationControls/Transition.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'out_trans', 1))
	$LoopControls/Out/AccelerationControls/Easing.select(UserSettings.get_value(UserSettings.Section.stroke_settings, 'out_ease', 2))
	$LoopControls.draw_easing()
	
	$Menu.select_mode(UserSettings.get_value(UserSettings.Section.app_settings, 'mode', 1))


func apply_device_settings():
	$Settings.set_max_speed(UserSettings.get_value(UserSettings.Section.speed_slider, 'max_speed', 25000))
	$Settings.set_max_acceleration(UserSettings.get_value(UserSettings.Section.accel_slider, 'max_acceleration', 500000))
	$SpeedPanel.set_speed_slider_percent(UserSettings.get_value(UserSettings.Section.speed_slider, 'position_percent', 0.6))
	$SpeedPanel.set_acceleration_slider_percent(UserSettings.get_value(UserSettings.Section.accel_slider, 'position_percent', 0.4))
	$RangePanel.set_min_slider_percent(UserSettings.get_value(UserSettings.Section.range_slider_min, 'position_percent', 0))
	$RangePanel.set_max_slider_percent(UserSettings.get_value(UserSettings.Section.range_slider_max, 'position_percent', 1))
	$Settings.set_syncing_speed(UserSettings.get_value(UserSettings.Section.device_settings, 'syncing_speed', 1000))
	$Settings.set_homing_trigger(UserSettings.get_value(UserSettings.Section.device_settings, 'homing_trigger', 1.5))


func round_to(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor


func load_path(filePath:String) -> bool:
	var funscript = Funscript.new(filePath, ticks_per_second, PATH_TOP, PATH_BOTTOM)
	if not funscript._marker_data:
		printerr("Error: Failed to read file.")
		return false
	if funscript._marker_data.size() < 6:
		printerr("Error: Insufficient path data in file.")
		return false

	funscripts.append(funscript)
	create_path_lines(funscript._marker_data)

	return true


func create_path_lines(marker_data: Dictionary):
	var previous_depth:float
	var previous_frame:int
	var marker_list:Array = marker_data.keys()
	var path_line:Line2D = Line2D.new()
	path_line.width = 15
	path_line.hide()
	marker_list.sort()
	for marker_frame in marker_list:
		var depth = marker_data[marker_frame][0]
		var trans = marker_data[marker_frame][1]
		@warning_ignore("shadowed_global_identifier")
		var ease = marker_data[marker_frame][2]
		@warning_ignore("unused_variable")
		var auxiliary = marker_data[marker_frame][3]
		if marker_frame > 0:
			var steps:int = marker_frame - previous_frame
			for step in steps:
				var step_depth:float = Tween.interpolate_value(
						previous_depth,
						depth - previous_depth,
						step,
						steps,
						trans,
						ease)
				var x_pos = (previous_frame * path_speed) + (step * path_speed)
				var y_pos = render_depth(step_depth)
				path_line.add_point(Vector2(x_pos, y_pos))
		previous_depth = depth
		previous_frame = marker_frame
	
	$PathDisplay/Paths.add_child(path_line)


func create_delay(duration:float):
	var current_funscript = funscripts[Global.active_path_index]
	var delay_path:PackedFloat32Array
	var path_line:Line2D = Line2D.new()
	path_line.hide()
	var headers:String = "M%sD%sT%sE%s"
	var message:String = headers%[0, duration * 1000, 0, 2]
	for point in round(duration * ticks_per_second):
		delay_path.append(-1)
	var marker_path:Dictionary
	var network_packets:Array
	for timing in 6:
		var move_command = OSSMCommand.create_move_command(timing, 0, 0, 0, 0)
		network_packets.append(move_command)
		marker_path[timing] = message
	var end_move = OSSMCommand.create_move_command(duration * 1000, 0, 0, 0, 0)
	network_packets.append(end_move)
	current_funscript.network_paths.append(network_packets)
	current_funscript.paths.append(delay_path)
	current_funscript.markers.append(marker_path)
	$PathDisplay/Paths.add_child(path_line)
	$Menu/Playlist.add_item("delay(%s)" % [duration])


@warning_ignore("shadowed_variable")
func display_active_path_index(pause := true, send_buffer := true):
	if pause:
		MPV.restart()
	Global.paused = pause
	Global.frame = 0
	marker_index = 0
	if send_buffer:
		if %WebSocket.ossm_connected:
			%OSSMCommand.reset()
			while marker_index < 6:
				%WebSocket.server.broadcast_binary(funscripts[Global.active_path_index].network_paths[marker_index])
				marker_index += 1
	else:
		marker_index = 6
	
	$ActionPanel.clear_selections()
	if pause:
		$ActionPanel/Pause.hide() 
		$ActionPanel/Play.show()
	for path in $PathDisplay/Paths.get_children():
		path.hide()
	var path = $PathDisplay/Paths.get_child(Global.active_path_index)
	path.position.x = ($PathDisplay/PathArea.size.x / 2) + path_speed
	path.show()
	$PathDisplay/Ball.position.y = render_depth(funscripts[Global.active_path_index].paths[0])
	$PathDisplay/Ball.show()
	$PathDisplay.show()


func render_depth(depth) -> float:
	return PATH_BOTTOM + depth * (PATH_TOP - PATH_BOTTOM)


func activate_move_mode():
	set_physics_process(true)
	%ActionPanel/Play.show()
	%ActionPanel/Pause.hide()
	%PathDisplay/PathArea.show()
	%PathDisplay/Paths.show()
	%PathDisplay/TimeLabel.show()
	%PathDisplay/Ball.show()
	%Menu/Main/PlaylistButtons.show()
	%Menu/Main/PathButtons.show()
	%Menu/Main/MoreButtons.show()
	%Menu/PathControls.show()
	%Menu/Playlist.show()
	if Global.active_path_index != null:
		display_active_path_index()
	%Menu.refresh_selection()


func deactivate_move_mode():
	%ActionPanel/Play.hide()
	%ActionPanel/Pause.show()
	%PathDisplay/Paths.hide()
	%PathDisplay/PathArea.hide()
	%PathDisplay/TimeLabel.hide()
	%PathDisplay/Ball.hide()
	%Menu/Main/PlaylistButtons.hide()
	%Menu/Main/PathButtons.hide()
	%Menu/Main/MoreButtons.hide()
	%Menu/PathControls.hide()
	%Menu/Playlist.hide()


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
	if %WebSocket.ossm_connected:
		pause()
		%OSSMCommand.set_range_limit_min(0)
		home_to(0)
