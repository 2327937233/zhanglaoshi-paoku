extends StaticBody2D

var obstacle_type: String = "rock_small"
var _start_y: float = 0.0
var _time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("obstacle")
	_start_y = position.y
	_time = randf() * PI * 2
	_setup_visual()

func _process(delta: float) -> void:
	pass

func _setup_visual() -> void:
	if sprite == null:
		return

	sprite.texture = _load_texture(_get_texture_path())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 5

	if obstacle_type == "bird":
		var rope := ColorRect.new()
		rope.name = "Rope"
		rope.position = Vector2(21, 0)
		rope.size = Vector2(3, 260)
		rope.color = Color(0.35, 0.25, 0.15, 0.85)
		add_child(rope)

func _get_texture_path() -> String:
	match obstacle_type:
		"rock_small":
			return "res://assets/obstacle_construction_cone.png"
		"rock_tall":
			return "res://assets/obstacle_concrete_rebar.png"
		"crate":
			return "res://assets/obstacle_brick_stack.png"
		"bird":
			return "res://assets/obstacle_crane_hook.png"
		_:
			return "res://assets/obstacle_construction_cone.png"

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)
