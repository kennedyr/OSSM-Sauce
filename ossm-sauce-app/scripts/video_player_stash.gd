class_name VideoPlayerStash

extends VideoPlayerBase

var _sync_connected: Callable
var _on_state_change: Callable

var _poll_timer: Timer

var _ws_server: WebSocketServer
var _stash_state := {
	"state": "stopped",
	"time": 0.0,
	"duration": 0.0
}

var _client_id
var _latency
var _last_heartbeat := 0.0
var _last_heartbeat_seen_at := 0.0

var _is_ready: bool:
	get:
		return _ws_server and _ws_server.is_listening() and _client_id

@warning_ignore("shadowed_variable_base_class")
func _init(
		player_port,
		sync_connected: Callable,
		on_state_change: Callable
	):
	self.player_port = player_port
	_sync_connected = sync_connected
	_on_state_change = on_state_change

	_ws_server = WebSocketServer.new()
	_ws_server.client_connected.connect(_on_client_connected)
	_ws_server.client_disconnected.connect(_on_client_disconnected)
	_ws_server.message_received.connect(_on_message_received)
	_ws_server.server_error.connect(_on_server_error)


func _ready():
	_poll_timer = Timer.new()
	_poll_timer.name = "PollTimer"
	_poll_timer.wait_time = 3.0
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_poll_status)


func activate():
	print_verbose("[Stash] Starting Stash WebSocket server on port %d" % int(player_port))
	var ok = _ws_server.start(player_port)
	if ok:
		print_verbose("[Stash] WebSocket server started on port %d" % int(player_port))
	else:
		push_error("[Stash] Failed to start WebSocket server on port %d" % int(player_port))

	_poll_timer.start()
	_stash_state = {}


func deactivate():
	print_verbose("[Stash] Stopping Stash WebSocket server")
	if _ws_server:
		_ws_server.stop()
		# _ws_server = null
		print_verbose("[Stash] WebSocket server stopped")
	else:
		print_verbose("[Stash] No WebSocket server to stop")
	_poll_timer.stop()
	_stash_state = {}


func send_play():
	if _is_ready:
		print_verbose("[Stash] send_play")
		_ws_server.send_text(_client_id, JSON.stringify({
			"command": "play",
			"properties": {
				"currentTime": _stash_state.get('time')
			}
		}))


func send_pause(time_seconds := -1.0):
	if _is_ready:
		print_verbose("[Stash] send_pause")
		_ws_server.send_text(_client_id, JSON.stringify({
			"command": "pause",
			"properties": {
				"currentTime": time_seconds
			}
		}))
	# if time_seconds >= 0.0:
	# 	send_seek(time_seconds)


func send_seek(time_seconds: float):
	if _is_ready:
		print_verbose("[Stash] send_seek")
		_ws_server.send_text(_client_id, JSON.stringify({
			"command": "seek",
			"properties": {
				"currentTime": time_seconds
			}
		}))


func send_loop(looping: bool):
	if _is_ready:
		print_verbose("[Stash] send_loop")
		_ws_server.send_text(_client_id, JSON.stringify({
			"command": "loop",
			"properties": {
				"looping": looping
			}
		}))


func _process(_delta):
	if _ws_server and _ws_server.is_listening():
		_ws_server.process()


func _poll_status():
	if _is_ready:
		var now = Time.get_unix_time_from_system()
		_ws_server.broadcast_ping()
		if now - _last_heartbeat_seen_at > 3:
			_ws_server.send_text(_client_id, JSON.stringify({
				"type": 'ping',
				"timestamp": int(now),
				"serverTime": int(now)
			}))
			_last_heartbeat = now;
		return


# ---- Websocket ----

func _on_client_connected(client_id):
	print_verbose("[Stash] client connected: %d" % client_id)
	_sync_connected.call(true)
	if _client_id and _client_id != client_id:
		push_warning("New client connected %s replacing %s" % [client_id, _client_id])
	_client_id = client_id


func _on_client_disconnected(client_id, code):
	print_verbose("[Stash] client disconnected: %d (code: %d)" % [client_id, code])
	_sync_connected.call(false)
	# reconnect?


func _on_message_received(client_id, message):
	var payload: Dictionary = JSON.parse_string(message)
	
	if not payload:
		push_warning("[Stash] ERROR: Invalid payload!")
		return
	
	if payload.has('type'):
		# Handle heartbeat response
		if payload.type == 'pong':
			if payload.has('timestamp'):
				# Calculate round-trip latency
				var now = Time.get_unix_time_from_system()
				_last_heartbeat_seen_at = now
				_latency = now - payload.timestamp
				print("[Stash] Client %s latency: %dms" % [client_id, _latency])

			return

		# Handle client-initiated ping (bidirectional heartbeat)
		if payload.type == 'ping':
			var now = Time.get_unix_time_from_system()
			var timestamp = payload.timestamp if payload.has('timestamp') else now
			_last_heartbeat_seen_at = now
			_ws_server.send_text(client_id, JSON.stringify({
				"type": 'pong',
				"timestamp": int(payload.timestamp),
				"serverTime": int(now)
			}))
			return

	print_verbose("[Stash] %s JSON payload:" % str(client_id))
	print_verbose(JSON.stringify(payload, "\t"))
	print_verbose("")
	if payload.has('event'):
		var properties = payload.get("properties", {})
		match payload.event:
			"open":
				_stash_update_state({
					"filename": properties.get("funscriptUrl"),
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			"play":
				_stash_update_state({
					"state": "playing",
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			"pause":
				_stash_update_state({
					"state": "paused",
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			"seek":
				_stash_update_state({
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			"loop":
				_stash_update_state({
					"loop": payload["properties"]["looping"],
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			"end":
				_stash_update_state({
					"state": "stopped",
					"time": properties.get("currentTime"),
					"duration": properties.get("duration")
				})
				return
			_:
				pass
	push_warning("[Stash] unhandled message: %s" % payload)
	

func _on_server_error(error):
	push_error("[Stash] Server error: %s" % error)


func _stash_update_state(state: Dictionary):
	_stash_state.merge(state, true)
	if not _stash_state.get("filename"):
		return
	
	_on_state_change.call(state)
