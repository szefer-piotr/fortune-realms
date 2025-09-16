extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 2.0
@export var row_spacing := 0.5
@export var flip_strength := TAU * 1
@export var score_tween_duration := 0.14
const MAX_CARDS := 10
const DEAL_DELAY := 0.05
const DISCARD_ANIMATION_DURATION := 0.5
const SCORE_UPDATE_DELAY := 0.01
const LAND_FALLBACK_PAD := 0.2 
const BUST_JIGGLE_STRENGTH := 6.0
const BUST_JIGGLE_REPEAT := 2
const END_PAUSE := 0.35
const SCATTER_SPEED := 12.0

# Nodes
@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var camera: Camera3D = $Camera3D
@onready var draw_button: TextureButton = $UI/DrawButton
@onready var hold_button: TextureButton = $UI/HoldButton
@onready var score_label: Label = $UI/ScoreLabel
@onready var score_bar: TextureProgressBar = $UI/ScoreBar
@onready var total_score_label: Label = $UI/TotalScoreLabel

# Runtime
var cards: Array[RigidBody3D] = []
var jackpot_card: RigidBody3D = null
var last_dealt_card : RigidBody3D = null
var last_fall_time := 0.0

var card_count := 0
var round_score := 0
var total_score := 0

var score_update_queue: Array[int] = []
var processing_scores := false
var is_dealing := false
var is_animating := false

func _ready() -> void:
	randomize()
	score_bar.step = 0
	_wire_ui()
	_start_round()
	
func _wire_ui() -> void:
	if draw_button and not draw_button.pressed.is_connected(_on_draw_pressed):
		draw_button.pressed.connect(_on_draw_pressed)
	if hold_button and not hold_button.pressed.is_connected(_on_hold_pressed):
		hold_button.pressed.connect(_on_hold_pressed)

func _start_round() -> void:
	is_dealing = false
	is_animating = false
	jackpot_card = null
	last_dealt_card = null
	last_fall_time = 0.0
	_enable_inputs(true, false)

func _enable_inputs(draw: bool, hold: bool) -> void:
	if draw_button:
		draw_button.disabled = not draw or is_dealing or is_animating
	if hold_button:
		hold_button.disabled = not hold or is_dealing or is_animating
	
	
func _lock_inputs() -> void:
	if draw_button: draw_button.disabled = true
	if hold_button: hold_button.disabled = true
	
	
# Core dealing logic

func _auto_draw_round() -> void:
	is_dealing = true
	var first := true
	while first or round_score < 15:
		first = false
		if card_count >= MAX_CARDS: break
		await _deal_card()
		await get_tree().create_timer(DEAL_DELAY).timeout
		if round_score >= 21: break
	is_dealing = false

func _deal_card() -> void:
	_lock_inputs()
	var card := card_scene.instantiate() as RigidBody3D
	add_child(card)
	cards.append(card)
	last_dealt_card = card
	
	# Pick texture
	var tex = card.face_textures[randi_range(0, card.face_textures.size() - 1)]
	card.set_face_texture(tex)
	
	# Spawn position
	var pos := deck_spawn.global_transform.origin
	pos.y += spawn_height
	pos.x += row_spacing * (card_count - (MAX_CARDS - 1) / 2.0)
	pos.z = 0.5
	card.global_transform.origin = pos

	card.rotation = Vector3(0.0, 0, 0.0)
	
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var fall_time := sqrt((2.0 * spawn_height) / gravity)
	last_fall_time = fall_time
	
	var new_score : int = round_score + card.number_value
	
	# Regular toss
	card.linear_velocity = Vector3(0.5, -8.0, -throw_strength)
	card.angular_velocity = Vector3(0.0, 0.0, -flip_strength / fall_time)
	
	card_count += 1
	round_score += card.number_value
	
	if new_score == 21:
		jackpot_card = card
	
	_queue_score_update(round_score, fall_time)
	await get_tree().create_timer(fall_time).timeout
	

# Score UI updates
func _queue_score_update(value: int, delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		score_update_queue.push_back(value)
		if not processing_scores:
			_process_score_queue.call_deferred()
	)
	
func _process_score_queue() -> void:
	processing_scores = true
	while score_update_queue.size() > 0:
		var next_score: int = score_update_queue.pop_front()
		score_label.text = str(next_score)
		var target: int = clamp(next_score, 0, 21)
		var tween := create_tween()
		tween.tween_property(score_bar, "value", target, score_tween_duration)
		await tween.finished
		await get_tree().create_timer(SCORE_UPDATE_DELAY).timeout
	processing_scores = false
	
	#End-state evaluation
func _evaluate_round() -> void:
	while processing_scores:
		await get_tree().process_frame
		
	if round_score == 21:
		await _end_round("JACKPOT", 100, true, false)
	elif round_score > 21:
		await _await_last_card_land()
		await _end_round("BUST", 0, false, true)
	else:
		_enable_inputs(true, round_score >= 18)

func _await_last_card_land() -> void:
	if last_dealt_card:
		var elapsed := 0.0
		var max_wait := last_fall_time + LAND_FALLBACK_PAD
		while not last_dealt_card.sleeping and elapsed < max_wait:
			await get_tree().physics_frame
			elapsed += (1.0 / Engine.get_physics_ticks_per_second()) if Engine.get_physics_ticks_per_second() > 0 else 0.016
	await get_tree().create_timer(0.05).timeout

