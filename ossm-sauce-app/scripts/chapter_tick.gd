extends TextureRect

func flash():
	modulate = Color.BLACK
	await get_tree().create_timer(1).timeout
	modulate = Color.WHITE
