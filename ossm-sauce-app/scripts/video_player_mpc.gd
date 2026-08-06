class_name VideoPlayerMpc

extends VideoPlayerBase

var _sync_connected: Callable
var _on_state_change: Callable

var _command_http: HTTPRequest
var _poll_http: HTTPRequest

var _poll_timer: Timer
var _poll_in_flight: bool = false

var _seek_after_pause: float = -1.0
var _mpc_state_regex: RegEx
var _mpc_pos_regex: RegEx
var _mpc_dur_regex: RegEx

var _base_url: String:
	get:
		return "http://" + player_address + ":" + str(player_port)

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

	_mpc_state_regex = RegEx.new()
	_mpc_state_regex.compile('<p id="state">(\\d+)</p>')
	_mpc_pos_regex = RegEx.new()
	_mpc_pos_regex.compile('<p id="position">(\\d+)</p>')
	_mpc_dur_regex = RegEx.new()
	_mpc_dur_regex.compile('<p id="duration">(\\d+)</p>')


func _ready():
	_command_http = HTTPRequest.new()
	_command_http.name = "CommandHTTP"
	_command_http.timeout = 2
	add_child(_command_http)
	_command_http.request_completed.connect(_on_command_completed)
	
	_poll_http = HTTPRequest.new()
	_poll_http.name = "PollHTTP"
	_poll_http.timeout = 2
	add_child(_poll_http)
	_poll_http.request_completed.connect(_on_poll_completed)
	
	_poll_timer = Timer.new()
	_poll_timer.name = "PollTimer"
	# Slower poll on Android: VLC/MPC HTTP polling keeps the WiFi
	# radio busy continuously, draining battery. 500ms is well within
	# what the offset inputs can absorb. Desktop stays at 100ms.
	_poll_timer.wait_time = 0.5 if OS.get_name() == "Android" else 0.1
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll_status)


func activate():
	_poll_timer.start()


func deactivate():
	_poll_in_flight = false
	_poll_timer.stop()
	_poll_http.cancel_request()
	_command_http.cancel_request()


func send_play():
	_command_http.cancel_request()
	_command_http.request(_base_url + "/command.html?wm_command=887")


func send_pause(time_seconds := -1.0):
	_seek_after_pause = time_seconds
	_command_http.cancel_request()
	_command_http.request(_base_url + "/command.html?wm_command=888")


func send_seek(time_seconds: float):
	_command_http.cancel_request()
	var total_ms = int(time_seconds * 1000)
	var h = int(total_ms / 3600000.0)
	var m = int((total_ms % 3600000) / 60000.0)
	var s = int((total_ms % 60000) / 1000.0)
	var ms = total_ms % 1000
	_command_http.request(
		_base_url + "/command.html?wm_command=-1&position=" \
		+"%02d:%02d:%02d.%03d" % [h, m, s, ms])


func _poll_status():
	if _poll_in_flight:
		return

	_poll_in_flight = true
	_poll_http.request(_base_url + "/variables.html")


func _on_poll_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_sync_connected.call(false)
		return
	else:
		_sync_connected.call(true)

	_poll_in_flight = false
	_parse_mpc(body)


func _on_command_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_seek_after_pause = -1.0
		return

	if _seek_after_pause >= 0.0:
		var time = _seek_after_pause
		_seek_after_pause = -1.0
		await get_tree().create_timer(0.1).timeout
		send_seek(time)


# ---- Response Parsing ----

func _parse_mpc(body: PackedByteArray):
	var html = body.get_string_from_utf8()
	var state_match = _mpc_state_regex.search(html)
	if not state_match:
		return
	var state_code = int(state_match.get_string(1))
	var state: String
	match state_code:
		0: state = "stopped"
		1: state = "paused"
		2: state = "playing"
		_: state = "stopped"
	var time_sec := 0.0
	var duration_sec := 0.0
	var pos_match = _mpc_pos_regex.search(html)
	if pos_match:
		time_sec = float(pos_match.get_string(1)) / 1000.0
	var dur_match = _mpc_dur_regex.search(html)
	if dur_match:
		duration_sec = float(dur_match.get_string(1)) / 1000.0
	_on_state_change.call({
		"state": state,
		"time": time_sec,
		"duration": duration_sec
	})
