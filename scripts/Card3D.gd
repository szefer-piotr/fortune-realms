extends RigidBody3D

var number_value: int = 0

@onready var number_label: Label3D = $NumberLabel

func _ready() -> void:
        number_value = randi_range(1, 6)
        assert(number_label != null)
        number_label.text = str(number_value)
