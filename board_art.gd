extends RefCounted

func make_night_shade(board_size: Vector2i, fire: Vector2i, cell: int, light_radius: int) -> ImageTexture:
	# Paint the mist at half resolution. The rules still use the exact tile boundary.
	var image := Image.create(board_size.x * cell / 2, board_size.y * cell / 2, false, Image.FORMAT_RGBA8)
	var fire_center := Vector2(fire) + Vector2(0.5, 0.5)
	var noise := FastNoiseLite.new()
	noise.seed = 220
	noise.frequency = 0.026
	for y in image.get_height():
		for x in image.get_width():
			var offset := Vector2(x, y) * 2.0 / cell - fire_center
			var distance := offset.length()
			var cloud := noise.get_noise_2d(x, y)
			var edge := smoothstep(light_radius - 0.36, light_radius + 0.62, distance + cloud * 0.42)
			var light := Color(1.0, 0.63, 0.28, 0.19 - 0.11 * clampf(distance / light_radius, 0.0, 1.0))
			var haze := clampf(cloud * 0.58 + sin(y * 0.08 + cloud * 1.7) * 0.10, -0.12, 0.4)
			var dark := Color(0.023 + haze * 0.18, 0.048 + haze * 0.24, 0.100 + haze * 0.34, 0.58 - haze * 0.19)
			image.set_pixel(x, y, light.lerp(dark, edge))
	return ImageTexture.create_from_image(image)
