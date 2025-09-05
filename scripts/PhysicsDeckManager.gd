extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/PhysicsCard3d.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 3.0

@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var draw_button: Button = $UI/DrawButton

func _ready() -> void:
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)

func _on_draw_pressed() -> void:
	var card := card_scene.instantiate() as RigidBody3D
	add_child(card)
	var pos := deck_spawn.global_transform.origin
	pos.y += spawn_height
	card.global_transform.origin = pos
	card.rotation = Vector3(0.0, randf_range(-PI, PI), 0.0)
	card.linear_velocity = Vector3(randf_range(-1.0, 1.0), -1.0, -throw_strength)
