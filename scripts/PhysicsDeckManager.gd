extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/PhysicsCard3d.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 3.0
@export var flip_strength := 6.0

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
	
	var yaw := randf_range(-PI, PI)
	
	card.global_transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI)
	card.rotate_object_local(Vector3.FORWARD, randf_range(-0.05, 0.05))
	card.linear_velocity = Vector3(randf_range(-1.0, 1.0), -1.0, -throw_strength)

	# HORIZONTAL FLIP: spin around *local X* so it goes from PI -> 0 (face-up).
	# HORIZONTAL FLIP: spin around local X so it goes from PI -> 0 (face-up).
	var omega := randf_range(flip_strength - 1.0, flip_strength + 2.0)
	var local_axis := Vector3.RIGHT  # X axis
	card.angular_velocity = card.global_transform.basis * (local_axis * -omega)


	# Optional settling (prevents endless wobble)
	card.angular_damp = 6.0
