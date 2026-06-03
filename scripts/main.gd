extends Node2D

const W := 800.0
const H := 450.0
const GROUND_Y := 370.0
const TREADMILL_TEXTURE := "res://assets/treadmill_belt_ground.png"
const TREADMILL_TILE_W := 1024.0
const MENU_LOGO_TEXTURE := "res://assets/menu_logo_ui.png"
const MENU_START_BUTTON_TEXTURE := "res://assets/menu_start_button_ui.png"

const BG_PATHS := [
	"res://background/beijing final.png",
	"res://background/bg_forest_loop.png",
	"res://background/bg_volcano_loop.png",
	"res://background/bg_city_buildings_loop.png",
]
const BG_PARALLAX := 0.06
const BG_HEIGHT := 370.0
const BG_SWITCH_DISTANCE := 650.0
const BG_TRANSITION_DURATION := 2.0
const COIN_MILESTONE_STEP := 10
const COIN_MILESTONE_TEXT := "你跑不过我你信不信？"
const HELICOPTER_SHEET := "res://assets/helicopter_chase_sheet.png"
const HELICOPTER_FRAME_SIZE := Vector2i(340, 170)
const HELICOPTER_FRAME_COUNT := 4
const HELICOPTER_ANIM_FPS := 12.0
const HELICOPTER_BASE_POS := Vector2(510.0, 38.0)
const HELICOPTER_SCALE := 0.82
const BASKETBALL_TEXTURE := "res://assets/basketball_item.png"
const BASKETBALL_DROP_INITIAL_MIN_FRAMES := 600
const BASKETBALL_DROP_INITIAL_JITTER_FRAMES := 300
const BASKETBALL_DROP_MIN_FRAMES := 960
const BASKETBALL_DROP_JITTER_FRAMES := 540
const BASKETBALL_DROP_GRAVITY := 520.0
const BASKETBALL_CLEAR_DURATION := 3.0
const BASKETBALL_THROW_SPEED := 820.0
const TREADMILL_SHIELD_TEXT := "平时咱们就练起来！"
const TREADMILL_SHIELD_INITIAL_MIN_FRAMES := 900
const TREADMILL_SHIELD_INITIAL_JITTER_FRAMES := 480
const TREADMILL_SHIELD_MIN_FRAMES := 1500
const TREADMILL_SHIELD_JITTER_FRAMES := 900
const ICED_TEA_DROP_TEXT := "牢大相信你！"
const ICED_TEA_DROP_INITIAL_MIN_FRAMES := 1800
const ICED_TEA_DROP_INITIAL_JITTER_FRAMES := 900
const ICED_TEA_DROP_MIN_FRAMES := 3300
const ICED_TEA_DROP_JITTER_FRAMES := 1800
const GIANT_DURATION := 5.0
const GIANT_SCALE_MULTIPLIER := 4.0
const GIANT_END_INVINCIBLE_DURATION := 1.0
const SHIELD_RING_RADIUS := 36.0
const GIANT_COIN_PICKUP_OFFSET := Vector2(-72.0, -175.0)
const GIANT_COIN_PICKUP_SIZE := Vector2(220.0, 238.0)
const GAMEOVER_RESTART_LOCK := 0.35
const GAMEOVER_FAILURE_UI_SCALE := 0.86

enum State { MENU, PLAYING, GAMEOVER }

var state: State = State.MENU
var speed: float = 300.0
var base_speed: float = 300.0
var max_speed: float = 650.0
var score: int = 0
var coin_count: int = 0
var distance: float = 0.0
var frame_count: int = 0

var shake_timer: float = 0.0
var shake_intensity: float = 0.0

@onready var player: CharacterBody2D = $Player
@onready var obstacle_container: Node2D = $Obstacles
@onready var coin_container: Node2D = $Coins
@onready var particle_container: Node2D = $Particles
@onready var treadmill_a: Sprite2D = $Ground/BeltA
@onready var treadmill_b: Sprite2D = $Ground/BeltB
@onready var background: Node2D = $Background
@onready var menu_ui: CanvasLayer = $MenuUI
@onready var gameover_ui: CanvasLayer = $GameOverUI
@onready var score_label: Label = $HUD/ScoreLabel
@onready var coin_label: Label = $HUD/CoinLabel
@onready var hud: CanvasLayer = $HUD
@onready var final_score_label: Label = $GameOverUI/GameOverPanel/VBoxContainer/FinalScore
@onready var distance_value_label: Label = $GameOverUI/GameOverPanel/VBoxContainer/StatsContainer/DistanceStat/DistanceValue
@onready var coin_value_label: Label = $GameOverUI/GameOverPanel/VBoxContainer/StatsContainer/CoinStat/CoinValue

@onready var bgm_player: AudioStreamPlayer = $AudioPlayers/BGM

var obstacle_scenes: Dictionary = {}
var coin_scene: PackedScene
var audio_players: Array[AudioStreamPlayer] = []
var bg_layers: Array = []
var bg_layer_widths: Array[float] = []
var bg_textures: Array[Texture2D] = []
var particles: Array[ColorRect] = []
var next_coin_spawn_frame: int = 130
var coin_pattern_index: int = 0
var _sfx_round: int = 0
var helicopter_sprite: Sprite2D = null
var _helicopter_time: float = 0.0
var next_basketball_spawn_frame: int = 720
var basketball_clear_timer: float = 0.0
var basketball_projectiles: Array[Sprite2D] = []
var next_treadmill_item_spawn_frame: int = 1200
var shield_charges: int = 0
var shield_visual: Node2D = null
var _shield_time: float = 0.0
var next_iced_tea_spawn_frame: int = 2400
var giant_timer: float = 0.0
var post_giant_invincible_timer: float = 0.0
var _giant_active: bool = false
var _bg_current_index: int = 0
var _bg_next_index: int = -1
var _bg_active_layer: int = 0
var _bg_transition_time: float = 0.0
var _bg_next_switch_distance: float = BG_SWITCH_DISTANCE
var _bg_is_transitioning: bool = false
var gameover_distance_display: Label = null
var gameover_coin_display: Label = null
var gameover_input_lock_timer: float = 0.0

func _ready() -> void:
	randomize()
	obstacle_scenes = {
		"rock_small": load("res://scenes/obstacle_rock_small.tscn"),
		"rock_tall": load("res://scenes/obstacle_rock_tall.tscn"),
		"crate": load("res://scenes/obstacle_crate.tscn"),
		"bird": load("res://scenes/obstacle_bird.tscn"),
	}
	coin_scene = load("res://scenes/coin.tscn")

	_init_background()
	_init_helicopter()
	_init_treadmill()
	_init_audio()
	_init_bgm()
	_init_shield_visual()
	_init_gameover_style_v2()
	_init_hud_score_panel()
	_init_start_menu_style()
	_update_hud()

	var start_btn: Button = menu_ui.get_node("MenuPanel/VBoxContainer/StartButton")
	start_btn.pressed.connect(_on_menu_start_pressed)

	var restart_btn: Button = gameover_ui.get_node("GameOverPanel/VBoxContainer/RestartButton")
	restart_btn.pressed.connect(_on_gameover_restart_pressed)

	player.died.connect(_on_player_died)
	show_menu()

func _process(delta: float) -> void:
	_update_helicopter(delta)
	_update_shield_visual(delta)
	if gameover_input_lock_timer > 0.0:
		gameover_input_lock_timer = maxf(0.0, gameover_input_lock_timer - delta)

	if state != State.PLAYING:
		return

	frame_count += 1

	speed = base_speed + floor(distance / 500.0) * 20.0
	speed = min(speed, max_speed)

	distance += speed * delta * 0.1
	score = int(distance) + coin_count * 10

	if shake_timer > 0:
		shake_timer -= delta
	if shake_timer <= 0:
		shake_intensity = lerp(shake_intensity, 0.0, delta * 8.0)

	if shake_intensity > 0.3:
		position = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
	else:
		position = Vector2.ZERO

	_move_obstacles(delta)
	_move_coins(delta)
	_check_coin_collection()
	_update_basketball_power(delta)
	_update_basketball_projectiles(delta)
	_update_giant_power(delta)
	_check_obstacle_collision()
	if state != State.PLAYING:
		return

	_update_obstacle_spawning()
	_update_coin_spawning()
	_update_basketball_spawning()
	_update_treadmill_item_spawning()
	_update_iced_tea_spawning()
	_update_background(delta)
	_update_treadmill(delta)
	_update_particles(delta)
	_update_hud()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump"):
		_handle_press()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_press()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_press()
	elif event is InputEventKey and event.pressed and not event.echo and _can_restart_gameover():
		start_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("slide") and state == State.PLAYING:
		player.slide()
		player.set_crouch_pressed(true)
	elif event.is_action_pressed("crouch") and state == State.PLAYING:
		player.set_crouch_pressed(true)
	elif event.is_action_released("crouch") and state == State.PLAYING:
		player.set_crouch_pressed(false)

func _handle_press() -> void:
	match state:
		State.MENU:
			start_game()
		State.GAMEOVER:
			if _can_restart_gameover():
				start_game()
		State.PLAYING:
			player.jump()

func _can_restart_gameover() -> bool:
	return state == State.GAMEOVER and gameover_input_lock_timer <= 0.0

func start_game() -> void:
	gameover_input_lock_timer = 0.0
	state = State.PLAYING
	reset_game()
	menu_ui.hide()
	gameover_ui.hide()
	score_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	coin_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	player.start_running()
	bgm_player.play()
	_update_hud()

func game_over() -> void:
	if state == State.GAMEOVER:
		return

	state = State.GAMEOVER
	gameover_input_lock_timer = GAMEOVER_RESTART_LOCK
	bgm_player.stop()
	shake_timer = 0.35
	shake_intensity = 6.0
	spawn_particles(player.position + Vector2(20, 28), 25, Color(0.906, 0.298, 0.235), 5.0)
	spawn_particles(player.position + Vector2(20, 28), 15, Color(0.996, 0.792, 0.341), 3.0)
	play_sound("dead")
	show_gameover()

func reset_game() -> void:
	score = 0
	coin_count = 0
	distance = 0.0
	speed = base_speed
	frame_count = 0
	next_coin_spawn_frame = 130
	coin_pattern_index = 0
	basketball_clear_timer = 0.0
	next_treadmill_item_spawn_frame = 1200
	shield_charges = 0
	_shield_time = 0.0
	next_iced_tea_spawn_frame = 2400
	giant_timer = 0.0
	post_giant_invincible_timer = 0.0
	_giant_active = false
	shake_timer = 0.0
	shake_intensity = 0.0
	position = Vector2.ZERO
	_reset_background_cycle()

	for child in obstacle_container.get_children():
		var collision_object := child as CollisionObject2D
		if collision_object:
			collision_object.collision_layer = 0
			collision_object.collision_mask = 0
		if child.is_in_group("obstacle"):
			child.remove_from_group("obstacle")
		child.queue_free()
	for child in coin_container.get_children():
		child.queue_free()
	for p in particles:
		if is_instance_valid(p):
			p.queue_free()
	particles.clear()
	for projectile in basketball_projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	basketball_projectiles.clear()

	stop_all_sfx()
	player.reset()
	_spawn_initial_coin_patterns()
	_schedule_next_basketball_drop(true)
	_schedule_next_treadmill_item(true)
	_schedule_next_iced_tea_drop(true)
	_update_shield_visual(0.0)

func _on_player_died() -> void:
	game_over()

func _move_obstacles(delta: float) -> void:
	for obs in obstacle_container.get_children():
		obs.position.x -= speed * delta
		if obs.position.x < -100:
			obs.queue_free()

func _update_obstacle_spawning() -> void:
	if basketball_clear_timer > 0.0:
		return

	var children := obstacle_container.get_children()
	var min_gap: float = max(90.0, 200.0 - speed * 0.13)
	var can_spawn := true
	if not children.is_empty():
		var last_obstacle: Node2D = children[children.size() - 1]
		can_spawn = last_obstacle.position.x < W - min_gap

	if can_spawn and randf() < 0.014 + speed * 0.000025:
		_spawn_obstacle()

func _spawn_obstacle() -> void:
	var r := randf()
	var type: String
	if r < 0.35:
		type = "rock_small"
	elif r < 0.60:
		type = "rock_tall"
	elif r < 0.85:
		type = "crate"
	else:
		type = "bird"

	if not obstacle_scenes.has(type):
		return

	var obs: StaticBody2D = obstacle_scenes[type].instantiate()
	obs.position.x = W + 50
	obs.set("obstacle_type", type)

	match type:
		"rock_small":
			obs.position.y = GROUND_Y - 44
		"rock_tall":
			obs.position.y = GROUND_Y - 56
		"crate":
			obs.position.y = GROUND_Y - 42
		"bird":
			obs.position.y = 60

	obs.add_to_group("obstacle")
	obstacle_container.add_child(obs)

