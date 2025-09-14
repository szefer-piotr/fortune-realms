extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 2.0
const MAX_CARDS := 10
const DEAL_DELAY := 0.001
const SCORE_UPDATE_DELAY := 0.1
@export var row_spacing := 0.5
var card_count := 0
var round_score := 0
var total_score := 0
var score_update_queue: Array[int] = []
var processing_scores := false

# Amount of rotation in radians performed during the fall. A default of 270
# degrees makes the card land face up when dropped from the spawn height.
@export var flip_strength := TAU * 1

@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var draw_button: TextureButton = $UI/DrawButton
@onready var hold_button: TextureButton = $UI/HoldButton
@onready var score_label: Label = $UI/ScoreLabel
@onready var score_bar: TextureProgressBar = $UI/ScoreBar
@onready var total_score_label: Label = $UI/TotalScoreLabel
var cards: Array[RigidBody3D] = []

func _ready() -> void:
	randomize()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)
	if hold_button:
		hold_button.pressed.connect(_on_hold_pressed)
	score_bar.step = 0
	start_round()

func start_round() -> void:
	draw_button.disabled = false
	hold_button.disabled = true
	
func _auto_draw_round() -> void:
	var first := true
	while first or round_score < 15:
		first = false
		await _deal_card()
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
	pos.z = 0
	card.global_transform.origin = pos
	card.rotation = Vector3(0.0, randf_range(-0.1*PI, 0.1*PI), 0.0)
	card.linear_velocity = Vector3(0.5, -10.0, -throw_strength)
	
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var fall_time := sqrt((2.0 * spawn_height) / gravity)
	
	card.angular_velocity = Vector3(0.0, 0.0, flip_strength / fall_time)
	card_count += 1
	await get_tree().create_timer(fall_time).timeout
	round_score += card.number_value
	score_update_queue.push_back(round_score)
	if !processing_scores:
		_process_score_queue.call_deferred()

func _process_score_queue() -> void:
	processing_scores = true
	while score_update_queue.size() > 0:
		var next_score: int = score_update_queue.pop_front()
		score_label.text = str(next_score)
		var target: int = clamp(next_score, 0, 21)
		var tween := create_tween()
		tween.tween_property(score_bar, "value", target, 0.5)
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
		card.linear_velocity = Vector3(5.0, 2.0, 0.0)
		card.angular_velocity = Vector3(0.0, 5.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	for card in cards:
		if card:
			card.queue_free()
	cards.clear()
	card_count = 0
	round_score = 0
	score_bar.value = 0
	await get_tree().create_timer(1.0).timeout
	score_label.text = "0"
	start_round()
