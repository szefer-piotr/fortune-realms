extends Control

const CARD_TEXTURES: Dictionary = {
	1: preload("res://assets/cards_png/Tarot Cats/1. The Magician.png"),
	2: preload("res://assets/cards_png/Tarot Cats/2. The Priestess.png"),
	3: preload("res://assets/cards_png/Tarot Cats/3. The Empress.png"),
	4: preload("res://assets/cards_png/Tarot Cats/4. The Emperor.png"),
	5: preload("res://assets/cards_png/Tarot Cats/5. The Hierophant.png"),
	6: preload("res://assets/cards_png/Tarot Cats/6. The Lovers.png"),
}

var mouse_in: bool = false
var is_dragging: bool = false
var value := ""

func set_number(num: int) -> void:
		$NumberLabel.text = str(num)
		var tex: Texture2D = CARD_TEXTURES.get(num, null)
		if tex:
				$Sprite2D.texture = tex
				$Sprite2D/Shadow.texture = tex

func set_value(v):
		value = str(v)
		if typeof(v) == TYPE_INT:
				set_number(v)
		else:
				$NumberLabel.text = value

func _physics_process(delta: float) -> void:
	drag_logic(delta)

func drag_logic(delta: float) -> void:
	$Sprite2D/Shadow.position = Vector2(-12,12).rotated($Sprite2D.rotation)
	if (mouse_in or is_dragging) and (Mousebrain.node_being_dragged == null or Mousebrain.node_being_dragged == self):
		if Input.is_action_pressed("click"):
			global_position = lerp(global_position, get_global_mouse_position() - (size/2.0), 22.0*delta)
			_change_scale(Vector2(0.06, 0.06))
			_set_rotation(delta)
			$Sprite2D.z_index = 100
			is_dragging = true
			Mousebrain.node_being_dragged == self
		else:
			_change_scale(Vector2(0.06, 0.06))
			$Sprite2D.rotation_degrees = lerp($Sprite2D.rotation_degrees, 0.0, 22.0*delta)
			is_dragging = false
			if Mousebrain.node_being_dragged == self:
				Mousebrain.node_being_dragged = null
		return
		
	$Sprite2D.z_index = 0
	_change_scale(Vector2(0.05, 0.05))

func _on_mouse_entered() -> void:
	mouse_in = true

func _on_mouse_exited() -> void:
	mouse_in = false

var current_goal_scale: Vector2 = Vector2(0.1, 0.1)
var scale_tween: Tween
func _change_scale(desired_scale: Vector2):
	if desired_scale == current_goal_scale:
		return
	if scale_tween:
		scale_tween.kill()
	scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property($Sprite2D, "scale", desired_scale, 0.125)
	current_goal_scale = desired_scale

var last_pos: Vector2
var max_card_rotation: float = 12.5
func _set_rotation(delta: float) -> void:
	var desired_rotation: float = clamp((global_position - last_pos).x*0.05, -max_card_rotation, max_card_rotation)
	$Sprite2D.rotation_degrees = lerp($Sprite2D.rotation_degrees, desired_rotation, 12.0*delta)
	last_pos = global_position
