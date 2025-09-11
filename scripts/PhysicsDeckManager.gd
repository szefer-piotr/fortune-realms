extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 2.0
const MAX_CARDS := 10
@export var row_spacing := 0.5
var card_count := 0

# Amount of rotation in radians performed during the fall. A default of 270
# degrees makes the card land face up when dropped from the spawn height.
@export var flip_strength := TAU * 1

@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var draw_button: Button = $UI/DrawButton
@onready var hold_button: Button = $UI/HoldButton
var cards: Array[RigidBody3D] = []

func _ready() -> void:
	randomize()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)
	if hold_button:
		hold_button.pressed.connect(_on_hold_pressed)

func _on_draw_pressed() -> void:
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
	print(pos)
	card.global_transform.origin = pos
	card.rotation = Vector3(0.0, randf_range(-0.1*PI, 0.1*PI), 0.0)
	card.linear_velocity = Vector3(0.5, -6.0, -throw_strength)
	
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var fall_time := sqrt((2.0 * spawn_height) / gravity)
	card.angular_velocity = Vector3(0.0, 0.0, flip_strength / fall_time)
	card_count += 1

func _on_hold_pressed() -> void:
	draw_button.disabled = true
	hold_button.disabled = true
	for card in cards:
		card.linear_velocity = Vector3(5.0, 2.0, 0.0)
		card.angular_velocity = Vector3(0.0, 5.0, 0.0)
	await get_tree().create_timer(0.5).timeout
	for card in cards:
		if card:
			card.queue_free()
	cards.clear()
	card_count = 0