func _check_obstacle_collision() -> void:
	var player_rect: Rect2 = _get_player_obstacle_rect()
	for obs in obstacle_container.get_children():
		if not is_instance_valid(obs) or obs.is_queued_for_deletion():
			continue

		var obs_rect := _get_obstacle_rect(obs)
		if player_rect.intersects(obs_rect):
			if handle_player_obstacle_contact(obs):
				if is_player_invincible():
					continue
				return
			player.die()
			return

func _get_player_obstacle_rect() -> Rect2:
	if giant_timer > 0.0:
		return Rect2(player.position + Vector2(-100.0, -180.0), Vector2(250.0, 236.0))
	return player.get_hit_rect()

func _get_obstacle_rect(obs: Node2D) -> Rect2:
	if str(obs.get("obstacle_type")) == "bird":
		return Rect2(obs.position + Vector2(11, 10), Vector2(24, 250))
	var shape_node := obs.get_node_or_null("CollisionShape2D")
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape := shape_node.shape as RectangleShape2D
		var half := rect_shape.size * 0.5
		return Rect2(obs.position + shape_node.position - half, rect_shape.size)
	return Rect2(obs.position, _get_obstacle_size(obs)).grow(-3)

func _get_obstacle_size(obs: Node2D) -> Vector2:
	match str(obs.get("obstacle_type")):
		"rock_small":
			return Vector2(36, 44)
		"rock_tall":
			return Vector2(36, 56)
		"crate":
			return Vector2(48, 42)
		"bird":
			return Vector2(46, 40)
		_:
			return Vector2(36, 36)

func _move_coins(delta: float) -> void:
	for coin in coin_container.get_children():
		if coin.get_meta("helicopter_drop", false):
			coin.position.x -= speed * 0.55 * delta
			var target_y := float(coin.get_meta("target_y", GROUND_Y - 60.0))
			if coin.position.y < target_y:
				var drop_vy := float(coin.get_meta("drop_vy", 0.0)) + BASKETBALL_DROP_GRAVITY * delta
				coin.position.y = minf(target_y, coin.position.y + drop_vy * delta)
				coin.set_meta("drop_vy", drop_vy)
		else:
			coin.position.x -= speed * delta
		if coin.position.x < -50:
			coin.queue_free()

func _update_coin_spawning() -> void:
	if frame_count < next_coin_spawn_frame:
		return

	var pattern := coin_pattern_index % 4
	var start_x := W + 130.0
	match pattern:
		0:
			_spawn_coin_line(start_x, GROUND_Y - 46.0, 3, 76.0)
		1:
			_spawn_coin_arc(start_x, GROUND_Y - 82.0)
		2:
			_spawn_coin_stairs(start_x, GROUND_Y - 58.0)
		_:
			_spawn_coin_line(start_x, GROUND_Y - 118.0, 2, 82.0)

	coin_pattern_index += 1
	next_coin_spawn_frame = frame_count + 150 + randi() % 80

func _update_basketball_spawning() -> void:
	if frame_count < next_basketball_spawn_frame:
		return

	if _has_live_basketball_drop() or _has_live_iced_tea_drop():
		_schedule_next_basketball_drop(false)
		return

	_spawn_basketball_drop()
	_schedule_next_basketball_drop(false)

func _has_live_basketball_drop() -> bool:
	for coin in coin_container.get_children():
		if is_instance_valid(coin) and not coin.is_queued_for_deletion() and str(coin.get("coin_type")) == "basketball":
			return true
	return false

func _has_live_iced_tea_drop() -> bool:
	for coin in coin_container.get_children():
		if is_instance_valid(coin) and not coin.is_queued_for_deletion() and str(coin.get("coin_type")) == "iced_tea":
			return true
	return false

func _schedule_next_basketball_drop(initial: bool) -> void:
	if initial:
		next_basketball_spawn_frame = frame_count + BASKETBALL_DROP_INITIAL_MIN_FRAMES + randi() % BASKETBALL_DROP_INITIAL_JITTER_FRAMES
	else:
		next_basketball_spawn_frame = frame_count + BASKETBALL_DROP_MIN_FRAMES + randi() % BASKETBALL_DROP_JITTER_FRAMES

func _spawn_basketball_drop() -> void:
	var ball: Area2D = coin_scene.instantiate()
	ball.position = _get_basketball_drop_position()
	ball.z_index = 8
	ball.set_meta("helicopter_drop", true)
	ball.set_meta("drop_vy", 10.0)
	ball.set_meta("target_y", GROUND_Y - 60.0)
	if ball.has_method("init"):
		ball.init("basketball")
	coin_container.add_child(ball)

func _update_treadmill_item_spawning() -> void:
	if frame_count < next_treadmill_item_spawn_frame:
		return

	if shield_charges > 0 or _has_live_treadmill_item():
		_schedule_next_treadmill_item(false)
		return

	_spawn_treadmill_item()
	_schedule_next_treadmill_item(false)

func _has_live_treadmill_item() -> bool:
	for coin in coin_container.get_children():
		if is_instance_valid(coin) and not coin.is_queued_for_deletion() and str(coin.get("coin_type")) == "treadmill":
			return true
	return false

func _schedule_next_treadmill_item(initial: bool) -> void:
	if initial:
		next_treadmill_item_spawn_frame = frame_count + TREADMILL_SHIELD_INITIAL_MIN_FRAMES + randi() % TREADMILL_SHIELD_INITIAL_JITTER_FRAMES
	else:
		next_treadmill_item_spawn_frame = frame_count + TREADMILL_SHIELD_MIN_FRAMES + randi() % TREADMILL_SHIELD_JITTER_FRAMES

func _spawn_treadmill_item() -> void:
	var item: Area2D = coin_scene.instantiate()
	var spawn_x := W + 160.0
	for coin in coin_container.get_children():
		if is_instance_valid(coin) and not coin.is_queued_for_deletion() and coin.position.x > W - 40.0:
			spawn_x = maxf(spawn_x, coin.position.x + 130.0)
	item.position = Vector2(spawn_x, GROUND_Y - randf_range(58.0, 88.0))
	item.z_index = 7
	if item.has_method("init"):
		item.init("treadmill")
	coin_container.add_child(item)

func _update_iced_tea_spawning() -> void:
	if frame_count < next_iced_tea_spawn_frame:
		return

	if giant_timer > 0.0 or post_giant_invincible_timer > 0.0 or _has_live_iced_tea_drop() or _has_live_basketball_drop():
		_schedule_next_iced_tea_drop(false)
		return

	_spawn_iced_tea_drop()
	_schedule_next_iced_tea_drop(false)

func _schedule_next_iced_tea_drop(initial: bool) -> void:
	if initial:
		next_iced_tea_spawn_frame = frame_count + ICED_TEA_DROP_INITIAL_MIN_FRAMES + randi() % ICED_TEA_DROP_INITIAL_JITTER_FRAMES
	else:
		next_iced_tea_spawn_frame = frame_count + ICED_TEA_DROP_MIN_FRAMES + randi() % ICED_TEA_DROP_JITTER_FRAMES

func _spawn_iced_tea_drop() -> void:
	var tea: Area2D = coin_scene.instantiate()
	tea.position = _get_basketball_drop_position() + Vector2(-12.0, 4.0)
	tea.z_index = 8
	tea.set_meta("helicopter_drop", true)
	tea.set_meta("drop_vy", 0.0)
	tea.set_meta("target_y", GROUND_Y - 74.0)
	if tea.has_method("init"):
		tea.init("iced_tea")
	coin_container.add_child(tea)
	_show_helicopter_drop_text(ICED_TEA_DROP_TEXT)

func _get_basketball_drop_position() -> Vector2:
	if helicopter_sprite:
		return helicopter_sprite.position + Vector2(
			float(HELICOPTER_FRAME_SIZE.x) * HELICOPTER_SCALE * 0.62,
			float(HELICOPTER_FRAME_SIZE.y) * HELICOPTER_SCALE * 0.74
		)
	return HELICOPTER_BASE_POS + Vector2(170.0, 105.0)

func _spawn_initial_coin_patterns() -> void:
	_spawn_coin_line(500.0, GROUND_Y - 48.0, 2, 92.0)
	_spawn_coin(690.0, GROUND_Y - 96.0)

func _spawn_coin_line(start_x: float, y: float, count: int, spacing: float) -> void:
	for i in range(count):
		_spawn_coin(start_x + float(i) * spacing, y)

func _spawn_coin_arc(start_x: float, base_y: float) -> void:
	var offsets := [14.0, -18.0, 14.0]
	for i in range(offsets.size()):
		_spawn_coin(start_x + float(i) * 70.0, base_y + offsets[i])

func _spawn_coin_stairs(start_x: float, base_y: float) -> void:
	for i in range(3):
		_spawn_coin(start_x + float(i) * 74.0, base_y - float(i) * 18.0)

func _spawn_coin(x: float, y: float) -> void:
	var coin: Area2D = coin_scene.instantiate()
	coin.position = Vector2(x, y)
	coin.z_index = 6
	var ctype := "qiaolezi" if randf() < 0.5 else "xuebi"
	if coin.has_method("init"):
		coin.init(ctype)
	coin_container.add_child(coin)

func _check_coin_collection() -> void:
	for coin in coin_container.get_children():
		if not is_instance_valid(coin):
			continue

		var player_rect := _get_player_coin_pickup_rect(coin)
		var coin_rect: Rect2 = coin.get_pickup_rect() if coin.has_method("get_pickup_rect") else Rect2(coin.position - Vector2(18, 18), Vector2(36, 36))
		if player_rect.intersects(coin_rect):
			if coin.has_method("collect"):
				coin.collect()

func _get_player_coin_pickup_rect(coin: Node) -> Rect2:
	var normal_rect: Rect2 = player.get_hit_rect() if player.has_method("get_hit_rect") else Rect2(player.position + Vector2(4, 4), Vector2(32, 48))
	if giant_timer <= 0.0:
		return normal_rect

	var ctype := str(coin.get("coin_type"))
	if ctype == "qiaolezi" or ctype == "xuebi":
		return Rect2(player.position + GIANT_COIN_PICKUP_OFFSET, GIANT_COIN_PICKUP_SIZE)
	return normal_rect

func collect_coin(coin_type: String, pos: Vector2) -> void:
	coin_count += 1
	var col := Color(1.0, 0.596, 0.0)
	match coin_type:
		"basketball":
			col = Color(1.0, 0.45, 0.05)
		"iced_tea":
			col = Color(1.0, 0.62, 0.08)
		"treadmill":
			col = Color(0.25, 0.85, 0.95)
		"xuebi":
			col = Color(0.298, 0.686, 0.314)
	spawn_particles(pos, 8, col, 2.0)
	if coin_type == "basketball":
		_activate_basketball_power(pos)
		play_sound("basketball")
	elif coin_type == "treadmill":
		_activate_shield(pos)
		play_sound("shield")
	elif coin_type == "iced_tea":
		_activate_giant_power(pos)
		play_sound("giant")
	else:
		play_sound("coin")
	if coin_count > 0 and coin_count % COIN_MILESTONE_STEP == 0:
		_show_milestone_text()

func _activate_basketball_power(pos: Vector2) -> void:
	basketball_clear_timer = BASKETBALL_CLEAR_DURATION
	if player and player.has_method("shoot_basketball"):
		player.shoot_basketball()
	_spawn_basketball_projectile(player.position + Vector2(48.0, 23.0))
	_clear_forward_obstacles()
	spawn_particles(pos, 18, Color(1.0, 0.55, 0.08), 5.0)

func _update_basketball_power(delta: float) -> void:
	if basketball_clear_timer <= 0.0:
		return

	basketball_clear_timer = maxf(0.0, basketball_clear_timer - delta)
	_clear_forward_obstacles()

func _activate_shield(pos: Vector2) -> void:
	shield_charges = 1
	_shield_time = 0.0
	_update_shield_visual(0.0)
	_show_player_float_text(TREADMILL_SHIELD_TEXT)
	spawn_particles(pos, 18, Color(0.25, 0.85, 0.95), 4.2)
	spawn_particles(player.position + Vector2(20.0, 24.0), 16, Color(0.42, 0.95, 1.0), 5.0)

func _activate_giant_power(pos: Vector2) -> void:
	giant_timer = GIANT_DURATION
	post_giant_invincible_timer = 0.0
	_giant_active = true
	if player and player.has_method("set_power_scale"):
		player.set_power_scale(GIANT_SCALE_MULTIPLIER)
	shake_timer = maxf(shake_timer, 0.2)
	shake_intensity = maxf(shake_intensity, 2.6)
	spawn_particles(pos, 22, Color(1.0, 0.62, 0.08), 5.0)
	spawn_particles(player.position + Vector2(20.0, 24.0), 28, Color(1.0, 0.72, 0.12), 8.0)

func _update_giant_power(delta: float) -> void:
	if giant_timer > 0.0:
		giant_timer = maxf(0.0, giant_timer - delta)
		if giant_timer <= 0.0 and _giant_active:
			_end_giant_power()
			return

	if post_giant_invincible_timer > 0.0:
		post_giant_invincible_timer = maxf(0.0, post_giant_invincible_timer - delta)

