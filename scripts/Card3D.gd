extends RigidBody3D

@export var face_textures: Array[Texture2D] = [
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/coins.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/draws.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/thief.png"),
]

var number_value: int = 0

@onready var number_label: Label3D = $NumberLabel

func _ready() -> void:
	number_value = randi_range(1, 6)
	number_label.text = str(number_value)

func set_face_texture(tex: Texture2D) -> void:
	var mat : StandardMaterial3D = $Front.material_override
	mat = mat.duplicate() if mat else StandardMaterial3D.new()
	mat.albedo_texture = tex
	$Front.material_override = mat
