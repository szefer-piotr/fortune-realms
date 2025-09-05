extends Node3D

@export var card_scene: PackedScene
@export var deal_flip_after_move := true
@export var deal_time := 0.35
@export var flip_time := 0.2
@export var deck_size := 24
@export var stack_offset := Vector3(0.0, 0.03, 0.02)
@export var deck_jitter := Vector3(0.02, 0.02, 0.02)
@export var target_jitter := Vector3(0.22, 0.2, 0.02)

@onready var deck_root: Node3D = $DeckRoot
@onready var deck_spawn: Node3D = $DeckSpawn
@onready var targets_parent: Node3D = $DealTargets
@onready var draw_button: Button = $"../CanvasLayer/DrawButton"

var targets: Array[Node3D] = []
var deck: Array[Node3D] = []
var next_target_idx := 0

func _ready() -> void:
	for c in targets_parent.get_children():
		if c is Node3D:
			targets.append(c as Node3D)
			
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)
		
	_build_deck()
	

func _build_deck() -> void:
	for c in deck:
		if is_instance_valid(c):
			c.queue_free()
	deck.clear()
	next_target_idx = 0
	
	var base := deck_spawn.global_transform
	for i in range(deck_size):
		var card := card_scene.instantiate() as Node3D
		deck_root.add_child(card)
		card.global_transform = base
		card.translate(stack_offset * float(i) + _random_offset(deck_jitter))
		card.rotate_y(deg_to_rad(randf_range(-3.0, 3.0)))
		if "show_back" in card:
			card.call_deferred("show_back")
		deck.push_front(card)
		
func _on_draw_pressed() -> void:
	if deck.is_empty():
		return
	if next_target_idx >= targets.size():
		return

	
	var card: Variant = deck.pop_front()
	var target := targets[next_target_idx]
	next_target_idx += 1

	var dest_pos := target.global_position + _random_offset(target_jitter)
	var tw := create_tween()
	tw.tween_property(card, "global_position", target.global_position, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "global_rotation", target.global_rotation, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if deal_flip_after_move and ("flip" in card):
		tw.tween_callback(Callable(card, "flip").bind(flip_time)).set_delay(0.02)


func _random_offset(range: Vector3) -> Vector3:
	return Vector3(
		randf_range(-range.x, range.x),
		randf_range(-range.y, range.y),
		randf_range(-range.z, range.z)
	)