func _end_giant_power() -> void:
	_giant_active = false
	post_giant_invincible_timer = GIANT_END_INVINCIBLE_DURATION
	if player and player.has_method("set_power_scale"):
		player.set_power_scale(1.0)
	shake_timer = maxf(shake_timer, 0.26)
	shake_intensity = maxf(shake_intensity, 5.0)
	_clear_nearby_obstacles()
	spawn_particles(player.position + Vector2(20.0, 24.0), 34, Color(1.0, 0.7, 0.12), 9.0)
	play_sound("giant_end")

func is_player_invincible() -> bool:
	return giant_timer > 0.0 or post_giant_invincible_timer > 0.0

func handle_player_obstacle_contact(source: Node = null) -> bool:
	if giant_timer > 0.0:
		_smash_obstacle(source, Color(1.0, 0.62, 0.08), 7.0)
		return true

	if post_giant_invincible_timer > 0.0:
		return true

	if try_consume_shield(source):
		return true

	return false

func try_consume_shield(source: Node = null) -> bool:
	if shield_charges <= 0:
		return false

	shield_charges -= 1
	_update_shield_visual(0.0)
	shake_timer = maxf(shake_timer, 0.18)
	shake_intensity = maxf(shake_intensity, 3.5)
	spawn_particles(player.position + Vector2(20.0, 24.0), 26, Color(0.35, 0.9, 1.0), 7.0)
	play_sound("shield_break")

	if source and is_instance_valid(source) and not source.is_queued_for_deletion():
		var source_node := source as Node2D
		if source_node:
			spawn_particles(source_node.position + Vector2(18.0, 18.0), 14, Color(0.42, 0.95, 1.0), 5.0)
		source.queue_free()
	return true

func _smash_obstacle(source: Node, color: Color, spread: float = 5.0) -> void:
	if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
		return
	var source_node := source as Node2D
	if source_node:
		spawn_particles(source_node.position + Vector2(20.0, 18.0), 18, color, spread)
	source.queue_free()

func _clear_nearby_obstacles() -> void:
	for obs in obstacle_container.get_children():
		if not is_instance_valid(obs) or obs.is_queued_for_deletion():
			continue
		var obs_node := obs as Node2D
		if obs_node == null:
			continue
		var dx := obs_node.position.x - player.position.x
		if dx > -110.0 and dx < 330.0:
			_smash_obstacle(obs, Color(1.0, 0.66, 0.1), 8.0)

func _clear_forward_obstacles() -> void:
	for obs in obstacle_container.get_children():
		if not is_instance_valid(obs) or obs.is_queued_for_deletion():
			continue
		if obs.position.x >= player.position.x - 12.0:
			spawn_particles(obs.position + Vector2(20.0, 18.0), 10, Color(1.0, 0.48, 0.05), 4.0)
			obs.queue_free()

func _spawn_basketball_projectile(pos: Vector2) -> void:
	var tex := _load_texture(BASKETBALL_TEXTURE)
	if tex == null:
		return

	var projectile := Sprite2D.new()
	projectile.name = "BasketballProjectile"
	projectile.texture = tex
	projectile.centered = true
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_index = 12
	projectile.position = pos
	projectile.scale = Vector2(0.42, 0.42)
	projectile.set_meta("age", 0.0)
	projectile.set_meta("base_y", pos.y)
	particle_container.add_child(projectile)
	basketball_projectiles.append(projectile)

func _update_basketball_projectiles(delta: float) -> void:
	var to_remove: Array[Sprite2D] = []
	for projectile in basketball_projectiles:
		if not is_instance_valid(projectile):
			to_remove.append(projectile)
			continue

		var age := float(projectile.get_meta("age", 0.0)) + delta
		projectile.set_meta("age", age)
		projectile.position.x += BASKETBALL_THROW_SPEED * delta
		var base_y := float(projectile.get_meta("base_y", projectile.position.y))
		projectile.position.y = base_y - sin(minf(age * 3.6, PI)) * 46.0 + age * 10.0
		projectile.rotation += delta * 13.0
		if projectile.position.x > W + 80.0 or age > 1.4:
			projectile.queue_free()
			to_remove.append(projectile)

	for projectile in to_remove:
		basketball_projectiles.erase(projectile)

func spawn_particles(pos: Vector2, count: int, color: Color, spread: float = 3.0) -> void:
	for i in range(count):
		var p := ColorRect.new()
		p.size = Vector2(3, 3)
		p.color = color
		p.position = pos + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		particle_container.add_child(p)
		particles.append(p)

		p.set_meta("particle_data", {
			"vx": randf_range(-spread * 2, spread * 2),
			"vy": randf_range(-spread * 2, spread * 2) - 4.0,
			"life": 0.5 + randf() * 0.3,
			"age": 0.0,
		})

func _update_particles(delta: float) -> void:
	var to_remove: Array[ColorRect] = []
	for p in particles:
		if not is_instance_valid(p):
			to_remove.append(p)
			continue

		var data = p.get_meta("particle_data", null)
		if data == null:
			to_remove.append(p)
			continue

		var age: float = data["age"] + delta
		var vy: float = data["vy"]
		p.position.x += float(data["vx"])
		p.position.y += vy
		vy += 80.0 * delta
		data["age"] = age
		data["vy"] = vy
		p.modulate.a = clampf(1.0 - age / float(data["life"]), 0.0, 1.0)

		if age >= float(data["life"]):
			p.queue_free()
			to_remove.append(p)

	for p in to_remove:
		particles.erase(p)

var _bg_scroll := 0.0

func _init_background() -> void:
	bg_textures.clear()
	for path in BG_PATHS:
		bg_textures.append(_load_texture(path))

	bg_layers.clear()
	bg_layer_widths.clear()
	for layer_i in range(2):
		var layer_sprites: Array[Sprite2D] = []
		for i in range(3):
			var sprite := Sprite2D.new()
			sprite.centered = false
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.z_index = 0
			sprite.position.y = 0
			sprite.modulate.a = 0.0
			background.add_child(sprite)
			layer_sprites.append(sprite)
		bg_layers.append(layer_sprites)
		bg_layer_widths.append(0.0)

	_reset_background_cycle()

func _init_helicopter() -> void:
	var tex := _load_texture(HELICOPTER_SHEET)
	if tex == null:
		return

	helicopter_sprite = Sprite2D.new()
	helicopter_sprite.name = "ChaseHelicopter"
	helicopter_sprite.texture = tex
	helicopter_sprite.region_enabled = true
	helicopter_sprite.centered = false
	helicopter_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	helicopter_sprite.z_index = 4
	helicopter_sprite.scale = Vector2(HELICOPTER_SCALE, HELICOPTER_SCALE)
	add_child(helicopter_sprite)
	_update_helicopter_frame(0)
	_update_helicopter(0.0)

func _reset_background_cycle() -> void:
	if bg_layers.is_empty() or bg_textures.is_empty():
		return

	_bg_current_index = 0
	_bg_next_index = -1
	_bg_active_layer = 0
	_bg_transition_time = 0.0
	_bg_next_switch_distance = BG_SWITCH_DISTANCE
	_bg_is_transitioning = false
	_bg_scroll = 0.0

	_set_background_layer(0, _bg_current_index, 1.0)
	var standby_index := 1 if bg_textures.size() > 1 else 0
	_set_background_layer(1, standby_index, 0.0)
	_reposition_background_layers()

func _set_background_layer(layer_idx: int, bg_idx: int, alpha: float) -> void:
	if layer_idx < 0 or layer_idx >= bg_layers.size() or bg_idx < 0 or bg_idx >= bg_textures.size():
		return

	var tex := bg_textures[bg_idx]
	if tex == null:
		return

	var scale_y := BG_HEIGHT / float(tex.get_height())
	bg_layer_widths[layer_idx] = float(tex.get_width()) * scale_y
	for sprite in bg_layers[layer_idx]:
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale = Vector2(scale_y, scale_y)
		sprite.position.y = 0.0
		sprite.modulate.a = alpha

func _set_background_layer_alpha(layer_idx: int, alpha: float) -> void:
	if layer_idx < 0 or layer_idx >= bg_layers.size():
		return
	for sprite in bg_layers[layer_idx]:
		sprite.modulate.a = alpha

func _reposition_background_layers() -> void:
	for layer_idx in range(bg_layers.size()):
		_reposition_background_layer(layer_idx)

func _reposition_background_layer(layer_idx: int) -> void:
	if layer_idx < 0 or layer_idx >= bg_layers.size():
		return

	var width := bg_layer_widths[layer_idx]
	if width <= 0.0:
		return

	var x := -fmod(_bg_scroll, width)
	for sprite in bg_layers[layer_idx]:
		sprite.position.x = x
		x += width

func _start_background_transition() -> void:
	if bg_textures.size() <= 1 or _bg_is_transitioning:
		return

	_bg_next_index = (_bg_current_index + 1) % bg_textures.size()
	var next_layer := 1 - _bg_active_layer
	_set_background_layer(next_layer, _bg_next_index, 0.0)
	_reposition_background_layer(next_layer)
	_bg_transition_time = 0.0
	_bg_is_transitioning = true

func _finish_background_transition() -> void:
	var old_layer := _bg_active_layer
	_bg_active_layer = 1 - _bg_active_layer
	_bg_current_index = _bg_next_index
	_bg_next_index = -1
	_bg_transition_time = 0.0
	_bg_is_transitioning = false
	_bg_next_switch_distance += BG_SWITCH_DISTANCE
	_set_background_layer_alpha(_bg_active_layer, 1.0)
	_set_background_layer_alpha(old_layer, 0.0)

func _update_helicopter(delta: float) -> void:
	if helicopter_sprite == null:
		return

	_helicopter_time += delta
	var frame := int(_helicopter_time * HELICOPTER_ANIM_FPS) % HELICOPTER_FRAME_COUNT
	_update_helicopter_frame(frame)

	var chase_x := sin(_helicopter_time * 1.55) * 10.0
	var chase_y := sin(_helicopter_time * 2.35) * 6.0
	helicopter_sprite.position = HELICOPTER_BASE_POS + Vector2(chase_x, chase_y)
	helicopter_sprite.rotation = sin(_helicopter_time * 2.0) * 0.025

func _update_helicopter_frame(frame: int) -> void:
	if helicopter_sprite == null:
		return

	helicopter_sprite.region_rect = Rect2(
		Vector2(float(frame * HELICOPTER_FRAME_SIZE.x), 0.0),
		Vector2(float(HELICOPTER_FRAME_SIZE.x), float(HELICOPTER_FRAME_SIZE.y))
	)

func _update_background(delta: float) -> void:
	if bg_layers.is_empty():
		return

	_bg_scroll += speed * BG_PARALLAX * delta
	var active_width := bg_layer_widths[_bg_active_layer] if _bg_active_layer < bg_layer_widths.size() else 0.0
	if active_width > 0.0:
		_bg_scroll = fmod(_bg_scroll, active_width)

	if not _bg_is_transitioning and distance >= _bg_next_switch_distance:
		_start_background_transition()

	if _bg_is_transitioning:
		_bg_transition_time += delta
		var t := clampf(_bg_transition_time / BG_TRANSITION_DURATION, 0.0, 1.0)
		var smooth := t * t * (3.0 - 2.0 * t)
		var next_layer := 1 - _bg_active_layer
		_set_background_layer_alpha(_bg_active_layer, 1.0 - smooth)
		_set_background_layer_alpha(next_layer, smooth)
		if t >= 1.0:
			_finish_background_transition()

	_reposition_background_layers()

func _init_treadmill() -> void:
	var tex := _load_texture(TREADMILL_TEXTURE)
	for belt in [treadmill_a, treadmill_b]:
		belt.texture = tex
		belt.centered = false
		belt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		belt.z_index = 1
	treadmill_a.position = Vector2.ZERO
	treadmill_b.position = Vector2(TREADMILL_TILE_W, 0.0)

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	var image := Image.new()
	if image.load(path) != OK:
		return null
	return ImageTexture.create_from_image(image)

func _update_treadmill(delta: float) -> void:
	if treadmill_a.texture == null:
		return

	var scroll_speed := speed * 0.75
	treadmill_a.position.x -= scroll_speed * delta
	treadmill_b.position.x -= scroll_speed * delta

	if treadmill_a.position.x <= -TREADMILL_TILE_W:
		treadmill_a.position.x = treadmill_b.position.x + TREADMILL_TILE_W
	if treadmill_b.position.x <= -TREADMILL_TILE_W:
		treadmill_b.position.x = treadmill_a.position.x + TREADMILL_TILE_W

