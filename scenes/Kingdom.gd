extends Node3D

@onready var play_button: TextureButton = $UI/PlayButton

func _ready() -> void:
	_wire_ui()
	

func _wire_ui() -> void:
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
		
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicsTable.tscn")
	
