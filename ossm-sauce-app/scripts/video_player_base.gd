@abstract class_name VideoPlayerBase

@export var player_address: String = "127.0.0.1"
@export var player_port: int = 8080

@abstract func activate(poll_timer: Timer)
@abstract func deactivate(poll_timer: Timer)

@abstract func send_play()
@abstract func send_pause()
@abstract func send_seek(time_seconds: float, player_duration: float)
@abstract func process(delta)
@abstract func poll_status()

@abstract func on_poll_completed(body: PackedByteArray)
@abstract func on_command_completed(body: PackedByteArray)
