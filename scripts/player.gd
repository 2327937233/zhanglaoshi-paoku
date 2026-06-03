extends CharacterBody2D

const GRAVITY := 1400.0
const JUMP_VELOCITY := -440.0
const MAX_JUMPS := 2
const GROUND_Y := 370.0
const PLAYER_H := 56.0

const SPRITE_SHEET := "res://assets/zhanglaoshi_sprite_sheet_aligned.png"
const FRAME_SIZE := Vector2i(256, 256)
const SHEET_COLUMNS := 8
const SPRITE_SCALE := 0.25
const SPRITE_ANCHOR := Vector2(128, 246)
const SPRITE_OFFSET := Vector2(20, PLAYER_H) - SPRITE_ANCHOR * SPRITE_SCALE

const ANIMS := {
	"idle": [0, 1],
	"start_run": [2, 3],
	"run": [4, 5, 6, 7, 8, 9, 10, 11],
	"hard_stop": [12, 13],
	"jump_crouch": [14, 15],
	"takeoff": [16, 17],
	"jump_up": [18, 19],
	"apex": [20],
	"fall": [21, 22],
	"land": [23, 24],
	"crouch": [25],
	"slide": [26, 27],
	"hurt": [28, 29],
	"victory": [30, 31],
}

var jumps_remaining: int = MAX_JUMPS
var is_dead: bool = false
var _was_on_ground: bool = true
var _anim_name: String = ""
var _anim_time: float = 0.0
var _one_shot_anim: bool = false
var _land_timer: float = 0.0
var _slide_timer: float = 0.0
var _jump_charge_timer: float = 0.0
var _crouch_held: bool = false
var _shoot_timer: float = 0.0
var _visual_multiplier: float = 1.0

signal died

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	var tex: Texture2D = load(SPRITE_SHEET) if ResourceLoader.exists(SPRITE_SHEET) else null
	if tex == null:
		var image := Image.new()
		if image.load(SPRITE_SHEET) == OK:
			tex = ImageTexture.create_from_image(image)

	if tex:
		sprite.texture = tex
		sprite.region_enabled = true
		sprite.centered = false
		sprite.offset = Vector2.ZERO
		_apply_visual_transform()
		_play_anim("idle")

	if collision_shape.shape == null:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(40, PLAYER_H)
		collision_shape.shape = rect
	collision_shape.position = Vector2(20, PLAYER_H / 2)

	add_to_group("player")
	reset()

func reset() -> void:
	is_dead = false
	jumps_remaining = MAX_JUMPS
	velocity = Vector2.ZERO
	position = Vector2(120, GROUND_Y - PLAYER_H)
	_was_on_ground = true
	_land_timer = 0.0
	_slide_timer = 0.0
	_jump_charge_timer = 0.0
	_crouch_held = false
	_shoot_timer = 0.0
	_visual_multiplier = 1.0
	sprite.rotation = 0.0
	_apply_visual_transform()
	_play_anim("idle")

func set_power_scale(multiplier: float) -> void:
	_visual_multiplier = maxf(0.2, multiplier)
	_apply_visual_transform()

func get_visual_multiplier() -> float:
	return _visual_multiplier

func get_visual_center() -> Vector2:
	var scale_value := SPRITE_SCALE * _visual_multiplier
	return Vector2(20.0, PLAYER_H) + Vector2(0.0, (128.0 - SPRITE_ANCHOR.y) * scale_value)

func _apply_visual_transform() -> void:
	if sprite == null:
		return
	var scale_value := SPRITE_SCALE * _visual_multiplier
	sprite.scale = Vector2(scale_value, scale_value)
	sprite.position = Vector2(20.0, PLAYER_H) - SPRITE_ANCHOR * scale_value

func start_running() -> void:
	if is_dead:
		return
	_play_anim("start_run", true)     

func set_crouch_pressed(pressed: bool) -> void:
	_crouch_held = pressed
	if pressed and _is_on_ground() and _slide_timer <= 0.0:
		_slide_timer = 0.1
		_play_anim("slide")

func slide() -> void:
	if is_dead:
		return
	if _is_on_ground() and _slide_timer <= 0.0:
		_slide_timer = 0.38
		_play_anim("slide")

func shoot_basketball() -> void:
	if is_dead:
		return
	_shoot_timer = 0.48
	_slide_timer = 0.0
	_jump_charge_timer = 0.0
	_crouch_held = false
	_play_anim("victory", true)

func jump() -> void:
	if is_dead:
		return
	if jumps_remaining <= 0:
		return

	var was_grounded := _is_on_ground()
	if was_grounded:
		_jump_charge_timer = 0.10
		_slide_timer = 0.0
		_crouch_held = false
		_play_anim("jump_crouch", true)
		return

	_perform_jump(was_grounded)

func _perform_jump(was_grounded: bool) -> void:
	velocity.y = JUMP_VELOCITY
	jumps_remaining -= 1
	_slide_timer = 0.0
	_jump_charge_timer = 0.0
	_crouch_held = false

	if was_grounded:
		_play_anim("takeoff", true)
	else:
		_play_anim("jump_up")

	var main: Node = get_tree().current_scene
	if main == null:
		main = get_parent()
	if main and main.has_method("play_sound"):
		if jumps_remaining == 0:
			main.play_sound("double_jump")
		else:
			main.play_sound("jump")

