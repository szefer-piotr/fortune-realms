extends Control

@onready var front: TextureRect = $Front
@onready var back: TextureRect = $Back

var _face_up: bool = false

func show_front() -> void:
    front.visible = true
    back.visible = false
    _face_up = true

func show_back() -> void:
    front.visible = false
    back.visible = true
    _face_up = false

func flip() -> void:
    if _face_up:
        show_back()
    else:
        show_front()

func is_face_up() -> bool:
    return _face_up
