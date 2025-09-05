extends Control

@onready var front: TextureRect = $Front
@onready var back: TextureRect = $Back

@export var flip_time := 0.2
var _face_up: bool = false
var _base_scale: Vector2

func _ready() -> void:
        _center_pivot()
        _base_scale = scale
        resized.connect(_center_pivot)

func _center_pivot() -> void:
	pivot_offset = size / 2

func _ready() -> void:
	_center_pivot()
	resized.connect(_center_pivot)

func _center_pivot() -> void:
	pivot_offset = size / 2

func show_front() -> void:
	front.visible = true
	back.visible = false
	_face_up = true

func show_back() -> void:
	front.visible = false
	back.visible = true
	_face_up = false

func flip(duration: float = flip_time) -> void:
  scale = _base_scale
  var tw := create_tween()
  tw.tween_property(self, "scale:x", 0.0, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
  tw.tween_callback(Callable(self, "_swap_face"))
  tw.tween_property(self, "scale:x", _base_scale.x, duration / 2).set_trans(Tween.TRANS_SINE).set_ease

func _swap_face() -> void:
	if _face_up:
		show_back()
	else:
		show_front()

func is_face_up() -> bool:
	return _face_up
