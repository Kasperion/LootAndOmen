extends SubViewport

const ATMOSPHERE := preload("res://art/heavy_ink/atmosphere.gdshader")
var mist := ShaderMaterial.new()

func _init(board_size: Vector2i, fire: Vector2i, light_radius: int) -> void:
	size = board_size * 24
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	mist.shader = ATMOSPHERE
	mist.set_shader_parameter("board_size", Vector2(board_size))
	mist.set_shader_parameter("fire_center", Vector2(fire) + Vector2(0.5, 0.5))
	mist.set_shader_parameter("light_radius", float(light_radius))
	var layer := ColorRect.new()
	layer.size = Vector2(size)
	layer.material = mist
	add_child(layer)

func show_mist(visible: bool, road: bool, fire_lit: bool) -> void:
	mist.set_shader_parameter("on_road", road)
	mist.set_shader_parameter("fire_lit", fire_lit)
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
