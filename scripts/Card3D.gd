extends RigidBody3D

const FACE_TEXTURES := [
    preload("res://assets/cards_png/gpt_game_assets/cards_simple/coins.png"),
    preload("res://assets/cards_png/gpt_game_assets/cards_simple/thief.png"),
]

var number_value: int

@onready var number_label: Label3D = $NumberLabel
@onready var front: MeshInstance3D = $Front

func _ready() -> void:
    number_value = randi_range(1, 6)
    number_label.text = str(number_value)

    var texture := FACE_TEXTURES[randi() % FACE_TEXTURES.size()]
    var mat := front.get_active_material(0).duplicate()
    mat.albedo_texture = texture
    front.material_override = mat
