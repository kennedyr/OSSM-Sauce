class_name VideoPlayerMpvAndroid

extends VideoPlayerBase

var saf_mpv_bridge_uri: String
var on_connected: Callable
var on_disconnected: Callable
var on_state_change: Callable

const _MPV_ANDROID_HEARTBEAT_TIMEOUT := 3.0 # seconds without heartbeat change
const _MPV_ANDROID_STATE_FILE := "ossm_bridge/state.json"
const _MPV_ANDROID_BRIDGE_SUBDIR := "ossm_bridge"
const _MPV_ANDROID_COMMAND_SUBDIR := "ossm_bridge/command_queue"
const _MPV_ANDROID_SCRIPTS_SUBDIR := "scripts"
const _MPV_ANDROID_LUA_FILE := "scripts/ossm_android_bridge.lua"
const _MPV_ANDROID_LUA_SOURCE := "res://bridges/ossm_android_bridge.lua"
# Hardcoded — mpv-android can only load scripts from its own /Android/media/
# package dir under scoped storage, so this path is fixed by platform.
const _MPV_ANDROID_SCRIPT_LINE := \
	"script=/sdcard/Android/media/is.xyz.mpv/scripts/ossm_android_bridge.lua"
const _MPV_ANDROID_EXPECTED_DOC_ID := "primary:Android/media/is.xyz.mpv"

var _mpv_android_state: Dictionary = {}
var _mpv_android_received_filename: bool = false
var _mpv_android_last_heartbeat: int = 0
var _mpv_android_last_heartbeat_seen_at: float = 0.0
var _mpv_android_command_counter: int = 0


func _init(
		saf_mpv_bridge_uri: String,
		on_connected: Callable,
		on_disconnected: Callable,
		on_state_change: Callable
	):
	self.player_address = ""
	self.player_port = 0
	self.saf_mpv_bridge_uri = saf_mpv_bridge_uri
	self.on_connected = on_connected
	self.on_disconnected = on_disconnected
	self.on_state_change = on_state_change


func activate(poll_timer: Timer):
	_mpv_android_activate()
	poll_timer.wait_time = 0.1
	poll_timer.start()


func deactivate(poll_timer: Timer):
	poll_timer.stop()
	_mpv_android_disconnect()


func send_play():
	_mpv_android_send_command(["set_property", "pause", false])


func send_pause():
	_mpv_android_send_command(["set_property", "pause", true])


func send_seek(time_seconds: float, _player_duration: float):
	_mpv_android_send_command(["seek", time_seconds, "absolute"])


func process(delta):
	pass

func poll_status():
	_mpv_android_poll()

func on_poll_completed(_body: PackedByteArray):
	pass

func on_command_completed(_body: PackedByteArray):
	pass


# ---- MPV Android File IPC (SAF) ----

func _mpv_android_saf_path(rel: String) -> String:
	# Builds a Godot SAF FileAccess path from the picked bridge tree URI.
	var uri := saf_mpv_bridge_uri
	if uri.is_empty():
		return ""
	return uri + "#" + rel


func _mpv_android_activate():
	_mpv_android_state = {}
	_mpv_android_received_filename = false
	_mpv_android_last_heartbeat = 0
	_mpv_android_last_heartbeat_seen_at = 0.0
	_mpv_android_command_counter = 0
	_mpv_android_ensure_subdir(_MPV_ANDROID_BRIDGE_SUBDIR)
	_mpv_android_ensure_subdir(_MPV_ANDROID_COMMAND_SUBDIR)
	_mpv_android_clear_command_queue()


func _mpv_android_disconnect():
	_mpv_android_state = {}
	_mpv_android_received_filename = false
	_mpv_android_last_heartbeat = 0
	_mpv_android_last_heartbeat_seen_at = 0.0


func _mpv_android_clear_command_queue():
	# Stale commands from a previous session would otherwise be eaten by
	# the bridge as soon as it sees them, with no relation to current intent.
	var uri := saf_mpv_bridge_uri
	if uri.is_empty():
		return
	var DocumentsContract = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var ActivityThread = JavaClassWrapper.wrap("android.app.ActivityThread")
	if DocumentsContract == null or Uri == null or ActivityThread == null:
		return
	var tree_uri_obj = Uri.parse(uri)
	if tree_uri_obj == null:
		return
	var tree_doc_id = DocumentsContract.getTreeDocumentId(tree_uri_obj)
	var cmd_doc_id := str(tree_doc_id) + "/" + _MPV_ANDROID_COMMAND_SUBDIR
	var children_uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree_uri_obj, cmd_doc_id)
	if children_uri == null:
		return
	var resolver = ActivityThread.currentActivityThread().getApplication().getContentResolver()
	var projection := PackedStringArray(["document_id", "_display_name"])
	var cursor = resolver.query(children_uri, projection, "", PackedStringArray(), "", null)
	if cursor == null:
		return
	var doc_id_col = cursor.getColumnIndex("document_id")
	var name_col = cursor.getColumnIndex("_display_name")
	while cursor.moveToNext():
		var name_val: String = cursor.getString(name_col)
		if name_val.begins_with("cmd_"):
			var doc_id = cursor.getString(doc_id_col)
			var doc_uri = DocumentsContract.buildDocumentUriUsingTree(tree_uri_obj, doc_id)
			DocumentsContract.deleteDocument(resolver, doc_uri)
	cursor.close()


