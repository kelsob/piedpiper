extends CharacterBody2D

@export var speed := 60.0
@export var max_health := 100
@export var max_breath := 100.0
@export var breath_depletion_rate := 20.0  # units per second
@export var breath_recovery_rate := 30.0   # units per second
@export var breath_pressure_multiplier := 1.5  # How much breath pressure affects volume
@export var attack_time := 0.01  # Time in seconds for note to reach full volume
@export var release_time := 0.2  # Time in seconds for note to fade out
@export var charm_radius := 60.0  # Radius in pixels for charming enemies
@export var charm_rate := 50.0  # Charm points per second while playing

@onready var tone_player: AudioStreamPlayer = $TonePlayer

const SAMPLE_RATE := 44100
const HARMONICS := 4  # Number of harmonics to generate
const VIBRATO_RATE := 5.0  # Hz
const VIBRATO_DEPTH := 0.1  # Semitones
const BUFFER_SIZE := 1024  # Smaller buffer size for lower latency

var generator := AudioStreamGenerator.new()
var playback: AudioStreamGeneratorPlayback

var current_health := max_health
var current_breath := max_breath
var breath_pressure := 1.0  # Current breath pressure (0.0 to 1.0)

var is_playing_note := false
var current_freq := 0.0
var tone_phase := 0.0
var envelope_phase := 0.0
var envelope_value := 0.0
var vibrato_phase := 0.0

# Define the fingering to frequency map (minor pentatonic + extras)
var fingering_to_freq := {
	# Empty fingering
	[]: 880.0,
	# Single fingerings
	["q"]: 523.25,
	["w"]: 587.33,
	["e"]: 659.25,
	["r"]: 783.99,
	# Double fingerings
	["e", "r"]: 440.0,
	["q", "r"]: 349.23,
	["q", "w"]: 293.66,
	["e", "w"]: 329.63,
	["r", "w"]: 392.0,
	# Triple fingerings
	["e", "q", "r"]: 246.94,
	["e", "r", "w"]: 261.63,
	["q", "r", "w"]: 220.0,
	["e", "q", "w"]: 196.0,
	# Quadruple fingering
	["e", "q", "r", "w"]: 174.61
}

# Octave modifiers
var current_octave := 1.0  # 1.0 = normal, 0.5 = octave down, 2.0 = octave up

func _ready():
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = float(BUFFER_SIZE) / SAMPLE_RATE  # Set smaller buffer for lower latency
	tone_player.stream = generator
	tone_player.play()
	playback = tone_player.get_stream_playback()
	
	# Pre-fill buffer with silence
	while playback.get_frames_available() > 0:
		playback.push_frame(Vector2.ZERO)

func _physics_process(delta):
	handle_movement(delta)
	handle_music_input(delta)
	update_health_ui()
	update_breath_ui()
	handle_charming(delta)

	if is_playing_note and current_breath > 0:
		generate_tone(delta)
	else:
		# Fill buffer with silence when not playing
		while playback.get_frames_available() > 0:
			playback.push_frame(Vector2.ZERO)

func generate_tone(delta):
	var base_freq = current_freq * current_octave
	var vibrato_offset = sin(vibrato_phase) * VIBRATO_DEPTH
	vibrato_phase += VIBRATO_RATE * delta * 2 * PI
	
	# Update envelope
	if envelope_phase < 1.0:
		envelope_phase += delta / attack_time
		envelope_value = min(envelope_phase, 1.0)
	
	var frames_to_fill = playback.get_frames_available()
	if frames_to_fill > 0:
		var effective_freq = base_freq * pow(2.0, vibrato_offset / 12.0)
		var increment = 2.0 * PI * effective_freq / SAMPLE_RATE
		
		for i in range(frames_to_fill):
			var sample = 0.0
			
			# Generate harmonics
			for j in range(HARMONICS):
				var harmonic_freq = effective_freq * (j + 1)
				var harmonic_amplitude = 1.0 / (j + 1)  # Higher harmonics are quieter
				sample += sin(tone_phase * (j + 1)) * harmonic_amplitude
			
			# Apply envelope and breath pressure
			sample *= envelope_value * breath_pressure * breath_pressure_multiplier
			sample = clamp(sample, -1.0, 1.0)
			
			tone_phase += increment
			playback.push_frame(Vector2(sample, sample))

func handle_movement(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var mouse_pos = get_global_mouse_position()
		var direction = (mouse_pos - global_position).normalized()
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func handle_music_input(delta):
	var hole_keys := []

	if Input.is_action_pressed("note_q"): hole_keys.append("q")
	if Input.is_action_pressed("note_w"): hole_keys.append("w")
	if Input.is_action_pressed("note_e"): hole_keys.append("e")
	if Input.is_action_pressed("note_r"): hole_keys.append("r")

	hole_keys.sort()  # Ensure order for lookup
	
	# Debug print to see what combinations are being detected
	if hole_keys.size() > 0:
		print("Current hole keys: ", hole_keys)
		print("Has combination: ", fingering_to_freq.has(hole_keys))
		if fingering_to_freq.has(hole_keys):
			print("Frequency for combination: ", fingering_to_freq[hole_keys])

	if Input.is_action_pressed("breath") and current_breath > 0:
		# Calculate breath pressure based on how long the breath key has been held
		breath_pressure = min(breath_pressure + delta * 2.0, 1.0)
		
		if fingering_to_freq.has(hole_keys):
			var freq = fingering_to_freq[hole_keys]

			if not is_playing_note or freq != current_freq:
				tone_phase = 0.0
				vibrato_phase = 0.0
				envelope_phase = 0.0
				current_freq = freq
				is_playing_note = true
		else:
			# If no valid combination is found, stop the current note
			stop_tone()

		current_breath -= breath_depletion_rate * delta * breath_pressure
	else:
		breath_pressure = max(breath_pressure - delta * 3.0, 0.0)
		stop_tone()
		# Faster breath recovery when not playing
		current_breath += breath_recovery_rate * delta * (1.0 + (1.0 - breath_pressure))

	current_breath = clamp(current_breath, 0, max_breath)

func stop_tone():
	if is_playing_note:
		envelope_phase = 0.0
		envelope_value = 0.0
		is_playing_note = false
		current_freq = 0.0

func take_damage(amount: int):
	current_health = max(current_health - amount, 0)
	if current_health == 0:
		die()

func update_health_ui():
	var health_bar = get_node("../UI/HealthBar")
	if health_bar:
		health_bar.value = current_health

func update_breath_ui():
	var breath_bar = get_node("../UI/BreathBar")
	if breath_bar:
		breath_bar.value = current_breath

func handle_charming(delta):
	if is_playing_note:
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			var distance = global_position.distance_to(enemy.global_position)
			if distance <= charm_radius:
				enemy.add_charm(charm_rate * delta)

func die():
	print("You died!") # TODO: Replace with game over logic
