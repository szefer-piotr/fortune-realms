extends Node3D

@export var card_scene: PackedScene = preload("res://scenes/Card3D.tscn")
@export var spawn_height := 2.0
@export var throw_strength := 5.0

# Amount of rotation in radians performed during the fall. A default of 270
# degrees makes the card land face up when dropped from the spawn height.
@export var flip_strength := TAU * 1

@onready var deck_spawn: Marker3D = $DeckSpawn
@onready var draw_button: Button = $UI/DrawButton

func _ready() -> void:
		randomize()
		if draw_button:
				draw_button.pressed.connect(_on_draw_pressed)

func _on_draw_pressed() -> void:
	var card := card_scene.instantiate() as RigidBody3D
	add_child(card)

	var tex = card.face_textures[randi_range(0, card.face_textures.size() - 1)]
	card.set_face_texture(tex)

	var pos := deck_spawn.global_transform.origin
	pos.y += spawn_height
	card.global_transform.origin = pos
	card.rotation = Vector3(0.0, randf_range(-0.1*PI, 0.1*PI), 0.0)
	card.linear_velocity = Vector3(randf_range(-1.0, 1.0), -6.0, -throw_strength)
	var gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
	var fall_time := sqrt((2.0 * spawn_height) / gravity)
	card.angular_velocity = Vector3(0.0, 0.0, flip_strength / fall_time)
