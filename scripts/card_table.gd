extends Control

var card_scene: PackedScene = preload("res://scenes/Card.tscn")
@export var deal_flip_after_move := true
@export var deal_time := 0.35
@export var deck_size := 24
@export var stack_offset := Vector2(0.0, -2.0)

@onready var deck_root: Control = self
@onready var deck_spawn: Control = $DeckSpawn
@onready var targets_parent: Control = $DealTargets
@onready var draw_button: Button = $UI/DrawButton

var targets: Array[Control] = []
var deck: Array[Control] = []
var next_target_idx := 0

func _ready() -> void:
	_collect_or_create_targets()
	_build_deck()
	if draw_button:
		draw_button.pressed.connect(_on_draw_pressed)

func _collect_or_create_targets() -> void:
	targets.clear()
	for c in targets_parent.get_children():
		if c is Control:
			targets.append(c)
	if targets.is_empty():
		for i in range(5):
			var slot := Control.new()
			targets_parent.add_child(slot)
			slot.position = Vector2(110 * i, 0)
			targets.append(slot)

func _build_deck() -> void:
	for c in deck:
		if is_instance_valid(c):
			c.queue_free()
	deck.clear()
	next_target_idx = 0

	var base := deck_spawn.global_position
	for i in range(deck_size):
		var card := card_scene.instantiate() as Control
		deck_root.add_child(card)
		card.global_position = base + stack_offset * float(i)
		card.rotation = deg_to_rad(randf_range(-3.0, 3.0))
		if "show_back" in card:
			card.call_deferred("show_back")
		deck.push_front(card)

func _on_draw_pressed() -> void:
	if deck.is_empty():
		return
	if next_target_idx >= targets.size():
		return

	var card: Control = deck.pop_front()
	var target: Control = targets[next_target_idx]
	next_target_idx += 1

	var tw := create_tween()
	tw.tween_property(card, "global_position", target.global_position, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(card, "global_rotation", target.global_rotation, deal_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if deal_flip_after_move and ("flip" in card):
		tw.tween_callback(Callable(card, "flip")).set_delay(0.02)