func _init_shield_visual() -> void:
	shield_visual = Node2D.new()
	shield_visual.name = "ShieldAura"
	shield_visual.position = Vector2(20.0, 28.0)
	shield_visual.z_index = 18
	shield_visual.visible = false
	player.add_child(shield_visual)

	var ring := Line2D.new()
	ring.name = "Ring"
	ring.width = 3.0
	ring.default_color = Color(0.32, 0.88, 1.0, 0.72)
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var points := PackedVector2Array()
	for i in range(36):
		var t := TAU * float(i) / 36.0
		points.append(Vector2(cos(t) * SHIELD_RING_RADIUS, sin(t) * SHIELD_RING_RADIUS))
	points.append(points[0])
	ring.points = points
	shield_visual.add_child(ring)

	var badge_outline := Polygon2D.new()
	badge_outline.name = "BadgeOutline"
	badge_outline.position = Vector2(33.0, -31.0)
	badge_outline.scale = Vector2(1.18, 1.18)
	badge_outline.color = Color(0.02, 0.06, 0.08, 0.92)
	badge_outline.polygon = PackedVector2Array([
		Vector2(0.0, -12.0), Vector2(11.0, -7.0), Vector2(8.0, 8.0),
		Vector2(0.0, 15.0), Vector2(-8.0, 8.0), Vector2(-11.0, -7.0)
	])
	shield_visual.add_child(badge_outline)

	var badge_fill := Polygon2D.new()
	badge_fill.name = "BadgeFill"
	badge_fill.position = badge_outline.position
	badge_fill.color = Color(0.35, 0.92, 1.0, 0.84)
	badge_fill.polygon = PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(8.0, -6.0), Vector2(6.0, 6.0),
		Vector2(0.0, 11.0), Vector2(-6.0, 6.0), Vector2(-8.0, -6.0)
	])
	shield_visual.add_child(badge_fill)

func _update_shield_visual(delta: float) -> void:
	if shield_visual == null:
		return

	var active := shield_charges > 0 and state == State.PLAYING
	shield_visual.visible = active
	if not active:
		return

	_shield_time += delta
	var visual_scale := 1.0
	if player and player.has_method("get_visual_multiplier"):
		visual_scale = float(player.get_visual_multiplier())
	if player and player.has_method("get_visual_center"):
		shield_visual.position = player.get_visual_center()

	var pulse := 1.0 + sin(_shield_time * 5.8) * 0.045
	shield_visual.scale = Vector2(visual_scale * pulse, visual_scale * pulse)
	shield_visual.rotation = sin(_shield_time * 1.8) * 0.035

	var ring := shield_visual.get_node_or_null("Ring") as Line2D
	if ring:
		ring.default_color = Color(0.32, 0.88, 1.0, 0.56 + sin(_shield_time * 6.4) * 0.12)
	var badge_fill := shield_visual.get_node_or_null("BadgeFill") as Polygon2D
	if badge_fill:
		badge_fill.color = Color(0.35, 0.92, 1.0, 0.75 + sin(_shield_time * 5.1) * 0.1)

func _init_audio() -> void:
	for _i in range(16):
		var asp := AudioStreamPlayer.new()
		asp.bus = "Master"
		$AudioPlayers.add_child(asp)
		audio_players.append(asp)

func _init_bgm() -> void:
	var stream := load("res://bgm_mario_style.ogg")
	if stream:
		var ogg_stream := stream as AudioStreamOggVorbis
		if ogg_stream:
			ogg_stream.loop = true
		bgm_player.stream = stream
		bgm_player.volume_db = -15.0

func play_sound(type: String) -> void:
	var asp: AudioStreamPlayer = null
	for p in audio_players:
		if not p.playing:
			asp = p
			break
	if asp == null:
		asp = audio_players[_sfx_round]
		_sfx_round = (_sfx_round + 1) % audio_players.size()
		asp.stop()

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 44100
	match type:
		"jump", "double_jump":
			stream.buffer_length = 0.12
		"coin":
			stream.buffer_length = 0.15
		"basketball":
			stream.buffer_length = 0.22
		"shield", "shield_break", "giant", "giant_end":
			stream.buffer_length = 0.2
		"dead":
			stream.buffer_length = 0.35
		_:
			stream.buffer_length = 0.1

	asp.stream = stream
	asp.play()
	var playback := asp.get_stream_playback()
	if playback == null:
		return

	match type:
		"jump":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 400.0, 600.0, "square")
		"double_jump":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 600.0, -300.0, "square")
		"coin":
			_fill_coin_tone(playback, stream.mix_rate, stream.buffer_length)
		"basketball":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 520.0, 420.0, "square")
		"shield":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 720.0, 260.0, "square")
		"shield_break":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 520.0, -330.0, "sawtooth")
		"giant":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 260.0, 520.0, "square")
		"giant_end":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 620.0, -260.0, "sawtooth")
		"dead":
			_fill_tone(playback, stream.mix_rate, stream.buffer_length, 80.0, -40.0, "sawtooth")

func stop_all_sfx() -> void:
	for p in audio_players:
		p.stop()

func _fill_tone(pb, sr: float, dur: float, freq: float, slide: float, wave_type: String) -> void:
	var samples := int(sr * dur)
	for i in range(samples):
		var t := float(i) / sr
		var f := freq + (slide * t / dur)
		var val: float
		match wave_type:
			"square":
				val = 1.0 if sin(2.0 * PI * f * t) >= 0 else -1.0
			_:
				val = 2.0 * (t * f - floor(t * f + 0.5))
		val *= 0.2 * (1.0 - t / dur)
		pb.push_frame(Vector2(val, val))

func _fill_coin_tone(pb, sr: float, dur: float) -> void:
	var samples := int(sr * dur)
	for i in range(samples):
		var t := float(i) / sr
		var f := 880.0 if t < dur * 0.4 else 1100.0
		var val := (1.0 if sin(2.0 * PI * f * t) >= 0 else -1.0) * 0.2 * (1.0 - t / dur)
		pb.push_frame(Vector2(val, val))

func _show_milestone_text() -> void:
	var label := Label.new()
	label.text = COIN_MILESTONE_TEXT
	label.size = Vector2(W, 44.0)
	label.position = Vector2(0.0, 54.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 30
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.93, 0.35))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.08))
	label.add_theme_constant_override("outline_size", 4)
	hud.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", 28.0, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.12)
	tween.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.85)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _show_player_float_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.size = Vector2(210.0, 28.0)
	label.position = player.position + Vector2(-76.0, -32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 31
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.9))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.08, 0.1))
	label.add_theme_constant_override("outline_size", 3)
	hud.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 24.0, 1.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.tween_property(label, "scale", Vector2(1.06, 1.06), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.28).set_delay(0.78)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _show_helicopter_drop_text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.size = Vector2(170.0, 28.0)
	var anchor := _get_basketball_drop_position()
	label.position = anchor + Vector2(-90.0, 12.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 32
	label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.34))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.07))
	label.add_theme_constant_override("outline_size", 3)
	hud.add_child(label)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 18.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.1)
	tween.tween_property(label, "scale", Vector2(1.06, 1.06), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.82)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)

func _make_gameover_stylebox(bg: Color, border: Color, border_width: int, radius: int = 0, margin: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	if margin > 0.0:
		style.set_content_margin(SIDE_LEFT, margin)
		style.set_content_margin(SIDE_RIGHT, margin)
		style.set_content_margin(SIDE_TOP, margin)
		style.set_content_margin(SIDE_BOTTOM, margin)
	return style

func _gameover_label(parent: Control, node_name: String) -> Label:
	var label := parent.get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		parent.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _gameover_rect(parent: Control, node_name: String) -> ColorRect:
	var rect := parent.get_node_or_null(node_name) as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = node_name
		parent.add_child(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect

func _gameover_place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

func _gameover_color_rect(parent: Control, node_name: String, left: float, top: float, right: float, bottom: float, color: Color, z: int = 0) -> ColorRect:
	var rect := _gameover_rect(parent, node_name)
	_gameover_place(rect, left, top, right, bottom)
	rect.color = color
	rect.z_index = z
	return rect

func _gameover_full_rect(parent: Control, node_name: String, left: float, top: float, right: float, bottom: float, color: Color, z: int = 0) -> ColorRect:
	var rect := _gameover_rect(parent, node_name)
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.offset_left = left
	rect.offset_top = top
	rect.offset_right = right
	rect.offset_bottom = bottom
	rect.color = color
	rect.z_index = z
	return rect

func _load_png_texture(path: String) -> Texture2D:
	var texture := load(path) as Texture2D
	if texture != null:
		return texture

	var image := Image.load_from_file(path)
	if image == null:
		push_error("Failed to load PNG texture: %s" % path)
		return null
	return ImageTexture.create_from_image(image)

func _init_hud_score_panel() -> void:
	var panel := hud.get_node_or_null("ScoreInfoPanel") as Panel
	if panel == null:
		panel = Panel.new()
		panel.name = "ScoreInfoPanel"
		hud.add_child(panel)
		hud.move_child(panel, 0)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 14.0
	panel.offset_top = 10.0
	panel.offset_right = 132.0
	panel.offset_bottom = 65.0
	panel.z_index = 25
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := _make_gameover_stylebox(
		Color(0.010, 0.055, 0.110, 0.94),
		Color(0.34, 0.78, 1.0, 1.0),
		2,
		0,
		4.0
	)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	panel_style.shadow_size = 3
	panel_style.shadow_offset = Vector2(3.0, 3.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	_init_hud_panel_decor(panel)
	_init_hud_score_row(panel, "ScoreRow", score_label, "\u5f97\u5206", true, 6.0)
	_init_hud_score_row(panel, "CoinRow", coin_label, "\u7269\u54c1", false, 30.0)

func _init_hud_panel_decor(panel: Panel) -> void:
	_gameover_full_rect(panel, "HudInnerGlow", 4.0, 4.0, -4.0, -4.0, Color(0.0, 0.25, 0.48, 0.22), 0)
	_gameover_color_rect(panel, "HudTopHighlight", 8.0, 2.0, 84.0, 4.0, Color(0.80, 0.93, 1.0, 0.74), 2)
	_gameover_color_rect(panel, "HudBottomDark", 10.0, 51.0, 101.0, 53.0, Color(0.0, 0.018, 0.050, 0.90), 2)
	_gameover_color_rect(panel, "HudCornerTL", 0.0, 0.0, 5.0, 5.0, Color(0.84, 0.96, 1.0, 1.0), 3)
	_gameover_color_rect(panel, "HudCornerTR", 113.0, 0.0, 118.0, 5.0, Color(0.84, 0.96, 1.0, 1.0), 3)
	_gameover_color_rect(panel, "HudCornerBL", 0.0, 50.0, 5.0, 55.0, Color(0.18, 0.58, 0.92, 1.0), 3)
	_gameover_color_rect(panel, "HudCornerBR", 113.0, 50.0, 118.0, 55.0, Color(0.18, 0.58, 0.92, 1.0), 3)
	for i in range(4):
		var tick_color := Color(0.0, 0.58, 0.95, 0.95) if i % 2 == 0 else Color(0.74, 0.92, 1.0, 0.95)
		_gameover_color_rect(panel, "HudSideTick%d" % i, 2.0, 12.0 + float(i) * 9.0, 5.0, 17.0 + float(i) * 9.0, tick_color, 4)

func _init_hud_score_row(panel: Panel, row_name: String, value_label: Label, title_text: String, is_score: bool, top: float) -> void:
	var row := panel.get_node_or_null(row_name) as Control
	if row == null:
		row = Control.new()
		row.name = row_name
		panel.add_child(row)
	_gameover_place(row, 7.0, top, 111.0, top + 20.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.z_index = 5

	var stripe := _gameover_rect(row, "RowStripe")
	_gameover_place(stripe, 0.0, 17.0, 96.0, 19.0)
	stripe.color = Color(0.0, 0.47, 0.74, 0.44) if is_score else Color(0.72, 0.25, 0.03, 0.48)
	stripe.z_index = 0

	var icon_wrap := row.get_node_or_null("IconWrap") as Control
	if icon_wrap == null:
		icon_wrap = Control.new()
		icon_wrap.name = "IconWrap"
		row.add_child(icon_wrap)
	_gameover_place(icon_wrap, 0.0, 0.0, 24.0, 20.0)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_init_hud_score_icon(icon_wrap, is_score)

	var title := _gameover_label(row, "Title")
	_gameover_place(title, 28.0, 0.0, 62.0, 20.0)
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1.0, 0.83, 0.10, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07, 1.0))
	title.add_theme_constant_override("outline_size", 2)
	title.z_index = 3

	if value_label.get_parent() != row:
		value_label.get_parent().remove_child(value_label)
		row.add_child(value_label)
	_gameover_place(value_label, 70.0, 0.0, 104.0, 20.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.z_index = 3
	value_label.add_theme_font_size_override("font_size", 15)
	value_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0) if is_score else Color(1.0, 0.84, 0.10, 1.0))
	value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.07, 1.0))
	value_label.add_theme_constant_override("outline_size", 2)

