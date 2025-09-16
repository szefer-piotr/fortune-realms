extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 2.0
const MAX_CARDS := 10
const DEAL_DELAY := 0.15
const SCORE_UPDATE_DELAY := 0.01
const DISCARD_ANIMATION_DURATION := 0.5
@export var row_spacing := 0.5
@export var score_tween_duration := 0.25
var card_count := 0
var round_score := 0
var total_score := 0
var score_update_queue: Array[int] = []
var processing_scores := false
var bars_started := false

# Amount of rotation in radians performed during the fall. A default of 270
# degrees makes the card land face up when dropped from the spawn height.
@export var flip_strength := TAU * 1

@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var camera: Camera3D = $Camera3D
@onready var draw_button: TextureButton = $UI/DrawButton
@onready var hold_button: TextureButton = $UI/HoldButton
@onready var score_label: Label = $UI/ScoreLabel
@onready var score_bar: TextureProgressBar = $UI/ScoreBar
@onready var total_score_label: Label = $UI/TotalScoreLabel
@onready var draw_bar = get_node_or_null("$UI/DrawBar")
@onready var hold_bar = get_node_or_null("$UI/HoldBar")
var cards: Array[RigidBody3D] = []
var jackpot_card: RigidBody3D = null

func _ready() -> void:
	randomize()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)
	if hold_button:
		hold_button.pressed.connect(_on_hold_pressed)
	if not draw_bar:
		draw_bar = get_node_or_null("UI/DrawButton/DrawBar")
	if not hold_bar:
		hold_bar = get_node_or_null("UI/HoldButton/HoldBar")
	score_bar.step = 0
	start_round()

func start_round() -> void:
	draw_button.disabled = false
	hold_button.disabled = true
	bars_started = false
	
func _auto_draw_round() -> void:
	var first := true
	while first or round_score < 15:
		if first:
			if not bars_started:
				if draw_bar:
					draw_bar.start()
				if hold_bar:
					hold_bar.start()
				bars_started = true
			first = false
		_deal_card()
		await get_tree().create_timer(DEAL_DELAY).timeout
		if round_score >= 21:
			break

func _deal_card() -> void:
	draw_button.disabled = true
	hold_button.disabled = true
	if card_count >= MAX_CARDS:
		return
	var card := card_scene.instantiate() as RigidBody3D
	add_child(card)
	cards.append(card)

	var tex = card.face_textures[randi_range(0, card.face_textures.size() - 1)]
	card.set_face_texture(tex)
	var pos := deck_spawn.global_transform.origin
	pos.y += spawn_height
	
	# Offset to center deck between the 5th and 6th cards when drawing up to MAX_CARDS
	pos.x += row_spacing * (card_count - (MAX_CARDS - 1) / 2.0)
	pos.z = 0.5
	card.global_transform.origin = pos
	#var rotation = (card_count-5.0)*PI/20.0
	#var rotation = ((7+(card_count/5))*PI)/4
	#var rotation = (9*PI)/4

	card.rotation = Vector3(0.0, 0, 0.0)
	
	var new_score = round_score + card.number_value
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var fall_time := sqrt((2.0 * spawn_height) / gravity)
	
	if new_score == 21:
		await _show_jackpot_card(card, fall_time)
	else:
		card.linear_velocity = Vector3(0.5, -8.0, -throw_strength)
		card.angular_velocity = Vector3(0.0, 0.0, -flip_strength / fall_time)
	
	card_count += 1
	round_score += card.number_value
	var delay := fall_time
	if new_score == 21:
		delay = 0.0
	_queue_score_update(round_score, fall_time)
	
func _show_jackpot_card(card: RigidBody3D, fall_time: float) -> void:
	jackpot_card = card
	card.linear_velocity = Vector3(0.5, -8.0, -throw_strength)
	card.angular_velocity = Vector3(0.0, 0.0, -flip_strength / fall_time)
	await get_tree().create_timer(fall_time).timeout
	card.linear_velocity = Vector3.ZERO
	card.angular_velocity = Vector3.ZERO
	var cam_transform := camera.global_transform
	var distance := 2.0
	var target_pos := cam_transform.origin - cam_transform.basis.z * distance
	card.look_at(cam_transform.origin, Vector3(0, 0, 0), true)
	var slide := create_tween()
	slide.tween_property(card, "global_transform:origin", target_pos, 0.3)
	await slide.finished
	var base_rot := card.rotation
	var offset := 0.1
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(card, "rotation", base_rot + Vector3(0.0, offset, 0.0), 0.1)
		tween.tween_property(card, "rotation", base_rot - Vector3(0.0, offset, 0.0), 0.1)
	tween.tween_property(card, "rotation", base_rot, 0.1)
	await tween.finished


func _queue_score_update(value: int, delay: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(func():
		score_update_queue.push_back(value)
		if !processing_scores:
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

func _evaluate_round() -> void:
	while processing_scores:
		await get_tree().process_frame
	if round_score == 21:
		_end_round("JACKPOT", 100)
	elif round_score > 21:
		_end_round("BUST", 0)
	else:
		draw_button.disabled = false
		hold_button.disabled = round_score < 18
		
func _on_draw_pressed() -> void:
	draw_button.disabled = true
	await _auto_draw_round()
	_evaluate_round()

func _on_hold_pressed() -> void:
	_end_round("", round_score)
	
func _end_round(message: String, points: int) -> void:
	draw_button.disabled = true
	hold_button.disabled = true
	score_update_queue.clear()
	processing_scores = false
	if message != "":
		score_label.text = message
	total_score += points
	total_score_label.text = "Total: %d" % total_score
	for card in cards:
		if card == jackpot_card:
			continue
		card.linear_velocity = Vector3(-5.0, 2.0, 0.0)
		card.angular_velocity = Vector3(0.0, 5.0, 0.0)
	await get_tree().create_timer(DISCARD_ANIMATION_DURATION).timeout
	score_bar.value = 0
	score_label.text = "0"
	for card in cards:
		if card:
			card.queue_free()
	cards.clear()
	card_count = 0
	round_score = 0
	start_round()
