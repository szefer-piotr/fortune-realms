extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 2.0
@export var row_spacing := 0.5
@export var flip_strength := TAU * 1
@export var score_tween_duration := 0.14
const MAX_CARDS := 10
const DEAL_DELAY := 0.1
const SCORE_TWEEN_BASE := 0.6
const SCORE_TWEEN_PER_POINT := 0.015
const UI_LAG_MIN := 0.06
const UI_LAG_MAX := 0.2
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
@onready var build_button: TextureButton = $UI/BuildButton
@onready var score_label: Label = $UI/ScoreLabel
@onready var score_bar: TextureProgressBar = $UI/ScoreBar
@onready var total_score_label: Label = $UI/TotalScoreContainer/TotalScoreLabel
@onready var draws_label: Label = $UI/DrawsContainer/DrawsLabel
@onready var attack_overlay: ColorRect = $UI/AttackOverlay

# Runtime
var cards: Array[RigidBody3D] = []
var jackpot_card: RigidBody3D = null
var last_dealt_card : RigidBody3D = null
var last_fall_time := 0.0

var card_count := 0
var round_score := 0
var total_score := 0
var displayed_score := 0
var draws_remaining := 100
var is_round_active := false

var score_update_queue: Array[int] = []
var processing_scores := false
var is_dealing := false
var is_animating := false

func _ready() -> void:
	randomize()
	score_bar.step = 0
	score_bar.max_value = 21
	displayed_score = 0
	_wire_ui()
	_refresh_draws_ui()
	_start_round()
	
func _wire_ui() -> void:
	if draw_button and not draw_button.pressed.is_connected(_on_draw_pressed):
		draw_button.pressed.connect(_on_draw_pressed)
	if hold_button and not hold_button.pressed.is_connected(_on_hold_pressed):
		hold_button.pressed.connect(_on_hold_pressed)
	if build_button and not build_button.pressed.is_connected(_on_build_pressed):
		build_button.pressed.connect(_on_build_pressed)

func _start_round() -> void:
        is_dealing = false
        is_animating = false
        jackpot_card = null
        last_dealt_card = null
        last_fall_time = 0.0
        is_round_active = false
        _refresh_draws_ui()
        _enable_inputs(true, false)

func _enable_inputs(draw: bool, hold: bool) -> void:
        var has_rounds_available := draws_remaining > 0 or is_round_active
        var can_draw := draw and has_rounds_available and not is_dealing and not is_animating
        var can_hold := hold and not is_dealing and not is_animating
        if draw_button:
                draw_button.disabled = not can_draw
        if hold_button:
                hold_button.disabled = not can_hold
	_refresh_draws_ui()
	
	
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
	var ui_delay : float = clamp(fall_time * 0.35, UI_LAG_MIN, UI_LAG_MAX)
	
	var new_score : int = round_score + card.number_value
	
	# Regular toss
	card.linear_velocity = Vector3(0.5, -8.0, -throw_strength)
	card.angular_velocity = Vector3(0.0, 0.0, -flip_strength / max(fall_time, 0.05))
	
	card_count += 1
	round_score = new_score
	_update_combo_effects()
	
	if new_score == 21:
		jackpot_card = card
	
	_queue_score_update(round_score, ui_delay)
	await get_tree().process_frame
	
	
func _update_combo_effects() -> void:
	var counts := {}
	for c in cards:
		if is_instance_valid(c):
			counts[c.icon_type] = int(counts.get(c.icon_type, 0)) + 1

	for c in cards:
		if is_instance_valid(c):
			c.set_highlight(counts.get(c.icon_type, 0) >= 4)
			

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
		
		# compute tween duration based on how many points were just added
		var delta: float = abs(next_score - displayed_score)
		var tween_duration: float = clamp(
			SCORE_TWEEN_BASE + SCORE_TWEEN_PER_POINT * float(delta),
			0.04, 0.22
		)

		score_label.text = str(next_score)
		var target: int = clamp(next_score, 0, 21)
		var tween := create_tween()
		tween.tween_property(score_bar, "value", target, tween_duration)
		await tween.finished
		displayed_score = next_score
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
	total_score_label.text = "%d" % total_score

	await get_tree().create_timer(END_PAUSE).timeout
	
	score_bar.value = 0
	score_label.text = "0"
	displayed_score = 0
	
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
		if is_instance_valid(c):
			c.set_highlight(false)
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