func _init_hud_score_icon(icon_wrap: Control, is_score: bool) -> void:
	for i in range(8):
		var part := _gameover_rect(icon_wrap, "IconPart%d" % i)
		part.z_index = 3
		if is_score:
			var gold := Color(1.0, 0.75, 0.07, 1.0)
			var gold_dark := Color(0.72, 0.25, 0.02, 1.0)
			match i:
				0:
					_gameover_place(part, 9.0, 1.0, 13.0, 18.0)
					part.color = gold
				1:
					_gameover_place(part, 2.0, 7.0, 20.0, 11.0)
					part.color = gold
				2:
					_gameover_place(part, 5.0, 3.0, 17.0, 15.0)
					part.color = gold
				3:
					_gameover_place(part, 6.0, 5.0, 16.0, 13.0)
					part.color = Color(1.0, 0.92, 0.26, 1.0)
				4:
					_gameover_place(part, 4.0, 14.0, 18.0, 17.0)
					part.color = gold_dark
				5:
					_gameover_place(part, 7.0, 0.0, 15.0, 3.0)
					part.color = Color(1.0, 0.95, 0.45, 1.0)
				6:
					_gameover_place(part, 1.0, 10.0, 6.0, 14.0)
					part.color = gold_dark
				_:
					_gameover_place(part, 16.0, 10.0, 21.0, 14.0)
					part.color = gold_dark
		else:
			match i:
				0:
					_gameover_place(part, 3.0, 8.0, 20.0, 17.0)
					part.color = Color(0.78, 0.31, 0.04, 1.0)
				1:
					_gameover_place(part, 5.0, 4.0, 18.0, 9.0)
					part.color = Color(1.0, 0.58, 0.10, 1.0)
				2:
					_gameover_place(part, 5.0, 9.0, 10.0, 16.0)
					part.color = Color(0.95, 0.44, 0.06, 1.0)
				3:
					_gameover_place(part, 11.0, 9.0, 20.0, 16.0)
					part.color = Color(0.52, 0.16, 0.025, 1.0)
				4:
					_gameover_place(part, 10.0, 5.0, 13.0, 17.0)
					part.color = Color(0.28, 0.08, 0.014, 1.0)
				5:
					_gameover_place(part, 6.0, 13.0, 18.0, 15.0)
					part.color = Color(1.0, 0.76, 0.18, 1.0)
				6:
					_gameover_place(part, 2.0, 17.0, 21.0, 19.0)
					part.color = Color(0.15, 0.045, 0.010, 1.0)
				_:
					_gameover_place(part, 4.0, 7.0, 7.0, 10.0)
					part.color = Color(1.0, 0.86, 0.25, 1.0)

func _init_start_menu_style() -> void:
	var panel := menu_ui.get_node("MenuPanel") as Panel
	var vbox := panel.get_node("VBoxContainer") as VBoxContainer

	panel.add_theme_stylebox_override("panel", _make_gameover_stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	var logo := panel.get_node_or_null("MenuLogoArt") as TextureRect
	if logo == null:
		logo = TextureRect.new()
		logo.name = "MenuLogoArt"
		panel.add_child(logo)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_SCALE
	logo.custom_minimum_size = Vector2(450.0, 267.0)
	logo.texture = _load_png_texture(MENU_LOGO_TEXTURE)
	_gameover_place(logo, 162.0, 34.0, 612.0, 301.0)
	logo.size = Vector2(450.0, 267.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.z_index = 8

	var button_art := panel.get_node_or_null("MenuStartButtonArt") as TextureRect
	if button_art == null:
		button_art = TextureRect.new()
		button_art.name = "MenuStartButtonArt"
		panel.add_child(button_art)
	button_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	button_art.stretch_mode = TextureRect.STRETCH_SCALE
	button_art.custom_minimum_size = Vector2(390.0, 112.0)
	button_art.texture = _load_png_texture(MENU_START_BUTTON_TEXTURE)
	_gameover_place(button_art, 205.0, 286.0, 595.0, 398.0)
	button_art.size = Vector2(390.0, 112.0)
	button_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_art.z_index = 9

	for node_name in ["Title", "Subtitle", "Hint"]:
		var old_label := vbox.get_node_or_null(node_name) as Control
		if old_label:
			old_label.hide()

	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.0
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.0
	vbox.offset_left = -195.0
	vbox.offset_top = 286.0
	vbox.offset_right = 195.0
	vbox.offset_bottom = 398.0
	vbox.alignment = 1
	vbox.z_index = 20
	vbox.add_theme_constant_override("separation", 0)

	var start := vbox.get_node("StartButton") as Button
	start.show()
	start.text = ""
	start.focus_mode = Control.FOCUS_NONE
	start.custom_minimum_size = Vector2(390.0, 112.0)
	var transparent := _make_gameover_stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0)
	start.add_theme_stylebox_override("normal", transparent)
	start.add_theme_stylebox_override("hover", transparent)
	start.add_theme_stylebox_override("pressed", transparent)
	start.add_theme_stylebox_override("focus", transparent)
	start.add_theme_stylebox_override("disabled", transparent)
	start.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	start.add_theme_color_override("font_hover_color", Color(1, 1, 1, 0))
	start.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 0))
	start.z_index = 21

func _init_gameover_style_v2() -> void:
	var panel := gameover_ui.get_node("GameOverPanel") as Panel
	var vbox := panel.get_node("VBoxContainer") as VBoxContainer
	panel.add_theme_stylebox_override("panel", _make_gameover_stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	var overlay := panel.get_node_or_null("PixelOverlay") as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "PixelOverlay"
		panel.add_child(overlay)
		panel.move_child(overlay, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.003, 0.012, 0.030, 0.82)
	overlay.z_index = 0

	var blue_wash := panel.get_node_or_null("FailureBlueWash") as ColorRect
	if blue_wash == null:
		blue_wash = ColorRect.new()
		blue_wash.name = "FailureBlueWash"
		panel.add_child(blue_wash)
		panel.move_child(blue_wash, 1)
	blue_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	blue_wash.offset_left = 0.0
	blue_wash.offset_top = 0.0
	blue_wash.offset_right = 0.0
	blue_wash.offset_bottom = 0.0
	blue_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blue_wash.color = Color(0.0, 0.10, 0.20, 0.18)
	blue_wash.z_index = 1

	var board := panel.get_node_or_null("PixelGameOverBoard") as Panel
	if board == null:
		board = Panel.new()
		board.name = "PixelGameOverBoard"
		panel.add_child(board)
	board.anchor_left = 0.5
	board.anchor_top = 0.5
	board.anchor_right = 0.5
	board.anchor_bottom = 0.5
	board.offset_left = -270.0
	board.offset_top = -160.0
	board.offset_right = 270.0
	board.offset_bottom = 175.0
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.z_index = 5
	board.pivot_offset = Vector2(270.0, 167.5)
	board.scale = Vector2(GAMEOVER_FAILURE_UI_SCALE, GAMEOVER_FAILURE_UI_SCALE)
	var board_style := _make_gameover_stylebox(
		Color(0.012, 0.034, 0.064, 0.98),
		Color(0.33, 0.39, 0.48, 1.0),
		7,
		0,
		18.0
	)
	board_style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	board_style.shadow_size = 8
	board_style.shadow_offset = Vector2(8.0, 9.0)
	board.add_theme_stylebox_override("panel", board_style)
	_init_gameover_board_decor_v2(board)

	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -210.0
	vbox.offset_top = -145.0
	vbox.offset_right = 210.0
	vbox.offset_bottom = 135.0
	vbox.z_index = 20
	vbox.alignment = 1
	vbox.pivot_offset = Vector2(210.0, 140.0)
	vbox.scale = Vector2(GAMEOVER_FAILURE_UI_SCALE, GAMEOVER_FAILURE_UI_SCALE)
	vbox.add_theme_constant_override("separation", 2)

	var title_stack := vbox.get_node_or_null("TitleStack") as Control
	if title_stack == null:
		title_stack = Control.new()
		title_stack.name = "TitleStack"
		vbox.add_child(title_stack)
	title_stack.custom_minimum_size = Vector2(420.0, 64.0)
	vbox.move_child(title_stack, 0)

	var title_drop := _gameover_label(title_stack, "TitleDrop")
	title_drop.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_drop.offset_left = 5.0
	title_drop.offset_top = 8.0
	title_drop.offset_right = 5.0
	title_drop.offset_bottom = 8.0
	title_drop.text = "\u6311\u6218\u5931\u8d25"
	title_drop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_drop.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_drop.add_theme_font_size_override("font_size", 52)
	title_drop.add_theme_color_override("font_color", Color(0.20, 0.020, 0.005, 0.95))
	title_drop.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title_drop.add_theme_constant_override("outline_size", 7)
	title_drop.z_index = 0

	var title_red := _gameover_label(title_stack, "TitleRedRim")
	title_red.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_red.offset_left = 1.0
	title_red.offset_top = 4.0
	title_red.offset_right = 1.0
	title_red.offset_bottom = 4.0
	title_red.text = "\u6311\u6218\u5931\u8d25"
	title_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_red.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_red.add_theme_font_size_override("font_size", 52)
	title_red.add_theme_color_override("font_color", Color(0.95, 0.20, 0.025, 1.0))
	title_red.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.01, 1.0))
	title_red.add_theme_constant_override("outline_size", 6)
	title_red.z_index = 1

	var title_main := _gameover_label(title_stack, "TitleMain")
	title_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_main.offset_left = 0.0
	title_main.offset_top = 0.0
	title_main.offset_right = 0.0
	title_main.offset_bottom = 0.0
	title_main.text = "\u6311\u6218\u5931\u8d25"
	title_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_main.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_main.add_theme_font_size_override("font_size", 52)
	title_main.add_theme_color_override("font_color", Color(1.0, 0.77, 0.10, 1.0))
	title_main.add_theme_color_override("font_outline_color", Color(0.36, 0.055, 0.012, 1.0))
	title_main.add_theme_constant_override("outline_size", 5)
	title_main.z_index = 2

	for stale_name in ["GameOverTitleShadow", "GameOverTitle", "TitleHighlight"]:
		var stale := vbox.get_node_or_null(stale_name) as Control
		if stale:
			stale.hide()

	var caption := vbox.get_node_or_null("ScoreLabel") as Label
	if caption:
		caption.show()
		caption.text = "\u26a0  \u6700\u7ec8\u5f97\u5206"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		caption.custom_minimum_size = Vector2(420.0, 24.0)
		caption.add_theme_font_size_override("font_size", 18)
		caption.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0, 1.0))
		caption.add_theme_color_override("font_outline_color", Color(0.025, 0.065, 0.10, 1.0))
		caption.add_theme_constant_override("outline_size", 2)
		vbox.move_child(caption, title_stack.get_index() + 1)

	final_score_label.custom_minimum_size = Vector2(420.0, 56.0)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 64)
	final_score_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.06, 1.0))
	final_score_label.add_theme_color_override("font_outline_color", Color(0.39, 0.13, 0.00, 1.0))
	final_score_label.add_theme_constant_override("outline_size", 5)
	if caption:
		vbox.move_child(final_score_label, caption.get_index() + 1)

	var separator := vbox.get_node_or_null("ScoreSeparatorV2") as Control
	if separator == null:
		separator = Control.new()
		separator.name = "ScoreSeparatorV2"
		vbox.add_child(separator)
	separator.custom_minimum_size = Vector2(420.0, 5.0)
	vbox.move_child(separator, final_score_label.get_index() + 1)
	for i in range(18):
		var dash := _gameover_rect(separator, "Dash%d" % i)
		_gameover_place(dash, 74.0 + float(i) * 15.0, 2.0, 83.0 + float(i) * 15.0, 5.0)
		dash.color = Color(0.94, 0.62, 0.10, 0.58)

	var old_stats := vbox.get_node_or_null("StatsContainer") as Control
	if old_stats:
		old_stats.hide()
	var styled_stats := vbox.get_node_or_null("StyledStats") as VBoxContainer
	if styled_stats == null:
		styled_stats = VBoxContainer.new()
		styled_stats.name = "StyledStats"
		vbox.add_child(styled_stats)
	styled_stats.custom_minimum_size = Vector2(370.0, 72.0)
	styled_stats.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	styled_stats.alignment = 1
	styled_stats.add_theme_constant_override("separation", 4)
	vbox.move_child(styled_stats, separator.get_index() + 1)
	gameover_distance_display = _init_gameover_stat_row_v2(styled_stats, "DistanceRow", "\u8ddd\u79bb", "0m")
	gameover_coin_display = _init_gameover_stat_row_v2(styled_stats, "CoinRow", "\u7269\u54c1", "0")

	var restart := vbox.get_node_or_null("RestartButton") as Button
	if restart:
		restart.custom_minimum_size = Vector2(370.0, 44.0)
		restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		restart.text = "\u518d\u6765\u4e00\u5c40"
		restart.focus_mode = Control.FOCUS_NONE
		restart.add_theme_font_size_override("font_size", 26)
		restart.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
		restart.add_theme_color_override("font_outline_color", Color(0.42, 0.075, 0.0, 1.0))
		restart.add_theme_constant_override("outline_size", 3)
		var normal := _make_gameover_stylebox(Color(1.0, 0.33, 0.025, 1.0), Color(1.0, 0.82, 0.16, 1.0), 4, 0, 6.0)
		normal.shadow_color = Color(0.05, 0.01, 0.0, 0.82)
		normal.shadow_size = 3
		normal.shadow_offset = Vector2(0.0, 3.0)
		var hover := _make_gameover_stylebox(Color(1.0, 0.45, 0.04, 1.0), Color(1.0, 0.96, 0.28, 1.0), 4, 0, 6.0)
		hover.shadow_color = Color(0.05, 0.01, 0.0, 0.82)
		hover.shadow_size = 3
		hover.shadow_offset = Vector2(0.0, 3.0)
		var pressed := _make_gameover_stylebox(Color(0.82, 0.18, 0.01, 1.0), Color(0.98, 0.50, 0.06, 1.0), 4, 0, 6.0)
		pressed.shadow_color = Color(0.01, 0.0, 0.0, 0.80)
		pressed.shadow_size = 2
		pressed.shadow_offset = Vector2(0.0, 2.0)
		restart.add_theme_stylebox_override("normal", normal)
		restart.add_theme_stylebox_override("hover", hover)
		restart.add_theme_stylebox_override("pressed", pressed)
		vbox.move_child(restart, styled_stats.get_index() + 1)

	var hint := vbox.get_node_or_null("GameOverHint") as Label
	if hint:
		hint.hide()

