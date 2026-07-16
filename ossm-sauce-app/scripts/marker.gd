class_name Marker


func _init(at_val: int, depth_val: float) -> void:
	self.at = at_val
	self.depth = depth_val

var at: int:
	get:
		return at

var depth: float:
	get:
		return depth

var _auxiliary: int = 0

var marker_frame: int:
	get:
		return int(at / (1000.0 / Global.ticks_per_second))

var network_packet: PackedByteArray:
	get:
		return OSSMCommand.create_move_command(at, Util.safe_map_physical_position(depth), Global.transition, Global.easing, _auxiliary)
