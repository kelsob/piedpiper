extends CharacterBody2D

@export var speed := 20.0
@export var player_path: NodePath = "../../Player"
@export var attack_cooldown := 1.5 # seconds
@export var attack_damage : float = 10.0
@export var max_charm := 100.0
@export var charm_decay_rate := 20.0 # units per second
@export var max_health := 20


var attack_on_cooldown : bool = false
var _player: Node2D
var _player_in_range := false
var current_charm := 0.0
var is_charmed := false
var target_enemy: Node2D = null
var current_health := max_health


func _ready():
	_player = get_node(player_path)
	$Timer.wait_time = attack_cooldown

func _physics_process(delta):
	if is_charmed:
		handle_charmed_behavior(delta)
	elif _player and not _player_in_range:
		var direction = (_player.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
	
	# Handle charm decay when not being charmed
	if not _player.is_playing_note:
		current_charm = max(0.0, current_charm - charm_decay_rate * delta)
		if current_charm == 0.0:
			is_charmed = false

func handle_charmed_behavior(delta):
	if target_enemy and is_instance_valid(target_enemy):
		var direction = (target_enemy.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		
		if global_position.distance_to(target_enemy.global_position) < 10.0 and !attack_on_cooldown:
			attack_enemy(target_enemy)
	else:
		# Find new target
		var enemies = get_tree().get_nodes_in_group("enemies")
		var closest_distance = INF
		for enemy in enemies:
			if enemy != self and not enemy.is_charmed:
				var distance = global_position.distance_to(enemy.global_position)
				if distance < closest_distance:
					closest_distance = distance
					target_enemy = enemy

func attack_enemy(enemy: Node2D):
	enemy.take_damage(attack_damage)
	attack_on_cooldown = true
	$Timer.start()

func _on_hurtbox_body_entered(body):
	if body.name == "Player" and not is_charmed:
		_player_in_range = true
		if !attack_on_cooldown:
			attack_player(attack_damage)

func _on_hurtbox_body_exited(body):
	if body.name == "Player":
		_player_in_range = false

func _on_timer_timeout():
	attack_on_cooldown = false
	if _player_in_range and not is_charmed:
		attack_player(attack_damage)

func attack_player(damage):
	_player.take_damage(damage)
	attack_on_cooldown = true
	$Timer.start()

func add_charm(amount: float):
	current_charm = min(current_charm + amount, max_charm)
	print(current_charm)
	if current_charm >= max_charm:
		is_charmed = true
		# Add to charmed group
		add_to_group("charmed_enemies")
		# Remove from regular enemies group
		remove_from_group("enemies")

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	if current_health == 0:
		die()


func die():
	print("You died!") # TODO: Replace with game over logic
	queue_free()