func _init_gameover_board_decor_v2(board: Panel) -> void:
	_gameover_full_rect(board, "FailureBackShadow", 12.0, 12.0, 12.0, 12.0, Color(0.0, 0.0, 0.0, 0.50), -3)
	_gameover_full_rect(board, "FailureOuterBlueGlow", -5.0, -5.0, 5.0, 5.0, Color(0.0, 0.36, 0.78, 0.16), -2)
	_gameover_full_rect(board, "FailureInnerPlate", 44.0, 48.0, -44.0, -52.0, Color(0.009, 0.029, 0.055, 0.96), -1)
	_gameover_full_rect(board, "FailureInnerTopLine", 50.0, 52.0, -50.0, -279.0, Color(0.0, 0.40, 0.70, 0.58), 0)
	_gameover_full_rect(board, "FailureInnerBottomLine", 50.0, 276.0, -50.0, -56.0, Color(0.0, 0.40, 0.70, 0.48), 0)
	_gameover_full_rect(board, "FailureInnerLeftLine", 45.0, 58.0, -491.0, -62.0, Color(0.0, 0.45, 0.78, 0.42), 0)
	_gameover_full_rect(board, "FailureInnerRightLine", 491.0, 58.0, -45.0, -62.0, Color(0.0, 0.45, 0.78, 0.42), 0)

	for y in range(9):
		for x in range(28):
			var dot_index := y * 28 + x
			var dot := _gameover_rect(board, "PanelDot%d" % dot_index)
			_gameover_place(dot, 111.0 + float(x) * 12.0, 72.0 + float(y) * 20.0, 114.0 + float(x) * 12.0, 75.0 + float(y) * 20.0)
			dot.color = Color(0.06, 0.18, 0.28, 0.22)
			dot.z_index = 0

	_gameover_color_rect(board, "TopMetalDeck", 130.0, -14.0, 410.0, 34.0, Color(0.14, 0.17, 0.20, 1.0), 2)
	_gameover_color_rect(board, "TopMetalDeckHi", 138.0, -7.0, 402.0, 4.0, Color(0.36, 0.42, 0.48, 1.0), 3)
	_gameover_color_rect(board, "TopMetalDeckLow", 132.0, 24.0, 408.0, 34.0, Color(0.04, 0.045, 0.055, 1.0), 3)
	_gameover_color_rect(board, "LeftTopRail", 30.0, 7.0, 183.0, 35.0, Color(0.18, 0.22, 0.27, 1.0), 2)
	_gameover_color_rect(board, "RightTopRail", 357.0, 7.0, 510.0, 35.0, Color(0.18, 0.22, 0.27, 1.0), 2)
	_gameover_color_rect(board, "LeftTopRailHi", 44.0, 10.0, 172.0, 16.0, Color(0.45, 0.53, 0.60, 1.0), 3)
	_gameover_color_rect(board, "RightTopRailHi", 368.0, 10.0, 496.0, 16.0, Color(0.45, 0.53, 0.60, 1.0), 3)

	for i in range(8):
		var stripe_color := Color(0.98, 0.62, 0.06, 1.0) if i % 2 == 0 else Color(0.035, 0.037, 0.044, 1.0)
		_gameover_color_rect(board, "LeftHazard%d" % i, 63.0 + float(i) * 14.0, 18.0, 73.0 + float(i) * 14.0, 31.0, stripe_color, 4)
		_gameover_color_rect(board, "RightHazard%d" % i, 367.0 + float(i) * 14.0, 18.0, 377.0 + float(i) * 14.0, 31.0, stripe_color, 4)

	_gameover_color_rect(board, "LeftSideMetal", 10.0, 42.0, 46.0, 295.0, Color(0.15, 0.18, 0.22, 1.0), 1)
	_gameover_color_rect(board, "RightSideMetal", 494.0, 42.0, 530.0, 295.0, Color(0.15, 0.18, 0.22, 1.0), 1)
	_gameover_color_rect(board, "LeftSideDark", 18.0, 59.0, 36.0, 282.0, Color(0.034, 0.045, 0.062, 1.0), 2)
	_gameover_color_rect(board, "RightSideDark", 504.0, 59.0, 522.0, 282.0, Color(0.034, 0.045, 0.062, 1.0), 2)
	_gameover_color_rect(board, "LeftBlueTube", 25.0, 84.0, 30.0, 247.0, Color(0.05, 0.54, 0.92, 0.90), 3)
	_gameover_color_rect(board, "RightBlueTube", 510.0, 84.0, 515.0, 247.0, Color(0.05, 0.54, 0.92, 0.90), 3)
	_gameover_color_rect(board, "LeftBlueTubeCore", 27.0, 90.0, 29.0, 240.0, Color(0.50, 0.86, 1.0, 0.82), 4)
	_gameover_color_rect(board, "RightBlueTubeCore", 512.0, 90.0, 514.0, 240.0, Color(0.50, 0.86, 1.0, 0.82), 4)

	for side in range(2):
		var bolt_x := 29.0 if side == 0 else 503.0
		for j in range(5):
			var bolt_name := "FrameBolt%d_%d" % [side, j]
			_gameover_color_rect(board, bolt_name, bolt_x, 54.0 + float(j) * 49.0, bolt_x + 10.0, 64.0 + float(j) * 49.0, Color(0.44, 0.50, 0.57, 1.0), 5)
			_gameover_color_rect(board, "%sCore" % bolt_name, bolt_x + 3.0, 57.0 + float(j) * 49.0, bolt_x + 7.0, 61.0 + float(j) * 49.0, Color(0.04, 0.05, 0.065, 1.0), 6)

	_gameover_color_rect(board, "WarningLampBase", 229.0, -49.0, 311.0, -8.0, Color(0.08, 0.09, 0.10, 1.0), 4)
	_gameover_color_rect(board, "WarningLampGlass", 241.0, -43.0, 299.0, -6.0, Color(0.85, 0.06, 0.035, 1.0), 5)
	_gameover_color_rect(board, "WarningLampHot", 260.0, -35.0, 280.0, -9.0, Color(1.0, 0.64, 0.20, 1.0), 6)
	_gameover_color_rect(board, "WarningLampWhite", 266.0, -30.0, 274.0, -13.0, Color(1.0, 0.96, 0.64, 1.0), 7)
	_gameover_color_rect(board, "WarningLampGlow", 236.0, -46.0, 304.0, -3.0, Color(1.0, 0.08, 0.02, 0.20), 3)

	var star := _gameover_label(board, "CenterBoltStar")
	_gameover_place(star, 239.0, 24.0, 301.0, 57.0)
	star.text = "+"
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	star.add_theme_font_size_override("font_size", 35)
	star.add_theme_color_override("font_color", Color(1.0, 0.74, 0.10, 1.0))
	star.add_theme_color_override("font_outline_color", Color(0.07, 0.05, 0.02, 1.0))
	star.add_theme_constant_override("outline_size", 3)
	star.z_index = 7

	_gameover_color_rect(board, "LeftTitleWingA", 68.0, 94.0, 137.0, 106.0, Color(0.88, 0.12, 0.035, 0.95), 1)
	_gameover_color_rect(board, "LeftTitleWingB", 81.0, 107.0, 137.0, 118.0, Color(0.70, 0.06, 0.025, 0.92), 1)
	_gameover_color_rect(board, "RightTitleWingA", 403.0, 94.0, 472.0, 106.0, Color(0.88, 0.12, 0.035, 0.95), 1)
	_gameover_color_rect(board, "RightTitleWingB", 403.0, 107.0, 459.0, 118.0, Color(0.70, 0.06, 0.025, 0.92), 1)

	for side in range(2):
		var x0 := 93.0 if side == 0 else 428.0
		var x1 := 99.0 if side == 0 else 434.0
		_gameover_color_rect(board, "ScoreBracket%dA" % side, x0, 154.0, x1, 209.0, Color(0.0, 0.55, 0.96, 0.70), 1)
		_gameover_color_rect(board, "ScoreBracket%dB" % side, x0, 154.0, x0 + 22.0, 160.0, Color(0.0, 0.55, 0.96, 0.70), 1)
		_gameover_color_rect(board, "ScoreBracket%dC" % side, x0, 203.0, x0 + 22.0, 209.0, Color(0.0, 0.55, 0.96, 0.70), 1)

	_gameover_color_rect(board, "BottomRail", 78.0, 305.0, 462.0, 335.0, Color(0.13, 0.15, 0.18, 1.0), 2)
	_gameover_color_rect(board, "BottomRailHi", 95.0, 309.0, 445.0, 316.0, Color(0.42, 0.47, 0.52, 1.0), 3)
	_gameover_color_rect(board, "BottomRailDark", 105.0, 326.0, 435.0, 335.0, Color(0.035, 0.04, 0.05, 1.0), 3)
	for i in range(6):
		_gameover_color_rect(board, "BottomBlueLight%d" % i, 246.0 + float(i) * 10.0, 320.0, 253.0 + float(i) * 10.0, 328.0, Color(0.0, 0.48, 0.92, 0.96), 4)
	for i in range(4):
		_gameover_color_rect(board, "BottomRedLightL%d" % i, 26.0, 232.0 + float(i) * 11.0, 33.0, 239.0 + float(i) * 11.0, Color(1.0, 0.18, 0.04, 0.92), 4)
		_gameover_color_rect(board, "BottomRedLightR%d" % i, 507.0, 232.0 + float(i) * 11.0, 514.0, 239.0 + float(i) * 11.0, Color(1.0, 0.18, 0.04, 0.92), 4)