# Build a Basis whose local -Y axis points along `dir` (so the card face, which is -Y, looks at the camera)
func _basis_with_minus_y_facing(dir: Vector3, up_hint: Vector3) -> Basis:
	var forward := dir.normalized()         # we want -Y to align with this
	var y := -forward
	var x := up_hint.cross(y).normalized()
	if x.length() < 0.0001:
		up_hint = Vector3(0, 0, 1)          # fallback if up_hint is parallel to y
		x = up_hint.cross(y).normalized()
	var z := x.cross(y).normalized()

	var b := Basis()
	b.x = x; b.y = y; b.z = z
	return b.orthonormalized()

# Wait until a rigid body sleeps (or timeout)
func _await_body_sleep(body: RigidBody3D, max_wait: float = 1.5) -> void:
	var elapsed := 0.0
	while is_instance_valid(body) and not body.sleeping and elapsed < max_wait:
		await get_tree().physics_frame
		var pps := Engine.get_physics_ticks_per_second()
		elapsed += 1.0 / max(pps, 1.0)


func _play_jackpot_animation() -> void:
	if not jackpot_card:
		return

	# 1) Wait until the jackpot card actually lands (sleeps)
	await _await_body_sleep(jackpot_card, last_fall_time + 0.8)

	# 2) Rotate in place so the card's local -Y faces the camera (reveals face)
	var to_cam := (camera.global_transform.origin - jackpot_card.global_transform.origin).normalized()
	var face_basis := _basis_with_minus_y_facing(to_cam, Vector3.UP)

	var reveal := create_tween()
	reveal.tween_property(jackpot_card, "global_transform:basis", face_basis, 0.18)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await reveal.finished

	# 3) Fly toward a point in front of the camera, keep the same facing
	jackpot_card.linear_velocity = Vector3.ZERO
	jackpot_card.angular_velocity = Vector3.ZERO
	jackpot_card.freeze = true  # stop physics from fighting the pose during the cinematic

	var cam := camera.global_transform
	var distance := 2.0
	var target_pos := cam.origin - cam.basis.z * distance

	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(jackpot_card, "global_transform:origin", target_pos, 0.30)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(jackpot_card, "global_transform:basis", face_basis, 0.30)
	await fly.finished

	# Optional: small sway while showcased
	var base_rot := jackpot_card.rotation
	var offset := 0.12
	var sway := create_tween()
	for i in range(3):
		sway.tween_property(jackpot_card, "rotation", base_rot + Vector3(0.0, offset, 0.0), 0.10)
		sway.tween_property(jackpot_card, "rotation", base_rot - Vector3(0.0, offset, 0.0), 0.10)
	sway.tween_property(jackpot_card, "rotation", base_rot, 0.10)
	await sway.finished

	await get_tree().create_timer(1.0).timeout
	jackpot_card.freeze = false  # give physics back control




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
        if not is_round_active:
                if draws_remaining <= 0:
                        return
                draws_remaining = max(draws_remaining - 1, 0)
                is_round_active = true
                _refresh_draws_ui()
        _lock_inputs()
        await _auto_draw_round()
        await _evaluate_round()

func _refresh_draws_ui() -> void:
        if draws_label:
                draws_label.text = "Rounds: %d" % max(draws_remaining, 0)
        if attack_overlay:
                attack_overlay.visible = draws_remaining <= 0 and not is_round_active

func _on_hold_pressed() -> void:
	if is_dealing or is_animating:
		return
	await _end_round("", round_score)  # no message, just score add

func _on_build_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/kingdoms/FirstKingdom.tscn")
