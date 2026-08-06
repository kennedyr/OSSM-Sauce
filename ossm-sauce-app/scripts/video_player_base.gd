@abstract class_name VideoPlayerBase

extends Node

@export var player_address: String = "127.0.0.1"
@export var player_port: int = 8080

@abstract func activate()
@abstract func deactivate()

@abstract func send_play()
@abstract func send_pause(time_seconds := -1.0)
@abstract func send_seek(time_seconds: float)
