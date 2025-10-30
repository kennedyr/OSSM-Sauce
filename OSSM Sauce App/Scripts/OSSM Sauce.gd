extends Control

var app_version_number:String = "1.4.4"

var storage_dir:String
var paths_dir:String
var playlists_dir:String
var cfg_path:String

const ANIM_TIME = 0.65

var ticks_per_second:int

var path_speed:int = 30

var paused:bool = true

var active_path_index

var paths:Array
var markers:Array
var network_paths:Array

var frame:int

#var app_active_mode:int

var max_speed:int
var max_acceleration:int

var min_stroke_duration:float
var max_stroke_duration:float

signal homing_complete

@onready var PATH_TOP = $PathDisplay/PathArea.position.y
@onready var PATH_BOTTOM = PATH_TOP + $PathDisplay/PathArea.size.y

@onready var ossm_connection_timeout:Timer = $Settings/Network/ConnectionTimeout

#var buttplug_bridge: Node = null

func _init():
	max_speed = 25000
	max_acceleration = 500000


func _ready():
	#get_tree().get_root().set_transparent_background(true)
	#var p1 = "D:/v2/BloodMoon.mov"
	#var path =  "C:/Users/clbhu/Desktop/Splendid/bxe.mp4"
	#var path1 = "D:/v2/BounceX Vol 2 (Ultra Quality - Uncompressed Audio).mov"
	#var p2 = "C:/Users/clbhu/BounceX/mpv/bxe.mp4"
	#var command = r'mpv --input-ipc-server=\\.\pipe\mpvsocket ' + p1
	#var command2 = 'mpv --input-ipc-server=\\\\.\\pipe\\mpv-pipe bxe.mp4'
	#OS.create_process("cmd", ["/c", command])
	#OS.create_process()
	
	OS.request_permissions()

	var physics_ticks = "physics/common/physics_ticks_per_second"
	ticks_per_second = ProjectSettings.get_setting(physics_ticks)
	set_process(false)
	$PositionControls.set_physics_process(false)
	
	min_stroke_duration = $Menu/LoopSettings/MinStrokeDuration/SpinBox.value
	max_stroke_duration = $Menu/LoopSettings/MaxStrokeDuration/SpinBox.value
	
	max_speed = int($Settings/Sliders/MaxSpeed/TextEdit.text)
	max_acceleration = int($Settings/Sliders/MaxAcceleration/TextEdit.text)
	
	if OS.get_name() == 'Android':
		storage_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
	else:
		storage_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	paths_dir = storage_dir + "/OSSM Sauce/Paths/"
	playlists_dir = storage_dir + "/OSSM Sauce/Playlists/"
	
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
func _physics_process(delta):
	if paused or paths[active_path_index].is_empty():
		return
	
	if frame >= paths[active_path_index].size() - 1:
		if active_path_index < network_paths.size() - 1:
			var overreach_index = marker_index - network_paths[active_path_index].size() + 1
			var next_path = network_paths[active_path_index + 1]
			%WebSocket.server.broadcast_binary(next_path[overreach_index])
			var path_list = $Menu/Playlist/Scroll/VBox
			var next_index = active_path_index + 1
			var next_path_item = path_list.get_child(next_index) 
			active_path_index = next_index
			display_active_path_index(false, false)
			$Menu/Playlist._on_item_selected(next_path_item)
			path_list.get_child(next_index).set_active()
		else:
			if $Menu.loop_playlist:
				var overreach_index = marker_index - network_paths[active_path_index].size() + 1
				var next_path = network_paths[0]
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
				var path_list = $Menu/Playlist/Scroll/VBox
				var next_path_item = path_list.get_child(0) 
				active_path_index = 0
				display_active_path_index(false, false)
				$Menu/Playlist._on_item_selected(next_path_item)
				path_list.get_child(0).set_active()
			else:
				pause()
				$Menu.show_play()
				$Menu
				$CircleSelection.show_restart()
				paused = true
		return
	
	var marker_list = markers[active_path_index]
	var active_path = network_paths[active_path_index]
	var current_marker = marker_index - 6
	var current_marker_frame = int(marker_list.keys()[current_marker])
	if frame == current_marker_frame:
		if %WebSocket.server_started:
			if marker_index < active_path.size():
				%WebSocket.server.broadcast_binary(active_path[marker_index])
			elif active_path_index < network_paths.size() - 1:
				var overreach_index = marker_index - active_path.size()
				var next_path = network_paths[active_path_index + 1]
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
			elif $Menu.loop_playlist:
				var overreach_index = marker_index - active_path.size()
				var next_path = network_paths[0]
				%WebSocket.server.broadcast_binary(next_path[overreach_index])
		if current_marker < marker_list.size() - 1:
			marker_index += 1
	
	var depth:float = paths[active_path_index][frame]
	var ms_timing: int = round((float(frame) / 50) * 1000)
	var minutes: int = floori(ms_timing / 60000.0)
	var seconds: int = floori((ms_timing % 60000) / 1000)
	frame += 1

	$PathDisplay/Paths.get_child(active_path_index).position.x -= path_speed
	$PathDisplay/Ball.position.y = render_depth(depth)
	$PathDisplay/TimeLabel.text = "%02d:%02d" % [minutes, seconds]

