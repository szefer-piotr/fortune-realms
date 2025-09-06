extends RigidBody3D

@onready var number_label: Label3D = $NumberLabel

func _ready() -> void:
    number_label.text = str(randi_range(1, 6))
