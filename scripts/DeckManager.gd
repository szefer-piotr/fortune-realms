extends Node3D

@export var card_scene: PackedScene
@export var deal_flip_after_move := true
@export var deal_time := 0.35
@export var deck_size := 24
@export var stack_offset := Vector3(0.0, 0.003, 0.002)

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
		card.translate(stack_offset * float(i))
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
	
	var tw := create_tween()
	tw.tween_property(card, "global_position", target.global_position, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "global_rotation", target.global_rotation, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if deal_flip_after_move and ("flip" in card):
		tw.tween_callback(Callable(card, "flip")).set_delay(0.02)
	