#func _process22(delta):
	#%WebSocket.poll()
	#var state = %WebSocket.get_ready_state()
	#if state == WebSocketPeer.STATE_OPEN:
		#if not %WebSocket.ossm_connected:
			#user_settings.set_value(
				#'app_settings',
				#'last_server_connection',
				#$Settings/Network/Address/TextEdit.text)
			#%WebSocket.ossm_connected = true
			#send_command(OSSM.Command.CONNECTION)
			#$Wifi.self_modulate = Color.WHITE
			#$Wifi.show()
		#while %WebSocket.get_available_packet_count():
			#var packet:PackedByteArray = %WebSocket.get_packet()
			#if packet.is_empty():
				#return
			#if packet[0] == OSSM.Command.RESPONSE:
				#match packet[1]:
					#OSSM.Command.CONNECTION:
						#ossm_connected = true
						#ossm_connection_timeout.emit_signal('timeout')
						#ossm_connection_timeout.stop()
						#$Wifi.self_modulate = Color.SEA_GREEN
						#$SpeedPanel.update_speed()
						#$SpeedPanel.update_acceleration()
						#$RangePanel.update_min_range()
						#$RangePanel.update_max_range()
						#$Settings.send_syncing_speed()
						#$Menu.select_mode(%Mode.selected)
					#OSSM.Command.HOMING:
						#$CircleSelection.hide()
						#$CircleSelection.homing_lock = false
						#var display = [
							#$PositionControls,
							#$LoopControls,
							#$PathDisplay,
							#$ActionPanel,
							#$Menu]
						#for node in display:
							#node.modulate.a = 1
						#emit_signal("homing_complete")
						#if %Mode.selected == 0:
							#if active_path_index != null:
								#$CircleSelection.show_play()
						#elif %Mode.selected == 1:
							#play()
	#elif state == WebSocketPeer.STATE_CLOSING:
		#pass # Keep polling to achieve proper close.
	#elif state == WebSocketPeer.STATE_CLOSED:
		#var code = %WebSocket.get_close_code()
		#var reason = %WebSocket.get_close_reason()
		#var text = "Webwebsocket closed with code: %d, reason %s. Clean: %s"
		#print(text % [code, reason, code != -1])
		#%WebSocket.ossm_connected = false
		#set_process(false)
		#$Wifi.hide()


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


func play(play_time_ms = null):
	%OSSMCommand.play(play_time_ms)
	if AppMode.active == AppMode.MOVE and active_path_index != null:
		paused = false
		%MPV.play()
		


func pause():
	if AppMode.active == AppMode.MOVE and active_path_index != null:
		%MPV.pause()
	%OSSMCommand.pause()
	paused = true
	Global.paused = true


func check_root_directory():
	var dir = DirAccess.open(storage_dir)
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


func create_move_command(ms_timing:int, depth:float, trans:int, ease:int, auxiliary:int):
	return %OSSMCommand.create_move_command(ms_timing, Util.safe_map_physical_position(depth), trans, ease, auxiliary)


func round_to(value: float, decimals: int) -> float:
	var factor = pow(10, decimals)
	return round(value * factor) / factor