func _end_round(message: String, points: int, is_jackpot: bool = false, is_bust: bool = false) -> void:
	is_animating = true
	_lock_inputs()
	score_update_queue.clear()
	processing_scores = false
	
	if message != "":
		score_label.text = message
	
	if is_bust:
		await _play_bust_animation()
	elif is_jackpot:
		await _play_jackpot_animation()
	
	total_score += points
	total_score_label.text = "Total: %d" % total_score

	await get_tree().create_timer(END_PAUSE).timeout
	
	score_bar.value = 0
	score_label.text = "0"
	
	for card in cards:
		if card:
			card.queue_free()
	cards.clear()
	
	card_count = 0
	round_score = 0
	jackpot_card = null
	last_dealt_card = null
	is_animating = false
	
	_start_round()


func _play_bust_animation() -> void:
	# 1) Jiggle the progress bar
	await _jiggle_progress_bar()

	# 2) Scatter all cards
	for c in cards:
		if not is_instance_valid(c): continue
		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.3, 1.2),
			randf_range(-1.0, 1.0)
		).normalized()
		c.linear_velocity = dir * SCATTER_SPEED
		c.angular_velocity = Vector3(
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0),
			randf_range(-6.0, 6.0)
		)

	await get_tree().create_timer(0.6).timeout


func _play_jackpot_animation() -> void:
	
	if not jackpot_card:
		await get_tree().create_timer(1).timeout
		return

	jackpot_card.linear_velocity = Vector3.ZERO
	jackpot_card.angular_velocity = Vector3.ZERO

	var cam_transform := camera.global_transform
	var distance := 2.0
	var target_pos := cam_transform.origin - cam_transform.basis.z * distance
	jackpot_card.look_at(cam_transform.origin, Vector3.ZERO, true)

	var slide := create_tween()
	slide.tween_property(jackpot_card, "global_transform:origin", target_pos, 0.3)
	await slide.finished

	var base_rot := jackpot_card.rotation
	var offset := 0.12
	var t := create_tween()
	for i in range(3):
		t.tween_property(jackpot_card, "rotation", base_rot + Vector3(0.0, offset, 0.0), 0.1)
		t.tween_property(jackpot_card, "rotation", base_rot - Vector3(0.0, offset, 0.0), 0.1)
	t.tween_property(jackpot_card, "rotation", base_rot, 0.1)
	
	#_spawn_confetti(jackpot_card.global_transform.origin + Vector3(0, 0.1, 0))
	await t.finished

	await get_tree().create_timer(1).timeout

func _jiggle_progress_bar() -> void:
	if not score_bar: return
	var t := create_tween()
	for i in range(BUST_JIGGLE_REPEAT):
		t.tween_property(score_bar, "rotation_degrees", BUST_JIGGLE_STRENGTH, 0.07)
		t.tween_property(score_bar, "rotation_degrees", -BUST_JIGGLE_STRENGTH, 0.09)
	t.tween_property(score_bar, "rotation_degrees", 0.0, 0.08)
	await t.finished


# UI events

func _on_draw_pressed() -> void:
	if is_dealing or is_animating:
		return
	_lock_inputs()
	await _auto_draw_round()
	await _evaluate_round()

func _on_hold_pressed() -> void:
	if is_dealing or is_animating:
		return
	await _end_round("", round_score)  # no message, just score add

#func _spawn_confetti(at: Vector3) -> void:
	#var p := CPUParticles3D.new()
	#p.one_shot = true
	#p.amount = 180
	#p.lifetime = 1.2
	#p.local_coords = true
	#p.emitting = false
	#p.transform.origin = at
	#
	#p.color_ramp = _make_confetti_ramp()   # <-- expects GradientTexture1D
	#add_child(p)
	#p.emitting = true
#
	#var quad := QuadMesh.new()
	#quad.size = Vector2(0.12, 0.12)
	#p.mesh = quad
#
	## Particle params set directly on CPUParticles3D in Godot 4.x
	#p.direction = Vector3(0, 1, 0)
	#p.spread = 85.0
	#p.initial_velocity_min = 8.0
	#p.initial_velocity_max = 14.0
	#p.angular_velocity_min = -8.0
	#p.angular_velocity_max = 8.0
	#p.gravity = Vector3(0, -7.5, 0)
	#p.scale_min = 0.08
	#p.scale_max = 0.16
#
	## Build the gradient, then wrap it in a GradientTexture1D
	#var grad := Gradient.new()
	#grad.add_point(0.0,  Color.html("#ff5470"))
	#grad.add_point(0.25, Color.html("#ffd166"))
	#grad.add_point(0.5,  Color.html("#06d6a0"))
	#grad.add_point(0.75, Color.html("#118ab2"))
	#grad.add_point(1.0,  Color.WHITE)
#
	#var ramp := GradientTexture1D.new()
	#ramp.gradient = grad
	#p.color_ramp = ramp   # <- expects GradientTexture1D
#
	#add_child(p)
	#p.emitting = true
	#await get_tree().create_timer(p.lifetime + 0.5).timeout
	#if is_instance_valid(p):
		#p.queue_free()
#
#func _make_confetti_ramp() -> GradientTexture1D:
	#var grad: Gradient = Gradient.new()
	#grad.add_point(0.00, Color.html("#ff5470"))
	#grad.add_point(0.25, Color.html("#ffd166"))
	#grad.add_point(0.50, Color.html("#06d6a0"))
	#grad.add_point(0.75, Color.html("#118ab2"))
	#grad.add_point(1.00, Color.WHITE)
#
	#var ramp: GradientTexture1D = GradientTexture1D.new()
	#ramp.gradient = grad
	#return ramp
