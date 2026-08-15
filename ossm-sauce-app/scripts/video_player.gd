extends Panel

enum PlayerType {OFF, VLC, MPC, MPV, MPV_ANDROID, STASH}

# Configuration — set these from your UI
var player_type: PlayerType = PlayerType.OFF
var player_address: String = "127.0.0.1"
var player_port: int = 8080
var vlc_password: String = ""
var delay_ms: int = 0
var advance_ms: int = 100
var video_offset_ms: int = 0
var vlc_seek_correction: float = 0.0

# Read-only state
var connected := false:
	get:
		return connected
	set(is_conn):
		if is_conn == connected:
			return

		connected = is_conn
		if not connected:
			player_state["state"] = "stopped"
			player_paused.emit()
		connection_changed.emit(connected)

var player_state := {
	"state": "stopped",
	"time": 0.0,
	"duration": 0.0
}

# Signals for bidirectional sync
signal player_played(video_time_seconds: float, from_stopped: bool)
signal player_paused
signal player_seeked(video_time_seconds: float)
signal connection_changed(is_conn: bool)

var _cooldown: bool = false
var _pending_action: String = ""

var _delay_timer: Timer
var _cooldown_timer: Timer
var _load_file_http: HTTPRequest

var _mpv_android_pending_player_type: PlayerType = PlayerType.OFF
var _mpv_desktop_pending_player_type: PlayerType = PlayerType.OFF

var player_interface: VideoPlayerBase


func _ready():
	self_modulate.a = 2
	
	$Main/HelpButton.hide()
	
	if OS.get_name() != "Android":
		$Main/PlayerSelection.set_item_disabled(PlayerType.MPV_ANDROID, true)
	
	connection_changed.connect(func(is_conn: bool):
			if is_conn:
				$Main/ConnectionIndicator.show()
			else:
				$Main/ConnectionIndicator.hide())
	
	_delay_timer = Timer.new()
	_delay_timer.name = "DelayTimer"
	_delay_timer.one_shot = true
	add_child(_delay_timer)
	_delay_timer.timeout.connect(_on_delay_timeout)
	
	_cooldown_timer = Timer.new()
	_cooldown_timer.name = "CooldownTimer"
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = 0.5
	add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(func(): _cooldown = false)

	_load_file_http = HTTPRequest.new()
	_load_file_http.name = "CommandHTTP"
	_load_file_http.timeout = 2
	add_child(_load_file_http)
	_load_file_http.request_completed.connect(_on_load_funscript)
	

func is_active() -> bool:
	return player_type != PlayerType.OFF


func try_load_video(funscript_path: String):
	if player_type == PlayerType.OFF or player_type == PlayerType.STASH:
		return

	var extensionless_path = funscript_path.get_basename()
	var mp4Path = extensionless_path + ".mp4"
	if FileAccess.file_exists(mp4Path):
		_load_video(mp4Path)
		return

	var mkvPath = extensionless_path + ".mkv"
	if FileAccess.file_exists(mkvPath):
		_load_video(mkvPath)
		return

	# try stripping off one more "." level
	extensionless_path = extensionless_path.get_basename()
	mp4Path = extensionless_path + ".mp4"
	if FileAccess.file_exists(mp4Path):
		_load_video(mp4Path)
		return


func _load_video(path: String):
	var command = r'mpv "' + path + r'"'
	OS.create_process("cmd", ["/c", command])


func _load_funscript(url: String):
	_load_file_http.cancel_request()
	_load_file_http.request(url)