func _init_gameover_stat_row_v2(parent: VBoxContainer, row_name: String, title_text: String, initial_value: String) -> Label:
	var row := parent.get_node_or_null(row_name) as PanelContainer
	if row == null:
		row = PanelContainer.new()
		row.name = row_name
		parent.add_child(row)
	row.custom_minimum_size = Vector2(370.0, 30.0)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row_style := _make_gameover_stylebox(
		Color(0.018, 0.069, 0.120, 0.96),
		Color(0.0, 0.42, 0.68, 0.98),
		2,
		0,
		4.0
	)
	row_style.shadow_color = Color(0.0, 0.0, 0.0, 0.54)
	row_style.shadow_size = 3
	row_style.shadow_offset = Vector2(2.0, 2.0)
	row.add_theme_stylebox_override("panel", row_style)

	var content := row.get_node_or_null("Content") as HBoxContainer
	if content == null:
		content = HBoxContainer.new()
		content.name = "Content"
		row.add_child(content)
	content.alignment = 1
	content.add_theme_constant_override("separation", 8)

	var icon_wrap := content.get_node_or_null("IconWrap") as Control
	if icon_wrap == null:
		icon_wrap = Control.new()
		icon_wrap.name = "IconWrap"
		content.add_child(icon_wrap)
	content.move_child(icon_wrap, 0)
	icon_wrap.custom_minimum_size = Vector2(34.0, 24.0)

	var icon_bg := _gameover_rect(icon_wrap, "IconBg")
	_gameover_place(icon_bg, 2.0, 1.0, 30.0, 23.0)
	icon_bg.color = Color(0.006, 0.037, 0.065, 1.0)

	for i in range(7):
		var part := _gameover_rect(icon_wrap, "IconPart%d" % i)
		part.z_index = 2
		if row_name == "DistanceRow":
			var pin_color := Color(0.08, 0.62, 0.95, 1.0)
			var pin_light := Color(0.38, 0.88, 1.0, 1.0)
			match i:
				0:
					_gameover_place(part, 9.0, 3.0, 25.0, 17.0)
					part.color = pin_color
				1:
					_gameover_place(part, 12.0, 17.0, 22.0, 25.0)
					part.color = pin_color
				2:
					_gameover_place(part, 12.0, 7.0, 22.0, 16.0)
					part.color = Color(0.015, 0.055, 0.085, 1.0)
				3:
					_gameover_place(part, 14.0, 9.0, 20.0, 14.0)
					part.color = pin_light
				4:
					_gameover_place(part, 7.0, 7.0, 11.0, 15.0)
					part.color = pin_light
				5:
					_gameover_place(part, 24.0, 7.0, 28.0, 15.0)
					part.color = Color(0.02, 0.25, 0.48, 1.0)
				_:
					_gameover_place(part, 15.0, 24.0, 19.0, 27.0)
					part.color = Color(0.02, 0.25, 0.48, 1.0)
		else:
			match i:
				0:
					_gameover_place(part, 7.0, 9.0, 26.0, 23.0)
					part.color = Color(0.76, 0.31, 0.045, 1.0)
				1:
					_gameover_place(part, 9.0, 5.0, 24.0, 11.0)
					part.color = Color(1.0, 0.60, 0.12, 1.0)
				2:
					_gameover_place(part, 7.0, 9.0, 16.0, 15.0)
					part.color = Color(0.98, 0.46, 0.08, 1.0)
				3:
					_gameover_place(part, 17.0, 9.0, 26.0, 15.0)
					part.color = Color(0.55, 0.18, 0.030, 1.0)
				4:
					_gameover_place(part, 16.0, 6.0, 20.0, 23.0)
					part.color = Color(0.34, 0.11, 0.020, 1.0)
				5:
					_gameover_place(part, 10.0, 17.0, 24.0, 20.0)
					part.color = Color(1.0, 0.72, 0.18, 1.0)
				_:
					_gameover_place(part, 6.0, 23.0, 27.0, 26.0)
					part.color = Color(0.20, 0.07, 0.015, 1.0)

	var title := content.get_node_or_null("Title") as Label
	if title == null:
		title = Label.new()
		title.name = "Title"
		content.add_child(title)
	title.custom_minimum_size = Vector2(90.0, 0.0)
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.87, 0.94, 1.0, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.015, 0.035, 0.055, 1.0))
	title.add_theme_constant_override("outline_size", 2)

	var filler := content.get_node_or_null("Filler") as Control
	if filler == null:
		filler = Control.new()
		filler.name = "Filler"
		content.add_child(filler)
	filler.custom_minimum_size = Vector2(62.0, 0.0)

	var value := content.get_node_or_null("Value") as Label
	if value == null:
		value = Label.new()
		value.name = "Value"
		content.add_child(value)
	value.custom_minimum_size = Vector2(106.0, 0.0)
	value.text = initial_value
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 23)
	value.add_theme_color_override("font_color", Color(1.0, 0.75, 0.07, 1.0))
	value.add_theme_color_override("font_outline_color", Color(0.19, 0.07, 0.0, 1.0))
	value.add_theme_constant_override("outline_size", 2)
	return value

func _init_gameover_style() -> void:
	var panel := gameover_ui.get_node("GameOverPanel") as Panel
	var vbox := panel.get_node("VBoxContainer") as VBoxContainer
	panel.add_theme_stylebox_override("panel", _make_gameover_stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))

	var overlay := panel.get_node_or_null("PixelOverlay") as ColorRect
	if overlay == null:
		overlay = ColorRect.new()
		overlay.name = "PixelOverlay"
		panel.add_child(overlay)
		panel.move_child(overlay, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0.003, 0.014, 0.038, 0.88)
	overlay.z_index = 0

	var scanlines := panel.get_node_or_null("PixelScanlines") as ColorRect
	if scanlines == null:
		scanlines = ColorRect.new()
		scanlines.name = "PixelScanlines"
		panel.add_child(scanlines)
		panel.move_child(scanlines, 1)
	scanlines.set_anchors_preset(Control.PRESET_FULL_RECT)
	scanlines.offset_left = 0.0
	scanlines.offset_top = 0.0
	scanlines.offset_right = 0.0
	scanlines.offset_bottom = 0.0
	scanlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scanlines.color = Color(0.0, 0.12, 0.22, 0.14)
	scanlines.z_index = 1

	var board := panel.get_node_or_null("PixelGameOverBoard") as Panel
	if board == null:
		board = Panel.new()
		board.name = "PixelGameOverBoard"
		panel.add_child(board)
	board.anchor_left = 0.5
	board.anchor_top = 0.5
	board.anchor_right = 0.5
	board.anchor_bottom = 0.5
	board.offset_left = -205.0
	board.offset_top = -122.0
	board.offset_right = 205.0
	board.offset_bottom = 132.0
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	board.z_index = 3
	board.add_theme_stylebox_override("panel", _make_gameover_stylebox(
		Color(0.06, 0.020, 0.012, 0.98),
		Color(1.0, 0.50, 0.08, 1.0),
		5,
		0,
		12.0
	))
	_init_gameover_board_decor(board)

	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -160.0
	vbox.offset_top = -88.0
	vbox.offset_right = 160.0
	vbox.offset_bottom = 110.0
	vbox.z_index = 9
	vbox.alignment = 1
	vbox.add_theme_constant_override("separation", 1)

	var title_shadow := vbox.get_node_or_null("GameOverTitleShadow") as Label
	if title_shadow == null:
		title_shadow = Label.new()
		title_shadow.name = "GameOverTitleShadow"
		vbox.add_child(title_shadow)
		vbox.move_child(title_shadow, 0)
	title_shadow.text = "挑战失败"
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_shadow.custom_minimum_size = Vector2(320.0, 2.0)
	title_shadow.add_theme_font_size_override("font_size", 12)
	title_shadow.add_theme_color_override("font_color", Color(0.95, 0.14, 0.03, 0.62))
	title_shadow.add_theme_color_override("font_outline_color", Color(0.04, 0.01, 0.00, 0.75))
	title_shadow.add_theme_constant_override("outline_size", 2)

	var title := vbox.get_node_or_null("GameOverTitle") as Label
	if title == null:
		title = Label.new()
		title.name = "GameOverTitle"
		vbox.add_child(title)
		vbox.move_child(title, 1)
	title.text = "挑战失败"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(320.0, 44.0)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1.0, 0.74, 0.10))
	title.add_theme_color_override("font_outline_color", Color(0.34, 0.045, 0.012))
	title.add_theme_constant_override("outline_size", 6)

	var title_highlight := vbox.get_node_or_null("TitleHighlight") as Label
	if title_highlight == null:
		title_highlight = Label.new()
		title_highlight.name = "TitleHighlight"
		vbox.add_child(title_highlight)
		vbox.move_child(title_highlight, title.get_index() + 1)
	title_highlight.text = "▰▰      ▰▰"
	title_highlight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_highlight.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_highlight.custom_minimum_size = Vector2(320.0, 5.0)
	title_highlight.add_theme_font_size_override("font_size", 10)
	title_highlight.add_theme_color_override("font_color", Color(1.0, 0.18, 0.05, 0.92))

	var caption := vbox.get_node_or_null("ScoreLabel") as Label
	if caption:
		caption.text = "△ 最终得分"
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.custom_minimum_size = Vector2(320.0, 18.0)
		caption.add_theme_font_size_override("font_size", 16)
		caption.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68))
		caption.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.00))
		caption.add_theme_constant_override("outline_size", 2)

	final_score_label.custom_minimum_size = Vector2(320.0, 50.0)
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 54)
	final_score_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.10))
	final_score_label.add_theme_color_override("font_outline_color", Color(0.39, 0.11, 0.00))
	final_score_label.add_theme_constant_override("outline_size", 5)

	var separator := vbox.get_node_or_null("ScoreSeparator") as Label
	if separator == null:
		separator = Label.new()
		separator.name = "ScoreSeparator"
		vbox.add_child(separator)
	separator.text = "━━━      ━━━"
	separator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	separator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	separator.custom_minimum_size = Vector2(320.0, 4.0)
	separator.add_theme_font_size_override("font_size", 11)
	separator.add_theme_color_override("font_color", Color(0.98, 0.18, 0.05, 0.90))
	separator.add_theme_color_override("font_outline_color", Color(0.04, 0.015, 0.00))
	separator.add_theme_constant_override("outline_size", 1)
	vbox.move_child(separator, final_score_label.get_index() + 1)

	var old_stats := vbox.get_node_or_null("StatsContainer") as Control
	if old_stats:
		old_stats.hide()
	var styled_stats := vbox.get_node_or_null("StyledStats") as VBoxContainer
	if styled_stats == null:
		styled_stats = VBoxContainer.new()
		styled_stats.name = "StyledStats"
		vbox.add_child(styled_stats)
	styled_stats.custom_minimum_size = Vector2(280.0, 52.0)
	styled_stats.alignment = 1
	styled_stats.add_theme_constant_override("separation", 3)
	vbox.move_child(styled_stats, separator.get_index() + 1)
	gameover_distance_display = _init_gameover_stat_row(styled_stats, "DistanceRow", "距离", "0m")
	gameover_coin_display = _init_gameover_stat_row(styled_stats, "CoinRow", "物品", "0")

	var restart := vbox.get_node_or_null("RestartButton") as Button
	if restart:
		restart.custom_minimum_size = Vector2(280.0, 38.0)
		restart.text = "再来一局"
		restart.focus_mode = Control.FOCUS_NONE
		restart.add_theme_font_size_override("font_size", 22)
		restart.add_theme_color_override("font_color", Color(1.0, 0.98, 0.90))
		restart.add_theme_color_override("font_outline_color", Color(0.43, 0.10, 0.00))
		restart.add_theme_constant_override("outline_size", 3)
		restart.add_theme_stylebox_override("normal", _make_gameover_stylebox(Color(0.98, 0.28, 0.02), Color(1.0, 0.78, 0.18), 4, 0, 6.0))
		restart.add_theme_stylebox_override("hover", _make_gameover_stylebox(Color(1.0, 0.42, 0.04), Color(1.0, 0.92, 0.30), 4, 0, 6.0))
		restart.add_theme_stylebox_override("pressed", _make_gameover_stylebox(Color(0.78, 0.18, 0.01), Color(0.92, 0.38, 0.05), 4, 0, 6.0))

	var hint := vbox.get_node_or_null("GameOverHint") as Label
	if hint:
		hint.hide()