func get_hit_rect() -> Rect2:
	if _slide_timer > 0.0 or _crouch_held:
		return Rect2(position + Vector2(4, 24), Vector2(36, 30))
	return Rect2(position + Vector2(4, 4), Vector2(32, 48))

func _update_collision_shape(on_ground: bool) -> void:
	if not collision_shape or collision_shape.shape == null:
		return
	var crouching := on_ground and (_slide_timer > 0.0 or _crouch_held)
	if crouching:
		collision_shape.shape.size = Vector2(40, 30)
		collision_shape.position = Vector2(20, 39)
	else:
		collision_shape.shape.size = Vector2(40, PLAYER_H)
		collision_shape.position = Vector2(20, PLAYER_H / 2)

func _physics_process(delta: float) -> void:
	if is_dead:
		_update_animation(delta)
		return

	if _jump_charge_timer > 0.0:
		_jump_charge_timer = maxf(0.0, _jump_charge_timer - delta)
		if _jump_charge_timer <= 0.0:
			_perform_jump(true)

	velocity.y += GRAVITY * delta

	var on_ground := _is_on_ground()
	if on_ground and velocity.y > 0:
		position.y = GROUND_Y - PLAYER_H
		velocity.y = 0
		jumps_remaining = MAX_JUMPS

	move_and_slide()

	on_ground = _is_on_ground()
	if on_ground:
		position.y = GROUND_Y - PLAYER_H
		if velocity.y > 0:
			velocity.y = 0
		jumps_remaining = MAX_JUMPS

	if on_ground and not _was_on_ground:
		_land_timer = 0.16
		_play_anim("land", true)
	_was_on_ground = on_ground

	if _slide_timer > 0.0:
		_slide_timer = maxf(0.0, _slide_timer - delta)

	if _shoot_timer > 0.0:
		_shoot_timer = maxf(0.0, _shoot_timer - delta)

	if _crouch_held and on_ground:
		_slide_timer = 0.1
	_update_collision_shape(on_ground)

	_update_motion_animation(on_ground)
	_update_animation(delta)

	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider := col.get_collider() if col else null
		if collider is Node and (collider as Node).is_queued_for_deletion():
			continue
		if collider and collider.is_in_group("obstacle"):
			var main: Node = get_tree().current_scene
			if main and main.has_method("handle_player_obstacle_contact") and main.handle_player_obstacle_contact(collider):
				continue
			if main and main.has_method("try_consume_shield") and main.try_consume_shield(collider):
				continue
			die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	_play_anim("hurt")
	died.emit()

func _is_on_ground() -> bool:
	return position.y >= GROUND_Y - PLAYER_H - 0.1

func _update_motion_animation(on_ground: bool) -> void:
	if is_dead:
		return

	if _jump_charge_timer > 0.0:
		_play_anim("jump_crouch", true)
		return

	if _shoot_timer > 0.0:
		_play_anim("victory", true)
		return

	if _slide_timer > 0.0:
		_play_anim("slide")
		return

	if on_ground:
		if _crouch_held:
			_play_anim("crouch")
			return

		if _land_timer > 0.0:
			return

		if _one_shot_anim and (_anim_name == "start_run" or _anim_name == "jump_crouch"):
			return

		_play_anim("run")
		return

	if _one_shot_anim and _anim_name == "takeoff":
		return

	if velocity.y < -90.0:
		_play_anim("jump_up")
	elif absf(velocity.y) <= 90.0:
		_play_anim("apex")
	else:
		_play_anim("fall")

func _update_animation(delta: float) -> void:
	_anim_time += delta
	if _land_timer > 0.0:
		_land_timer = maxf(0.0, _land_timer - delta)

	var frames: Array = ANIMS.get(_anim_name, ANIMS["idle"])
	var fps := _get_anim_fps(_anim_name)
	var frame_index := 0

	if frames.size() > 1:
		frame_index = int(floor(_anim_time * fps))
		if _one_shot_anim:
			if frame_index >= frames.size():
				_one_shot_anim = false
				match _anim_name:
					"start_run":
						_play_anim("run")
						return
					"takeoff":
						_play_anim("jump_up")
						return
					"land":
						_play_anim("run")
						return
				frame_index = frames.size() - 1
			else:
				frame_index = min(frame_index, frames.size() - 1)
		else:
			frame_index %= frames.size()

	_set_frame(int(frames[frame_index]))

func _play_anim(name: String, one_shot: bool = false) -> void:
	if _anim_name == name and _one_shot_anim == one_shot:
		return
	if not ANIMS.has(name):
		name = "idle"

	_anim_name = name
	_anim_time = 0.0
	_one_shot_anim = one_shot
	var frames: Array = ANIMS[name]
	_set_frame(int(frames[0]))

func _set_frame(frame: int) -> void:
	if sprite.texture == null:
		return
	var col := frame % SHEET_COLUMNS
	var row := floori(float(frame) / float(SHEET_COLUMNS))
	sprite.region_rect = Rect2(
		Vector2(col * FRAME_SIZE.x, row * FRAME_SIZE.y),
		Vector2(FRAME_SIZE)
	)

func _get_anim_fps(name: String) -> float:
	match name:
		"idle":
			return 3.0
		"start_run", "hard_stop", "jump_crouch", "takeoff", "land":
			return 14.0
		"run":
			return 13.0
		"slide":
			return 10.0
		"hurt", "victory":
			return 6.0
		_:
			return 8.0
