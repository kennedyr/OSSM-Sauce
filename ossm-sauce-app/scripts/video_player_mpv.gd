class_name VideoPlayerMpv

extends VideoPlayerBase

var _sync_connected: Callable
var _on_state_change: Callable

var _mpv_tcp: StreamPeerTCP = null
var _mpv_buffer: String = ""
var _mpv_pause: bool = true
var _mpv_filename = null
var _mpv_time_pos = null
var _mpv_duration = null
var _mpv_received_filename: bool = false
var _mpv_reconnect_accum: float = 0.0


@warning_ignore("shadowed_variable_base_class")
func _init(
		player_address,
		player_port,
		sync_connected: Callable,
		on_state_change: Callable
	):
	self.player_address = player_address
	self.player_port = player_port
	_sync_connected = sync_connected
	_on_state_change = on_state_change


func activate():
	_mpv_connect()


func deactivate():
	_mpv_disconnect()


func send_play():
	_mpv_send_command(["set_property", "pause", false])


func send_pause(time_seconds := -1.0):
	_mpv_send_command(["set_property", "pause", true])
	if time_seconds >= 0.0:
		send_seek(time_seconds)


func send_seek(time_seconds: float):
	_mpv_send_command(["seek", time_seconds, "absolute"])


func _process(delta):
	if _mpv_tcp == null:
		_mpv_reconnect_accum += delta
		if _mpv_reconnect_accum >= 1.0:
			_mpv_reconnect_accum = 0.0
			_mpv_connect()
		return
	_mpv_reconnect_accum = 0.0
	_mpv_tcp.poll()
	match _mpv_tcp.get_status():
		StreamPeerTCP.STATUS_CONNECTED:
			_sync_connected.call(true)
			var avail := _mpv_tcp.get_available_bytes()
			if avail > 0:
				var result = _mpv_tcp.get_data(avail)
				if result[0] == OK:
					_mpv_buffer += (result[1] as PackedByteArray).get_string_from_utf8()
					_mpv_drain_buffer()
		StreamPeerTCP.STATUS_ERROR, StreamPeerTCP.STATUS_NONE:
			_sync_connected.call(false)
			_mpv_disconnect()


# ---- MPV TCP ----

func _mpv_connect():
	_mpv_tcp = StreamPeerTCP.new()
	var err := _mpv_tcp.connect_to_host(player_address, player_port)
	if err != OK:
		push_warning("MPV TCP connect_to_host failed: %d" % err)
		_mpv_tcp = null


func _mpv_disconnect():
	if _mpv_tcp != null:
		_mpv_tcp.disconnect_from_host()
		_mpv_tcp = null
	_mpv_buffer = ""
	_mpv_pause = true
	_mpv_filename = null
	_mpv_time_pos = null
	_mpv_duration = null
	_mpv_received_filename = false


func _mpv_drain_buffer():
	while true:
		var nl_idx := _mpv_buffer.find("\n")
		if nl_idx < 0:
			break
		var line := _mpv_buffer.substr(0, nl_idx)
		_mpv_buffer = _mpv_buffer.substr(nl_idx + 1)
		if line.strip_edges().is_empty():
			continue
		_mpv_handle_line(line)


func _mpv_handle_line(line: String):
	var msg = JSON.parse_string(line)
	if not msg is Dictionary:
		return
	if msg.has("event"):
		_mpv_handle_event(msg)
	# Replies (msg.has("error")) are intentionally ignored — property
	# observers tell us everything we need to know about player state.


func _mpv_handle_event(msg: Dictionary):
	match msg.get("event", ""):
		"property-change":
			var prop_name: String = msg.get("name", "")
			var value = msg.get("data")
			match prop_name:
				"pause":
					if value is bool:
						_mpv_pause = value
				"time-pos":
					_mpv_time_pos = value
				"duration":
					_mpv_duration = value
				"filename":
					_mpv_filename = value
					_mpv_received_filename = true
			_mpv_update_state()
		"end-file":
			_mpv_filename = null
			_mpv_received_filename = true
			_mpv_update_state()


func _mpv_update_state():
	# Wait for filename to arrive before deriving state — during the initial
	# snapshot burst the other properties land first, and acting on them
	# would emit phantom seek/pause signals before we know if a file is loaded.
	if not _mpv_received_filename:
		return
	var state: String
	if _mpv_filename == null:
		state = "stopped"
	elif _mpv_pause:
		state = "paused"
	else:
		state = "playing"
	var time := 0.0
	var duration := 0.0
	if _mpv_filename != null:
		if _mpv_time_pos != null:
			time = float(_mpv_time_pos)
		if _mpv_duration != null:
			duration = float(_mpv_duration)
	_on_state_change.call({
		"state": state,
		"time": time,
		"duration": duration
	})


func _mpv_send_command(arr: Array):
	if _mpv_tcp == null:
		return
	if _mpv_tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	var line := JSON.stringify({"command": arr}) + "\n"
	_mpv_tcp.put_data(line.to_utf8_buffer())
