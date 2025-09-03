extends RigidBody3D

@onready var front: Sprite3D = $Front
@onready var back: Sprite3D = $Back

var is_face_up := false

func _ready() -> void:
	set_face_up(false)
	
func set_face_up(up: bool) -> void:
	is_face_up = up
	front.visible = up
	back.visible = not up
	
func show_front() -> void: set_face_up(true)
func show_back() -> void: set_face_up(false)

func flip(duration: float = 0.25) -> void:
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "rotation_degrees:y", rotation_degrees.y + 90.0, duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "_toggle_face"))
	tw.tween_property(self, "rotation_degrees:y", rotation_degrees.y + 180.0, duration * 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
func _toggle_face() -> void:
	set_face_up(not is_face_up)
