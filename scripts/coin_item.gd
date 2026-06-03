extends Area2D

const DISPLAY_SIZE := 38.0
const BASKETBALL_DISPLAY_SIZE := 34.0
const TREADMILL_DISPLAY_SIZE := 62.0
const ICED_TEA_DISPLAY_SIZE := 46.0
const PICKUP_RADIUS := 20.0
const TREADMILL_PICKUP_SIZE := Vector2(64.0, 46.0)
const ICED_TEA_PICKUP_SIZE := Vector2(34.0, 52.0)

var coin_type: String = "qiaolezi"
var _phase: float = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _collected: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	z_index = 6
	add_to_group("coin")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_setup_collision()
	_setup_visual()

func init(type: String) -> void:
	coin_type = type
	_phase = randf() * PI * 2
	_setup_visual()

func _setup_visual() -> void:
	var tex_path := _get_texture_path()
	var tex: Texture2D = _load_png_texture(tex_path)
	if tex and sprite:
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2.ZERO
		sprite.z_index = 6
		var max_side: float = float(max(tex.get_width(), tex.get_height()))
		var display_size := DISPLAY_SIZE
		if coin_type == "basketball":
			display_size = BASKETBALL_DISPLAY_SIZE
		elif coin_type == "treadmill":
			display_size = TREADMILL_DISPLAY_SIZE
		elif coin_type == "iced_tea":
			display_size = ICED_TEA_DISPLAY_SIZE
		var s: float = display_size / max_side
		_base_scale = Vector2(s, s)
		sprite.scale = _base_scale

func _get_texture_path() -> String:
	match coin_type:
		"qiaolezi":
			return "res://assets/qiaolezi_item_cutout.png"
		"xuebi":
			return "res://assets/xuebi_item_cutout.png"
		"basketball":
			return "res://assets/basketball_item.png"
		"treadmill":
			return "res://assets/treadmill_shield_item.png"
		"iced_tea":
			return "res://assets/iced_tea_item.png"
		_:
			return "res://assets/qiaolezi_item_cutout.png"

func _setup_collision() -> void:
	if collision_shape.shape == null or not (collision_shape.shape is CircleShape2D):
		collision_shape.shape = CircleShape2D.new()
	var circle := collision_shape.shape as CircleShape2D
	if coin_type == "treadmill":
		circle.radius = 26.0
	elif coin_type == "iced_tea":
		circle.radius = 24.0
	else:
		circle.radius = PICKUP_RADIUS
	collision_shape.position = Vector2.ZERO

func _load_png_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if _collected:
		return

	_phase += delta * 5.0
	if sprite:
		if coin_type == "basketball":
			sprite.rotation += delta * 8.5
			var pulse := 1.0 + 0.06 * sin(_phase * 1.4)
			sprite.scale = _base_scale * pulse
			sprite.position.y = sin(_phase) * 4.0
			return
		if coin_type == "treadmill":
			var pulse := 1.0 + 0.05 * sin(_phase * 1.2)
			sprite.scale = _base_scale * pulse
			sprite.rotation = sin(_phase * 0.7) * 0.035
			sprite.position.y = sin(_phase) * 4.0
			return
		if coin_type == "iced_tea":
			var pulse := 1.0 + 0.07 * sin(_phase * 1.35)
			sprite.scale = _base_scale * pulse
			sprite.rotation = sin(_phase * 0.9) * 0.045
			sprite.position.y = sin(_phase) * 5.0
			return

		var spin: float = abs(cos(_phase))
		sprite.scale.x = _base_scale.x * (0.82 + 0.18 * spin)
		sprite.scale.y = _base_scale.y * (0.96 + 0.04 * sin(_phase * 1.7))
		sprite.position.y = sin(_phase) * 3.0

func get_pickup_rect() -> Rect2:
	if _collected:
		return Rect2()
	if coin_type == "treadmill":
		return Rect2(position - TREADMILL_PICKUP_SIZE * 0.5, TREADMILL_PICKUP_SIZE)
	if coin_type == "iced_tea":
		return Rect2(position - ICED_TEA_PICKUP_SIZE * 0.5, ICED_TEA_PICKUP_SIZE)
	return Rect2(position - Vector2(PICKUP_RADIUS, PICKUP_RADIUS), Vector2(PICKUP_RADIUS * 2.0, PICKUP_RADIUS * 2.0))

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	if _collected:
		return
	_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if sprite:
		sprite.hide()

	var main: Node = get_tree().current_scene
	if main == null and get_parent():
		main = get_parent().get_parent()
	if main and main.has_method("collect_coin"):
		main.collect_coin(coin_type, global_position)
	queue_free()