func _on_load_funscript(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_error("[videoplayer] Funscript Request failed %d - %s " % [result, response_code])
		return
	var json_raw = body.get_string_from_utf8()
	
	owner.load_raw(json_raw)


func activate(type: PlayerType):
	deactivate()
	player_type = type
	if type == PlayerType.OFF:
		return

	if player_interface:
		player_interface.player_address = player_address
		player_interface.player_port = player_port
		if type == PlayerType.MPV_ANDROID:
			player_interface.saf_mpv_bridge_uri = %FileUtil.saf_mpv_bridge_uri
		if type == PlayerType.VLC:
			player_interface.vlc_password = vlc_password
		player_interface.activate()


func deactivate():
	player_type = PlayerType.OFF
	if player_interface:
		player_interface.deactivate()

	_delay_timer.stop()
	_cooldown_timer.stop()
	_cooldown = false
	_load_file_http.cancel_request()
	_pending_action = ""
	player_state.merge({
		"state": "stopped",
		"time": 0.0,
		"duration": 0.0,
	}, true)
	connected = false


# ---- App -> Video Player ----

func sync_play():
	if player_interface:
		player_interface.send_play()

	_start_cooldown()
	if delay_ms > 0:
		_pending_action = "play"
		_delay_timer.wait_time = delay_ms / 1000.0
		_delay_timer.start()
	else:
		owner.play()


func sync_pause():
	if player_interface:
		player_interface.send_pause()

	_start_cooldown()
	if delay_ms > 0:
		_pending_action = "pause"
		_delay_timer.wait_time = delay_ms / 1000.0
		_delay_timer.start()
	else:
		owner.pause()


func sync_seek(path_time_seconds: float):
	var video_time = _path_to_video_time(path_time_seconds)
	if player_interface:
		player_interface.send_seek(video_time)

	_start_cooldown()


func pause_and_seek(path_time_seconds: float):
	var video_time = _path_to_video_time(path_time_seconds)
	if player_interface:
		player_interface.send_pause(video_time)

	_start_cooldown()


func pause_player():
	if not is_active():
		return

	if player_interface:
		player_interface.send_pause()
	_start_cooldown()


func _on_delay_timeout():
	match _pending_action:
		"play":
			owner.play()
		"pause":
			owner.pause()
	_pending_action = ""


func _path_to_video_time(path_time_seconds: float) -> float:
	var video_time = path_time_seconds - delay_ms / 1000.0 + video_offset_ms / 1000.0
	if player_type == PlayerType.VLC and vlc_seek_correction != 0:
		video_time -= vlc_seek_correction * video_time / 60.0 / 1000.0
	return maxf(video_time, 0.0)


func _process_state(state: Dictionary):
	var old_state = player_state.get("state")
	var old_time = player_state.get("time")
	var new_state: String = state.get("state", old_state)
	var new_time: float = state.get("time", old_time)
	var funscriptUrl = state.get('filename')
	if funscriptUrl and player_state.get('filename') != funscriptUrl:
		_load_funscript(funscriptUrl)

	player_state.merge(state, true)
	if _cooldown:
		return
	if new_state != old_state:
		match new_state:
			"playing":
				var adjusted = new_time - video_offset_ms / 1000.0 + delay_ms / 1000.0 + advance_ms / 1000.0
				player_played.emit(maxf(adjusted, 0.0), old_state == "stopped")
			"paused", "stopped":
				player_paused.emit()
	elif abs(new_time - old_time) > 1.5:
		var adjusted = new_time - video_offset_ms / 1000.0 + delay_ms / 1000.0
		player_seeked.emit(maxf(adjusted, 0.0))


func _mpv_android_saf_path(rel: String) -> String:
	# Builds a Godot SAF FileAccess path from the picked bridge tree URI.
	var uri: String = %FileUtil.saf_mpv_bridge_uri
	if uri.is_empty():
		return ""
	return uri + "#" + rel


func _mpv_android_ensure_subdir(rel_path: String) -> bool:
	# Walks rel_path and creates each missing component as a directory.
	var uri: String = %FileUtil.saf_mpv_bridge_uri
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
				if cursor.getStrinFg(name_col) == part:
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


func _mpv_android_install_lua() -> bool:
	if not _mpv_android_ensure_subdir(VideoPlayerMpvAndroid._MPV_ANDROID_SCRIPTS_SUBDIR):
		return false
	var src := FileAccess.open(VideoPlayerMpvAndroid._MPV_ANDROID_LUA_SOURCE, FileAccess.READ)
	if src == null:
		push_warning("MPV_ANDROID: lua source missing at " + VideoPlayerMpvAndroid._MPV_ANDROID_LUA_SOURCE)
		return false
	var body := src.get_as_text()
	src.close()
	var dst_path := _mpv_android_saf_path(VideoPlayerMpvAndroid._MPV_ANDROID_LUA_FILE)
	var dst := FileAccess.open(dst_path, FileAccess.WRITE)
	if dst == null:
		push_warning("MPV_ANDROID: cannot write lua to " + dst_path)
		return false
	dst.store_string(body)
	dst.close()
	return true


func _mpv_android_ensure_mpv_media_dir() -> bool:
	# Attempts to create /Android/media/is.xyz.mpv/ so the SAF picker has
	# a target to navigate to even when mpv-android hasn't been opened yet.
	# Cross-app writes into another package's /Android/media/<pkg>/ are
	# generally blocked by scoped storage on API 30+ — if this fails, the
	# user has to open mpv-android once first to create the dir.
	var path := "/storage/emulated/0/Android/media/is.xyz.mpv"
	if DirAccess.dir_exists_absolute(path):
		return true
	var err := DirAccess.make_dir_recursive_absolute(path)
	if err != OK:
		push_warning("MPV_ANDROID: could not create mpv media dir: " + str(err))
		return false
	return true


func _start_cooldown():
	_cooldown = true
	_cooldown_timer.start()


func reconnect(_player_type: PlayerType) -> void:
	deactivate()
	if _player_type > 0:
		activate(_player_type)


func _on_player_selection_item_selected(index: int) -> void:
	$Main/PlayerAddress.show()
	$Main/PlayerPort.show()
	$Main/DelayMs.show()
	$Main/AdvanceMs.show()
	$Main/VideoOffset.show()
	$Main/HelpButton.show()
	$Main/VLCPassword.hide()
	$Main/VLCSeekCorrection.hide()
	if player_interface:
		remove_child(player_interface)
		player_interface = null
	
	player_type = index as PlayerType
	UserSettings.set_value(UserSettings.Section.video_player, 'player_type', index)
	match player_type:
		PlayerType.OFF:
			$Main/PlayerAddress.hide()
			$Main/PlayerPort.hide()
			$Main/DelayMs.hide()
			$Main/AdvanceMs.hide()
			$Main/VideoOffset.hide()
			$Main/HelpButton.hide()
			deactivate()
			return
		PlayerType.VLC:
			$Main/VLCPassword.show()
			$Main/VLCSeekCorrection.show()
			player_port = UserSettings.get_value(UserSettings.Section.video_player, 'vlc_port', 8080)
			delay_ms = UserSettings.get_value(UserSettings.Section.video_player, 'vlc_delay_ms', 0)
			advance_ms = UserSettings.get_value(UserSettings.Section.video_player, 'vlc_advance_ms', 100)
			player_interface = VideoPlayerVlc.new(player_address, player_port, vlc_password,
				Callable(self, "_sync_connected"),
				Callable(self, "_on_state_change")
			)
		PlayerType.MPC:
			player_port = UserSettings.get_value(UserSettings.Section.video_player, 'mpc_port', 13579)
			delay_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpc_delay_ms', 0)
			advance_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpc_advance_ms', 100)
			player_interface = VideoPlayerMpc.new(player_address, player_port,
				Callable(self, "_sync_connected"),
				Callable(self, "_on_state_change")
			)
		PlayerType.MPV:
			player_port = UserSettings.get_value(UserSettings.Section.video_player, 'mpv_port', 9001)
			delay_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpv_delay_ms', 0)
			advance_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpv_advance_ms', 100)
			player_interface = VideoPlayerMpv.new(player_address, player_port,
				Callable(self, "_sync_connected"),
				Callable(self, "_on_state_change")
			)
		PlayerType.MPV_ANDROID:
			$Main/PlayerAddress.hide()
			$Main/PlayerPort.hide()
			delay_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpv_android_delay_ms', 0)
			advance_ms = UserSettings.get_value(UserSettings.Section.video_player, 'mpv_android_advance_ms', 100)
			player_interface = VideoPlayerMpvAndroid.new(
				%FileUtil.saf_mpv_bridge_uri,
				Callable(self, "_sync_connected"),
				Callable(self, "_on_state_change")
			)
		PlayerType.STASH:
			$Main/PlayerPort.hide()
			player_port = UserSettings.get_value(UserSettings.Section.video_player, 'stash_port', 9009)
			delay_ms = UserSettings.get_value(UserSettings.Section.video_player, 'stash_delay_ms', 0)
			advance_ms = UserSettings.get_value(UserSettings.Section.video_player, 'stash_advance_ms', 100)
			player_interface = VideoPlayerStash.new(player_port,
				Callable(self, "_sync_connected"),
				Callable(self, "_on_state_change")
			)
	if player_interface:
		add_child(player_interface, false, INTERNAL_MODE_BACK)

	$Main/PlayerPort/Input.set_value_no_signal(player_port)
	$Main/DelayMs/Input.value = delay_ms
	$Main/AdvanceMs/Input.value = advance_ms
	if player_type == PlayerType.MPV_ANDROID and %FileUtil.saf_mpv_bridge_uri.is_empty():
		# Defer activation until SAF folder is granted.
		_mpv_android_pending_player_type = PlayerType.MPV_ANDROID
		_mpv_android_ensure_mpv_media_dir()
		$MPVBridgeSplash.show()
		return
	if player_type == PlayerType.MPV and not MPVBridgeInstaller.is_installed():
		# Defer activation until the user consents to the lua/conf install.
		_mpv_desktop_pending_player_type = PlayerType.MPV
		_populate_mpv_bridge_desktop_splash()
		$MPVBridgeDesktopSplash.show()
		return
	activate(player_type)


func _on_player_address_text_submitted(new_text: String) -> void:
	player_address = new_text
	UserSettings.set_value(UserSettings.Section.video_player, 'player_address', new_text)
	reconnect(player_type)


func _on_player_port_value_changed(value: float) -> void:
	player_port = int(value)
	match player_type:
		PlayerType.VLC:
			UserSettings.set_value(UserSettings.Section.video_player, 'vlc_port', player_port)
		PlayerType.MPC:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpc_port', player_port)
		PlayerType.MPV:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpv_port', player_port)
			MPVBridgeInstaller.update_port(player_port)
	reconnect(player_type)


func _on_vlc_password_text_submitted(new_text: String) -> void:
	vlc_password = new_text
	UserSettings.set_value(UserSettings.Section.video_player, 'vlc_password', new_text)
	reconnect(player_type)


func _on_delay_ms_value_changed(value: float) -> void:
	delay_ms = int(value)
	match player_type:
		PlayerType.VLC:
			UserSettings.set_value(UserSettings.Section.video_player, 'vlc_delay_ms', delay_ms)
		PlayerType.MPC:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpc_delay_ms', delay_ms)
		PlayerType.MPV:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpv_delay_ms', delay_ms)
		PlayerType.MPV_ANDROID:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpv_android_delay_ms', delay_ms)
		PlayerType.STASH:
			UserSettings.set_value(UserSettings.Section.video_player, 'stash_delay_ms', delay_ms)


func _on_advance_ms_value_changed(value: float) -> void:
	advance_ms = int(value)
	match player_type:
		PlayerType.VLC:
			UserSettings.set_value(UserSettings.Section.video_player, 'vlc_advance_ms', advance_ms)
		PlayerType.MPC:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpc_advance_ms', advance_ms)
		PlayerType.MPV:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpv_advance_ms', advance_ms)
		PlayerType.MPV_ANDROID:
			UserSettings.set_value(UserSettings.Section.video_player, 'mpv_android_advance_ms', advance_ms)
		PlayerType.STASH:
			UserSettings.set_value(UserSettings.Section.video_player, 'stash_advance_ms', advance_ms)


func _on_video_offset_ms_value_changed(value: float) -> void:
	video_offset_ms = int(value)
	UserSettings.set_value(UserSettings.Section.video_player, 'video_offset_ms', video_offset_ms)


func _on_vlc_seek_correction_value_changed(value: float) -> void:
	vlc_seek_correction = value
	UserSettings.set_value(UserSettings.Section.video_player, 'vlc_seek_correction', vlc_seek_correction)


func _on_mpv_bridge_pick_pressed() -> void:
	var err := DisplayServer.file_dialog_show(
			"Pick mpv-android folder",
			"",
			"",
			false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
			PackedStringArray(),
			_on_mpv_bridge_folder_picked)
	if err != OK:
		push_error("file_dialog_show failed: %s" % err)


func _on_mpv_bridge_folder_picked(
		status: bool,
		paths: PackedStringArray,
		_filter_idx: int) -> void:
	if not status or paths.is_empty():
		return
	var uri: String = paths[0]
	if not _mpv_android_uri_is_correct_folder(uri):
		OS.alert(
			"Please pick the 'is.xyz.mpv' folder inside Android/media.",
			"Wrong folder")
		return
	%FileUtil.saf_mpv_bridge_uri = uri
	%FileUtil.save_saf_mpv_bridge_uri(uri)
	%FileUtil.take_persistable_uri_permission(uri)
	if not _mpv_android_install_lua():
		push_warning("MPV_ANDROID: lua install failed")
	$MPVBridgeSplash.hide()
	$MPVSettingsCopySplash.show()


func _mpv_android_uri_is_correct_folder(uri: String) -> bool:
	# SAF tree URI ends with the URL-encoded document ID, e.g.
	# .../tree/primary%3AAndroid%2Fmedia%2Fis.xyz.mpv
	return uri.uri_decode().trim_suffix("/").ends_with(
		VideoPlayerMpvAndroid._MPV_ANDROID_EXPECTED_DOC_ID)


func _on_mpv_bridge_copy_pressed() -> void:
	DisplayServer.clipboard_set(VideoPlayerMpvAndroid._MPV_ANDROID_SCRIPT_LINE)


func _on_mpv_bridge_done_pressed() -> void:
	$MPVSettingsCopySplash.hide()
	if _mpv_android_pending_player_type == PlayerType.MPV_ANDROID:
		_mpv_android_pending_player_type = PlayerType.OFF
		activate(PlayerType.MPV_ANDROID)


func _on_mpv_bridge_cancel_pressed() -> void:
	$MPVBridgeSplash.hide()
	_mpv_android_pending_player_type = PlayerType.OFF
	$Main/PlayerSelection.select(PlayerType.OFF)
	player_type = PlayerType.OFF
	UserSettings.set_value(UserSettings.Section.video_player, 'player_type', PlayerType.OFF)
	deactivate()


func _populate_mpv_bridge_desktop_splash() -> void:
	var lua_path := MPVBridgeInstaller.get_lua_path()
	var conf_path := MPVBridgeInstaller.get_conf_path()
	$MPVBridgeDesktopSplash/VBox/Label.text = (
			"[u]To use mpv, OSSM Sauce needs to install a bridge script.[/u]\n\n"
			+"Files will be written to:\n\n"
			+ lua_path + "\n\n"
			+ conf_path + "\n\n"
			+"[u]Make sure to restart mpv player after installing.[/u]")


func _on_mpv_bridge_install_pressed() -> void:
	var err := MPVBridgeInstaller.install(player_port)
	if err != OK:
		printerr("MPV bridge install failed: %s" % error_string(err))
		_on_mpv_bridge_install_cancel_pressed()
		return
	$MPVBridgeDesktopSplash.hide()
	if _mpv_desktop_pending_player_type == PlayerType.MPV:
		_mpv_desktop_pending_player_type = PlayerType.OFF
		activate(PlayerType.MPV)


func _on_mpv_bridge_install_cancel_pressed() -> void:
	$MPVBridgeDesktopSplash.hide()
	_mpv_desktop_pending_player_type = PlayerType.OFF
	$Main/PlayerSelection.select(PlayerType.OFF)
	player_type = PlayerType.OFF
	UserSettings.set_value(UserSettings.Section.video_player, 'player_type', PlayerType.OFF)
	deactivate()


func _on_back_pressed() -> void:
	if $Help/VLCSetupInstructions.visible:
		$Help/VLCSetupInstructions.hide()
		$Help/VLCInfo.show()
		return
	if $Help/MPCSetupInstructions.visible:
		$Help/MPCSetupInstructions.hide()
		$Help/MPCInfo.show()
		return
	if $Help.visible:
		$Help.hide()
		$Main.show()
		return
	hide()


func _on_help_button_pressed() -> void:
	$Main.hide()
	$Help/VLCInfo.hide()
	$Help/MPCInfo.hide()
	$Help/mpvInfo.hide()
	$Help/mpvAndroidInfo.hide()
	$Help/VLCSetupInstructions.hide()
	$Help/MPCSetupInstructions.hide()
	$Help/mpvRestartReminder.hide()
	match player_type:
		PlayerType.VLC:
			$Help/VLCInfo.show()
		PlayerType.MPC:
			$Help/MPCInfo.show()
		PlayerType.MPV:
			$Help/mpvInfo.show()
		PlayerType.MPV_ANDROID:
			$Help/mpvAndroidInfo.show()
	$Help.show()


func _on_reinstall_lua_scripts_pressed() -> void:
	var err := MPVBridgeInstaller.install(player_port)
	if err != OK:
		printerr("MPV bridge reinstall failed: %s" % error_string(err))
		return
	$Help/mpvRestartReminder.show()


func _on_open_mpv_directory_pressed() -> void:
	MPVBridgeInstaller.open_mpv_folder()


func _on_reinstall_mpv_android_lua_pressed() -> void:
	if not _mpv_android_install_lua():
		return
	$Help/mpvRestartReminder.show()


func _on_vlc_setup_instructions_pressed() -> void:
	$Help/VLCInfo.hide()
	$Help/mpvRestartReminder.hide()
	$Help/VLCSetupInstructions.show()


func _on_mpc_setup_instructions_pressed() -> void:
	$Help/MPCInfo.hide()
	$Help/mpvRestartReminder.hide()
	$Help/MPCSetupInstructions.show()


# ---- Video Player Callbacks ----

func _sync_connected(is_conn: bool) -> void:
	connected = is_conn


func _on_state_change(state: Dictionary) -> void:
	_process_state(state)
