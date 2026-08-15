class_name VideoPlayerVlc

extends VideoPlayerBase

var _sync_connected: Callable
var _on_state_change: Callable

var _command_http: HTTPRequest
var _poll_http: HTTPRequest
var _poll_timer: Timer

var _poll_in_flight: bool = false

var _seek_after_pause: float = -1.0
var _vlc_password: String = ""
var _vlc_state: Dictionary = {}


var _base_url: String:
	get:
		return "http://" + player_address + ":" + str(player_port)

var _vlc_headers: PackedStringArray:
	get:
		return PackedStringArray([
			"Authorization: Basic " + Marshalls.utf8_to_base64(":" + _vlc_password)
		])

@warning_ignore("shadowed_variable_base_class")
func _init(
		player_address,
		player_port,
		vlc_password,
		sync_connected: Callable,
		on_state_change: Callable
	):
	self.player_address = player_address
	self.player_port = player_port
	self._vlc_password = vlc_password
	_sync_connected = sync_connected
	_on_state_change = on_state_change

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
	_vlc_state = {}
	_poll_timer.start()


func deactivate():
	_vlc_state = {}
	_poll_in_flight = false
	_poll_timer.stop()
	_poll_http.cancel_request()
	_command_http.cancel_request()


func send_play():
	_command_http.cancel_request()
	_command_http.request(
		_base_url + "/requests/status.json?command=pl_forceresume",
		_vlc_headers)


func send_pause(time_seconds := -1.0):
	_seek_after_pause = time_seconds
	_command_http.cancel_request()
	_command_http.request(
		_base_url + "/requests/status.json?command=pl_forcepause",
		_vlc_headers)


func send_seek(time_seconds: float):
	_command_http.cancel_request()
	var pct = "0"
	var player_duration = float(_vlc_state.get("position", 0))
	if player_duration > 0.0:
		pct = "%f" % (time_seconds / player_duration * 100.0)
	_command_http.request(
		_base_url + "/requests/status.json?command=seek&val=" \
		+ pct + "%25",
		_vlc_headers)


func _poll_status():
	if _poll_in_flight:
		return

	_poll_in_flight = true
	_poll_http.request(_base_url + "/requests/status.json", _vlc_headers)


func _on_poll_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_sync_connected.call(false)
		return
	else:
		_sync_connected.call(true)

	_poll_in_flight = false
	parse_vlc(body)


func _on_command_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_seek_after_pause = -1.0
		return

	parse_vlc(body)
	
	if _seek_after_pause >= 0.0:
		var time = _seek_after_pause
		_seek_after_pause = -1.0
		await get_tree().create_timer(0.1).timeout
		send_seek(time)


# ---- Response Parsing ----

func parse_vlc(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary:
		return
	_vlc_state = json

	var length = float(json.get("length", 0))
	var position = float(json.get("position", 0))
	
	_on_state_change.call({
		"state": json.get("state", "stopped"),
		"time": position * length,
		"duration": length
	})