func _mpv_android_ensure_subdir(rel_path: String) -> bool:
	# Walks rel_path and creates each missing component as a directory.
	var uri := saf_mpv_bridge_uri
	if uri.is_empty():
		return false
	var DocumentsContract = JavaClassWrapper.wrap("android.provider.DocumentsContract")
	var Uri = JavaClassWrapper.wrap("android.net.Uri")
	var ActivityThread = JavaClassWrapper.wrap("android.app.ActivityThread")
	if DocumentsContract == null or Uri == null or ActivityThread == null:
		return false
	var tree_uri_obj = Uri.parse(uri)
	if tree_uri_obj == null:
		return false
	var tree_doc_id = DocumentsContract.getTreeDocumentId(tree_uri_obj)
	var resolver = ActivityThread.currentActivityThread().getApplication().getContentResolver()
	var current_doc_id := str(tree_doc_id)
	for part in rel_path.split("/", false):
		var children_uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree_uri_obj, current_doc_id)
		var found := false
		var cursor = resolver.query(children_uri, PackedStringArray(["_display_name"]), "", PackedStringArray(), "", null)
		if cursor != null:
			var name_col = cursor.getColumnIndex("_display_name")
			while cursor.moveToNext():
				if cursor.getString(name_col) == part:
					found = true
					break
			cursor.close()
		if not found:
			var parent_uri = DocumentsContract.buildDocumentUriUsingTree(tree_uri_obj, current_doc_id)
			var created = DocumentsContract.createDocument(resolver, parent_uri, "vnd.android.document/directory", part)
			if created == null:
				push_warning("MPV_ANDROID: createDocument failed at " + part)
				return false
		current_doc_id = current_doc_id + "/" + part
	return true


func _mpv_android_poll():
	var state_path := _mpv_android_saf_path(_MPV_ANDROID_STATE_FILE)
	if state_path.is_empty():
		_mpv_android_set_disconnected()
		return
	
	var f := FileAccess.open(state_path, FileAccess.READ)
	if f == null:
		_mpv_android_set_disconnected()
		return
	var body := f.get_as_text()
	f.close()
	
	var json = JSON.parse_string(body)
	if not json is Dictionary:
		return # Partial write race — retry next poll.
	
	var heartbeat := int(json.get("heartbeat", 0))
	var now := Time.get_ticks_msec() / 1000.0
	
	# Bootstrap: first poll just records the heartbeat without marking alive.
	# Liveness = heartbeat changed within HEARTBEAT_TIMEOUT seconds.
	if _mpv_android_last_heartbeat_seen_at == 0.0:
		_mpv_android_last_heartbeat = heartbeat
		_mpv_android_last_heartbeat_seen_at = now
		return
	
	if heartbeat != _mpv_android_last_heartbeat:
		_mpv_android_last_heartbeat = heartbeat
		_mpv_android_last_heartbeat_seen_at = now
	
	var alive := (now - _mpv_android_last_heartbeat_seen_at) < _MPV_ANDROID_HEARTBEAT_TIMEOUT
	
	if alive:
		on_connected.call()
	else:
		_mpv_android_set_disconnected()
		return
		
	_mpv_android_state = json
	if json.get("filename") != null:
		_mpv_android_received_filename = true
	_mpv_android_update_state()


func _mpv_android_set_disconnected():
	on_disconnected.call()
	_mpv_android_received_filename = false


func _mpv_android_update_state():
	# Mirrors _mpv_update_state — wait for filename to land before deriving,
	# so phantom signals don't fire from a partial state snapshot.
	if not _mpv_android_received_filename:
		return
	var filename = _mpv_android_state.get("filename")
	var pause_val = _mpv_android_state.get("pause")
	var time_pos = _mpv_android_state.get("time-pos")
	var duration = _mpv_android_state.get("duration")
	
	var state: String
	if filename == null:
		state = "stopped"
	elif pause_val == true:
		state = "paused"
	else:
		state = "playing"
	
	var time_sec := 0.0
	var duration_sec := 0.0
	if filename != null:
		if time_pos != null:
			time_sec = float(time_pos)
		if duration != null:
			duration_sec = float(duration)
	on_state_change.call(state, time_sec, duration)


func _mpv_android_send_command(arr: Array):
	_mpv_android_command_counter += 1
	var seq := _mpv_android_command_counter
	var rel := _MPV_ANDROID_COMMAND_SUBDIR + "/cmd_%010d.json" % seq
	var path := _mpv_android_saf_path(rel)
	if path.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("MPV_ANDROID: cannot open command file " + path)
		return
	f.store_string(JSON.stringify({"command": arr}))
	f.close()
