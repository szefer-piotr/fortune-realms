extends RigidBody3D

var number_value: int = randi_range(1, 6)
@onready var number_label: Label3D = $NumberLabel

func _ready() -> void:
    number_label.text = str(number_value)