func _init_gameover_board_decor(board: Panel) -> void:
	var back_shadow := board.get_node_or_null("BackShadow") as ColorRect
	if back_shadow == null:
		back_shadow = ColorRect.new()
		back_shadow.name = "BackShadow"
		board.add_child(back_shadow)
		board.move_child(back_shadow, 0)
	back_shadow.anchor_left = 0.0
	back_shadow.anchor_top = 0.0
	back_shadow.anchor_right = 1.0
	back_shadow.anchor_bottom = 1.0
	back_shadow.offset_left = 9.0
	back_shadow.offset_top = 10.0
	back_shadow.offset_right = 9.0
	back_shadow.offset_bottom = 10.0
	back_shadow.color = Color(0.0, 0.0, 0.0, 0.50)
	back_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back_shadow.z_index = -1

	var outer_glow := board.get_node_or_null("OuterGlow") as ColorRect
	if outer_glow == null:
		outer_glow = ColorRect.new()
		outer_glow.name = "OuterGlow"
		board.add_child(outer_glow)
		board.move_child(outer_glow, 1)
	outer_glow.anchor_left = 0.0
	outer_glow.anchor_top = 0.0
	outer_glow.anchor_right = 1.0
	outer_glow.anchor_bottom = 1.0
	outer_glow.offset_left = -5.0
	outer_glow.offset_top = -5.0
	outer_glow.offset_right = 5.0
	outer_glow.offset_bottom = 5.0
	outer_glow.color = Color(1.0, 0.22, 0.02, 0.22)
	outer_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_glow.z_index = -2

	var inner := board.get_node_or_null("InnerPlate") as ColorRect
	if inner == null:
		inner = ColorRect.new()
		inner.name = "InnerPlate"
		board.add_child(inner)
	inner.anchor_left = 0.0
	inner.anchor_top = 0.0
	inner.anchor_right = 1.0
	inner.anchor_bottom = 1.0
	inner.offset_left = 26.0
	inner.offset_top = 34.0
	inner.offset_right = -26.0
	inner.offset_bottom = -22.0
	inner.color = Color(0.055, 0.023, 0.014, 0.94)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(6):
		var plate_line := board.get_node_or_null("InnerPlateLine%d" % i) as ColorRect
		if plate_line == null:
			plate_line = ColorRect.new()
			plate_line.name = "InnerPlateLine%d" % i
			board.add_child(plate_line)
		plate_line.anchor_left = 0.10
		plate_line.anchor_top = 0.0
		plate_line.anchor_right = 0.90
		plate_line.anchor_bottom = 0.0
		plate_line.offset_top = 50.0 + float(i) * 31.0
		plate_line.offset_bottom = 51.5 + float(i) * 31.0
		plate_line.color = Color(0.42, 0.10, 0.02, 0.26)
		plate_line.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(18):
		var pixel := board.get_node_or_null("InnerPixel%d" % i) as ColorRect
		if pixel == null:
			pixel = ColorRect.new()
			pixel.name = "InnerPixel%d" % i
			board.add_child(pixel)
		pixel.anchor_left = 0.5
		pixel.anchor_top = 0.0
		pixel.anchor_right = 0.5
		pixel.anchor_bottom = 0.0
		pixel.offset_left = -160.0 + float(i % 9) * 40.0
		pixel.offset_top = 48.0 + float(i / 9) * 132.0
		pixel.offset_right = pixel.offset_left + 3.0
		pixel.offset_bottom = pixel.offset_top + 3.0
		pixel.color = Color(1.0, 0.32, 0.03, 0.26)
		pixel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_bar := board.get_node_or_null("TopMetalBar") as ColorRect
	if top_bar == null:
		top_bar = ColorRect.new()
		top_bar.name = "TopMetalBar"
		board.add_child(top_bar)
	top_bar.anchor_left = 0.12
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 0.88
	top_bar.anchor_bottom = 0.0
	top_bar.offset_left = 0.0
	top_bar.offset_top = -10.0
	top_bar.offset_right = 0.0
	top_bar.offset_bottom = 27.0
	top_bar.color = Color(0.16, 0.055, 0.025, 1.0)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top_shadow := board.get_node_or_null("TopMetalShadow") as ColorRect
	if top_shadow == null:
		top_shadow = ColorRect.new()
		top_shadow.name = "TopMetalShadow"
		board.add_child(top_shadow)
	top_shadow.anchor_left = 0.16
	top_shadow.anchor_top = 0.0
	top_shadow.anchor_right = 0.84
	top_shadow.anchor_bottom = 0.0
	top_shadow.offset_top = 20.0
	top_shadow.offset_bottom = 28.0
	top_shadow.color = Color(0.045, 0.018, 0.010, 1.0)
	top_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(10):
		var stripe := board.get_node_or_null("TopHazardStripe%d" % i) as ColorRect
		if stripe == null:
			stripe = ColorRect.new()
			stripe.name = "TopHazardStripe%d" % i
			board.add_child(stripe)
		stripe.anchor_left = 0.5
		stripe.anchor_top = 0.0
		stripe.anchor_right = 0.5
		stripe.anchor_bottom = 0.0
		stripe.offset_left = -164.0 + float(i) * 36.0
		stripe.offset_top = 5.0
		stripe.offset_right = -142.0 + float(i) * 36.0
		stripe.offset_bottom = 14.0
		stripe.color = Color(1.0, 0.64, 0.06, 1.0) if i % 2 == 0 else Color(0.070, 0.030, 0.014, 1.0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var badge := board.get_node_or_null("SkullBadge") as Label
	if badge == null:
		badge = Label.new()
		badge.name = "SkullBadge"
		board.add_child(badge)
	badge.anchor_left = 0.5
	badge.anchor_top = 0.0
	badge.anchor_right = 0.5
	badge.anchor_bottom = 0.0
	badge.offset_left = -40.0
	badge.offset_top = -12.0
	badge.offset_right = 40.0
	badge.offset_bottom = 22.0
	badge.text = "✦"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", Color(1.0, 0.70, 0.08, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0.06, 0.02, 0.01, 1.0))
	badge.add_theme_constant_override("outline_size", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lamp_base := board.get_node_or_null("WarningLampBase") as ColorRect
	if lamp_base == null:
		lamp_base = ColorRect.new()
		lamp_base.name = "WarningLampBase"
		board.add_child(lamp_base)
	lamp_base.anchor_left = 0.5
	lamp_base.anchor_top = 0.0
	lamp_base.anchor_right = 0.5
	lamp_base.anchor_bottom = 0.0
	lamp_base.offset_left = -25.0
	lamp_base.offset_top = -34.0
	lamp_base.offset_right = 25.0
	lamp_base.offset_bottom = -10.0
	lamp_base.color = Color(0.10, 0.030, 0.018, 1.0)
	lamp_base.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lamp := board.get_node_or_null("WarningLamp") as ColorRect
	if lamp == null:
		lamp = ColorRect.new()
		lamp.name = "WarningLamp"
		board.add_child(lamp)
	lamp.anchor_left = 0.5
	lamp.anchor_top = 0.0
	lamp.anchor_right = 0.5
	lamp.anchor_bottom = 0.0
	lamp.offset_left = -16.0
	lamp.offset_top = -30.0
	lamp.offset_right = 16.0
	lamp.offset_bottom = -8.0
	lamp.color = Color(1.0, 0.12, 0.045, 1.0)
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lamp_glow := board.get_node_or_null("WarningLampGlow") as ColorRect
	if lamp_glow == null:
		lamp_glow = ColorRect.new()
		lamp_glow.name = "WarningLampGlow"
		board.add_child(lamp_glow)
	lamp_glow.anchor_left = 0.5
	lamp_glow.anchor_top = 0.0
	lamp_glow.anchor_right = 0.5
	lamp_glow.anchor_bottom = 0.0
	lamp_glow.offset_left = -9.0
	lamp_glow.offset_top = -26.0
	lamp_glow.offset_right = 9.0
	lamp_glow.offset_bottom = -13.0
	lamp_glow.color = Color(1.0, 0.82, 0.36, 1.0)
	lamp_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for side in range(2):
		var rail := board.get_node_or_null("SideBlueRail%d" % side) as ColorRect
		if rail == null:
			rail = ColorRect.new()
			rail.name = "SideBlueRail%d" % side
			board.add_child(rail)
		rail.anchor_left = 0.0 if side == 0 else 1.0
		rail.anchor_top = 0.18
		rail.anchor_right = 0.0 if side == 0 else 1.0
		rail.anchor_bottom = 0.80
		rail.offset_left = 12.0 if side == 0 else -19.0
		rail.offset_right = 19.0 if side == 0 else -12.0
		rail.color = Color(1.0, 0.28, 0.035, 0.86)
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE

		for j in range(4):
			var bolt := board.get_node_or_null("SideBolt%d_%d" % [side, j]) as ColorRect
			if bolt == null:
				bolt = ColorRect.new()
				bolt.name = "SideBolt%d_%d" % [side, j]
				board.add_child(bolt)
			bolt.anchor_left = 0.0 if side == 0 else 1.0
			bolt.anchor_top = 0.0
			bolt.anchor_right = 0.0 if side == 0 else 1.0
			bolt.anchor_bottom = 0.0
			bolt.offset_left = 21.0 if side == 0 else -31.0
			bolt.offset_top = 43.0 + float(j) * 55.0
			bolt.offset_right = 31.0 if side == 0 else -21.0
			bolt.offset_bottom = 53.0 + float(j) * 55.0
			bolt.color = Color(1.0, 0.75, 0.18, 1.0)
			bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for i in range(10):
		var light := board.get_node_or_null("BottomLight%d" % i) as ColorRect
		if light == null:
			light = ColorRect.new()
			light.name = "BottomLight%d" % i
			board.add_child(light)
		light.anchor_left = 0.5
		light.anchor_top = 1.0
		light.anchor_right = 0.5
		light.anchor_bottom = 1.0
		light.offset_left = -70.0 + float(i) * 15.5
		light.offset_top = -13.0
		light.offset_right = -62.0 + float(i) * 15.5
		light.offset_bottom = -7.0
		light.color = Color(1.0, 0.20, 0.035, 0.92) if i % 2 == 0 else Color(1.0, 0.62, 0.08, 0.92)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _init_gameover_stat_row(parent: VBoxContainer, row_name: String, title_text: String, initial_value: String) -> Label:
	var row := parent.get_node_or_null(row_name) as PanelContainer
	if row == null:
		row = PanelContainer.new()
		row.name = row_name
		parent.add_child(row)
	row.custom_minimum_size = Vector2(260.0, 25.0)
	row.add_theme_stylebox_override("panel", _make_gameover_stylebox(
		Color(0.085, 0.030, 0.014, 0.92),
		Color(0.84, 0.22, 0.035, 0.95),
		2,
		0,
		5.0
	))

	var content := row.get_node_or_null("Content") as HBoxContainer
	if content == null:
		content = HBoxContainer.new()
		content.name = "Content"
		row.add_child(content)
	content.alignment = 1
	content.add_theme_constant_override("separation", 6)

	var icon_wrap := content.get_node_or_null("IconWrap") as Control
	if icon_wrap == null:
		icon_wrap = Control.new()
		icon_wrap.name = "IconWrap"
		content.add_child(icon_wrap)
	content.move_child(icon_wrap, 0)
	icon_wrap.custom_minimum_size = Vector2(22.0, 18.0)

	var icon_bg := icon_wrap.get_node_or_null("IconBg") as ColorRect
	if icon_bg == null:
		icon_bg = ColorRect.new()
		icon_bg.name = "IconBg"
		icon_wrap.add_child(icon_bg)
	icon_bg.position = Vector2(2.0, 2.0)
	icon_bg.size = Vector2(18.0, 14.0)
	icon_bg.color = Color(0.14, 0.038, 0.018, 1.0) if row_name == "DistanceRow" else Color(0.18, 0.075, 0.018, 1.0)
	icon_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := content.get_node_or_null("Icon") as ColorRect
	if icon:
		icon.queue_free()
	for i in range(4):
		var part := icon_wrap.get_node_or_null("IconPart%d" % i) as ColorRect
		if part == null:
			part = ColorRect.new()
			part.name = "IconPart%d" % i
			icon_wrap.add_child(part)
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if row_name == "DistanceRow":
			var distance_pos: Vector2
			var distance_size: Vector2
			match i:
				0:
					distance_pos = Vector2(7, 1)
					distance_size = Vector2(7, 6)
				1:
					distance_pos = Vector2(5, 6)
					distance_size = Vector2(4, 8)
				2:
					distance_pos = Vector2(11, 6)
					distance_size = Vector2(4, 8)
				_:
					distance_pos = Vector2(8, 11)
					distance_size = Vector2(4, 5)
			part.position = distance_pos
			part.size = distance_size
			part.color = Color(1.0, 0.24, 0.04, 1.0) if i != 3 else Color(1.0, 0.80, 0.20, 1.0)
		else:
			var crate_pos: Vector2
			var crate_size: Vector2
			var crate_color: Color
			match i:
				0:
					crate_pos = Vector2(4, 6)
					crate_size = Vector2(15, 10)
					crate_color = Color(0.76, 0.30, 0.05, 1.0)
				1:
					crate_pos = Vector2(7, 3)
					crate_size = Vector2(10, 3)
					crate_color = Color(1.0, 0.58, 0.12, 1.0)
				2:
					crate_pos = Vector2(12, 3)
					crate_size = Vector2(3, 10)
					crate_color = Color(0.50, 0.18, 0.035, 1.0)
				_:
					crate_pos = Vector2(7, 10)
					crate_size = Vector2(8, 2)
					crate_color = Color(1.0, 0.76, 0.22, 1.0)
			part.position = crate_pos
			part.size = crate_size
			part.color = crate_color

	var title := content.get_node_or_null("Title") as Label
	if title == null:
		title = Label.new()
		title.name = "Title"
		content.add_child(title)
	title.custom_minimum_size = Vector2(66.0, 0.0)
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.66))
	title.add_theme_color_override("font_outline_color", Color(0.09, 0.025, 0.00))
	title.add_theme_constant_override("outline_size", 1)

	var filler := content.get_node_or_null("Filler") as Control
	if filler == null:
		filler = Control.new()
		filler.name = "Filler"
		content.add_child(filler)
	filler.custom_minimum_size = Vector2(38.0, 0.0)

	var value := content.get_node_or_null("Value") as Label
	if value == null:
		value = Label.new()
		value.name = "Value"
		content.add_child(value)
	value.custom_minimum_size = Vector2(88.0, 0.0)
	value.text = initial_value
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	value.add_theme_color_override("font_color", Color(1.0, 0.78, 0.12))
	value.add_theme_color_override("font_outline_color", Color(0.18, 0.065, 0.0))
	value.add_theme_constant_override("outline_size", 2)
	return value

func _update_hud() -> void:
	score_label.text = str(int(score))
	coin_label.text = str(coin_count)

func show_menu() -> void:
	menu_ui.show()
	gameover_ui.hide()
	score_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	coin_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func show_gameover() -> void:
	final_score_label.text = str(int(score))
	distance_value_label.text = str(int(distance)) + "m"
	coin_value_label.text = str(coin_count)
	if gameover_distance_display:
		gameover_distance_display.text = str(int(distance)) + "m"
	if gameover_coin_display:
		gameover_coin_display.text = str(coin_count)
	score_label.modulate = Color(0.72, 0.82, 0.95, 0.46)
	coin_label.modulate = Color(0.72, 0.82, 0.95, 0.46)
	gameover_ui.show()

func _on_menu_start_pressed() -> void:
	start_game()

func _on_gameover_restart_pressed() -> void:
	start_game()
