extends Node

# Game constants
const WIDTH := 800.0
const HEIGHT := 450.0
const GROUND_Y := 370.0
const GRAVITY := 700.0
const PLAYER_X := 120.0

# Game state
enum State { MENU, PLAYING, GAMEOVER }
var state: State = State.MENU

var speed: float = 300.0
var base_speed: float = 300.0
var max_speed: float = 840.0

var score: int = 0
var coin_count: int = 0
var distance: float = 0.0
var frame_count: int = 0

signal game_started
signal game_ended
signal coin_collected
