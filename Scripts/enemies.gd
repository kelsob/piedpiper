extends Node2D

@export var enemy_scene: PackedScene = preload("res://Scenes/enemy.tscn")
@export var player_path: NodePath = "../Player"
@export var spawn_interval := 0.1
@export var max_enemies := 100
@export var min_spawn_distance := 160.0
@export var spawn_area_radius := 1000.0

var _player: Node2D
var _spawn_timer := 0.0

func _ready():
	_player = get_node(player_path)
	_spawn_timer = spawn_interval

func _process(delta):
	_spawn_timer -= delta

	if _spawn_timer <= 0:
		_spawn_timer = spawn_interval
		_try_spawn_enemy()

func _try_spawn_enemy():
	if get_child_count() >= max_enemies:
		return

	var spawn_pos = _get_valid_spawn_position()
	if spawn_pos == null:
		return

	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy)
	enemy.add_to_group("enemies")

func _get_valid_spawn_position() -> Vector2:
	var attempts := 10
	while attempts > 0:
		attempts -= 1
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_area_radius)
		var offset = Vector2.RIGHT.rotated(angle) * distance
		var candidate_pos = _player.global_position + offset

		# Optional: check if inside screen bounds or within a play area
		return candidate_pos

	return Vector2(0,0)
