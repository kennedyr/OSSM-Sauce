class_name VideoPlayerVlc

extends VideoPlayerBase

var on_state_change: Callable

var _poll_http: HTTPRequest
var _command_http: HTTPRequest

var _poll_in_flight: bool = false

var vlc_password: String = ""

var _base_url: String:
	get:
		return "http://" + player_address + ":" + str(player_port)

var _vlc_headers: PackedStringArray:
	get:
		return PackedStringArray([
			"Authorization: Basic " + Marshalls.utf8_to_base64(":" + vlc_password)
		])

func _init(
		player_address,
		player_port,
		vlc_password,
		_poll_http: HTTPRequest,
		_command_http: HTTPRequest,
		on_state_change: Callable
	):
	self.player_address = player_address
	self.player_port = player_port
	self.vlc_password = vlc_password
	self._poll_http = _poll_http
	self._command_http = _command_http
	self.on_state_change = on_state_change


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
	_command_http.request(
		_base_url + "/requests/status.json?command=pl_forceresume",
		_vlc_headers)


func send_pause():
	_command_http.cancel_request()
	_command_http.request(
		_base_url + "/requests/status.json?command=pl_forcepause",
		_vlc_headers)

func send_seek(time_seconds: float, player_duration: float):
	_command_http.cancel_request()
	var pct = "0"
	if player_duration > 0.0:
		pct = "%f" % (time_seconds / player_duration * 100.0)
	_command_http.request(
		_base_url + "/requests/status.json?command=seek&val=" \
		+ pct + "%25",
		_vlc_headers)


func process(delta):
	pass


func poll_status():
	_poll_http.request(_base_url + "/requests/status.json", _vlc_headers)


func on_poll_completed(body: PackedByteArray):
	_poll_in_flight = false
	parse_vlc(body)


func on_command_completed(body: PackedByteArray):
	parse_vlc(body)


# ---- Response Parsing ----

func parse_vlc(body: PackedByteArray):
	var json = JSON.parse_string(body.get_string_from_utf8())
	if not json is Dictionary:
		return
	var length = float(json.get("length", 0))
	var _position = float(json.get("position", 0))

	on_state_change.call(json.get("state", "stopped"), _position * length, length)
