class_name VideoPlayerMpc

extends VideoPlayerBase

var on_state_change: Callable

var _poll_http: HTTPRequest
var _command_http: HTTPRequest

var _poll_in_flight: bool = false

var _mpc_state_regex: RegEx
var _mpc_pos_regex: RegEx
var _mpc_dur_regex: RegEx

var _base_url: String:
	get:
		return "http://" + player_address + ":" + str(player_port)

func _init(
		player_address,
		player_port,
		_poll_http: HTTPRequest,
		_command_http: HTTPRequest,
		on_state_change: Callable
	):
	self.player_address = player_address
	self.player_port = player_port
	self._poll_http = _poll_http
	self._command_http = _command_http
	self.on_state_change = on_state_change

	_mpc_state_regex = RegEx.new()
	_mpc_state_regex.compile('<p id="state">(\\d+)</p>')
	_mpc_pos_regex = RegEx.new()
	_mpc_pos_regex.compile('<p id="position">(\\d+)</p>')
	_mpc_dur_regex = RegEx.new()
	_mpc_dur_regex.compile('<p id="duration">(\\d+)</p>')


func activate(poll_timer: Timer):
	# Slower poll on Android: VLC/MPC HTTP polling keeps the WiFi
	# radio busy continuously, draining battery. 500ms is well within
	# what the offset inputs can absorb. Desktop stays at 100ms.
	poll_timer.wait_time = 0.5 if OS.get_name() == "Android" else 0.1
	poll_timer.start()


func deactivate(poll_timer: Timer):
	_poll_in_flight = false
	poll_timer.stop()
	_poll_http.cancel_request()
	_command_http.cancel_request()


func send_play():
	_command_http.cancel_request()
	_command_http.request(_base_url + "/command.html?wm_command=887")


func send_pause():
	_command_http.cancel_request()
	_command_http.request(_base_url + "/command.html?wm_command=888")


func send_seek(time_seconds: float, _player_duration: float):
	_command_http.cancel_request()
	var total_ms = int(time_seconds * 1000)
	var h = int(total_ms / 3600000.0)
	var m = int((total_ms % 3600000) / 60000.0)
	var s = int((total_ms % 60000) / 1000.0)
	var ms = total_ms % 1000
	_command_http.request(
		_base_url + "/command.html?wm_command=-1&position=" \
		+"%02d:%02d:%02d.%03d" % [h, m, s, ms])


func process(delta):
	pass


func poll_status():
	if _poll_in_flight:
		return

	_poll_in_flight = true	
	_poll_http.request(_base_url + "/variables.html")


func on_poll_completed(body: PackedByteArray):
	_poll_in_flight = false
	_parse_mpc(body)


func on_command_completed(_body: PackedByteArray):
	pass


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
	on_state_change.call(state, time_sec, duration_sec)