func load_path(filePath:String) -> bool:
	var file = FileAccess.open(filePath, FileAccess.READ)
	if not file:
		printerr("Error: Failed to read file.")
		return false
	
	var file_data:Dictionary
	
	if filePath.ends_with(".funscript"):
		var file_text = file.get_as_text()
		
		file_text = file_text.replace("\n", "")
		
		var actions_pattern = RegEx.new()
		actions_pattern.compile('"[Aa]ctions":\\s*\\[.*?\\]')
		var actions_regex = actions_pattern.search(file_text)
		if not actions_regex:
			actions_pattern.compile('"[Rr]aw[Aa]ctions":\\s*\\[.*?\\]')
			actions_regex = actions_pattern.search(file_text)
		if actions_regex:
			var actions_text = actions_regex.get_string(0)
			actions_text = actions_text.replace("'", '"')
			actions_text = actions_text.insert(0, "{")
			actions_text = actions_text.insert(actions_text.length(), "}")
			var actions_data = JSON.parse_string(actions_text)
			if actions_data:
				var actions_list = actions_data[actions_data.keys()[0]]
				var trans: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_trans', 0)
				var ease: int = UserSettings.get_value(UserSettings.Section.stroke_settings, 'in_ease', 2)
				file_data[0] = [0, trans, ease, 0]
				for action in actions_list:
					var frame:int = action.at / 16.66666
					var depth = round_to(clamp(action.pos / 100, 0, 1), 4)

					var aux = 0
					file_data[frame] = [depth, trans, ease, aux]
			else:
				print("Failed to parse funscript JSON")
		else:
			print("No actions data found in the funscript")
	else:
		file_data = JSON.parse_string(file.get_line())
		if not file_data:
			printerr("Error: No JSON data found in file.")
			return false
	
	var marker_data:Dictionary = file_data
	if marker_data.size() < 6:
		printerr("Error: Insufficient path data in file.")
		return false
	
	var network_packets:Array
	for marker_frame in marker_data.keys():
		var ms_timing = round((float(marker_frame) / 60) * 1000)
		var depth = marker_data[marker_frame][0]
		var trans = marker_data[marker_frame][1]
		var ease = marker_data[marker_frame][2]
		var auxiliary:int = marker_data[marker_frame][3]
		
		var network_packet = %OSSMCommand.create_move_command(ms_timing, Util.safe_map_physical_position(depth), trans, ease, auxiliary)
		#if auxiliary & 1 << 1:
			#network_packet.resize(13)
			#network_packet.encode_u8(0, OSSM.Command.VIBRATE)
			#network_packet.encode_s32(1, -1)
			#network_packet.encode_u32(5, 10)
			#network_packet.encode_u16(9, round(remap(depth, 0, 1, 0, 10000)))
			#network_packet.encode_u8(11, 5)
			#network_packet.encode_u8(12, 100)
		#else:
		network_packets.append(network_packet)
		
		#adjusting for physics tick rate change from BounceX (60Hz to 50Hz)
		marker_data[round(int(marker_frame) / 1.2)] = marker_data[marker_frame]
		marker_data.erase(marker_frame)
	
	network_paths.append(network_packets)
	
	file.close()
	var previous_depth:float
	var previous_frame:int
	var marker_list:Array = marker_data.keys()
	var path:PackedFloat32Array
	var path_new:Dictionary
	var path_line:Line2D = Line2D.new()
	path_line.width = 15
	path_line.hide()
	marker_list.sort()
	for marker_frame in marker_list:
		var depth = marker_data[marker_frame][0]
		var trans = marker_data[marker_frame][1]
		var ease = marker_data[marker_frame][2]
		var auxiliary = marker_data[marker_frame][3]
		if marker_frame > 0:
			var steps:int = marker_frame - previous_frame
			var duration = (float(steps) / ticks_per_second) * 1000
			var scaled_depth:int = round(clamp(depth, 0, 0.9999) * 10000)
			var headers:String = "M%sD%sT%sE%s"
			var message:String = headers%[scaled_depth, duration, trans, ease]
			path_new[previous_frame] = message
			for step in steps:
				var step_depth:float = Tween.interpolate_value(
						previous_depth,
						depth - previous_depth,
						step,
						steps,
						trans,
						ease)
				path.append(step_depth)
				var x_pos = (previous_frame * path_speed) + (step * path_speed)
				var y_pos = render_depth(step_depth)
				path_line.add_point(Vector2(x_pos, y_pos))
		previous_depth = depth
		previous_frame = marker_frame
	paths.append(path)
	markers.append(path_new)
	$PathDisplay/Paths.add_child(path_line)
	return true


func create_delay(duration:float):
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
		var move_command = create_move_command(timing, 0, 0, 0, 0)
		network_packets.append(move_command)
		marker_path[timing] = message
	var end_move = create_move_command(duration * 1000, 0, 0, 0, 0)
	network_packets.append(end_move)
	network_paths.append(network_packets)
	paths.append(delay_path)
	markers.append(marker_path)
	$PathDisplay/Paths.add_child(path_line)
	$Menu/Playlist.add_item("delay(%s)" % [duration])


func display_active_path_index(pause := true, send_buffer := true):
	if pause:
		%MPV.restart()
	paused = pause
	frame = 0
	marker_index = 0
	if send_buffer:
		if %WebSocket.ossm_connected:
			%OSSMCommand.reset()
			while marker_index < 6:
				%WebSocket.server.broadcast_binary(network_paths[active_path_index][marker_index])
				marker_index += 1
	else:
		marker_index = 6
	
	$ActionPanel.clear_selections()
	if pause:
		$ActionPanel/Pause.hide() 
		$ActionPanel/Play.show()
	for path in $PathDisplay/Paths.get_children():
		path.hide()
	var path = $PathDisplay/Paths.get_child(active_path_index)
	path.position.x = ($PathDisplay/PathArea.size.x / 2) + path_speed
	path.show()
	$PathDisplay/Ball.position.y = render_depth(paths[active_path_index][0])
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
	%Menu/Main/LoopPlaylistButton.show()
	%Menu/PathControls.show()
	%Menu/Playlist.show()
	if active_path_index != null:
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
	%Menu/Main/LoopPlaylistButton.hide()
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
