extends Control

@export var card_scene: PackedScene = preload("res://scenes/Card.tscn")
@export var deal_time := 0.35
@export var deck_size := 24
@export var stack_offset := Vector2(0.0, -2.0)

@onready var deck_spawn: Control = $DeckSpawn
@onready var targets_parent: Control = $DealTargets
@onready var draw_button: Button = $"UI/DrawButton"

var targets: Array[Control] = []
var deck: Array[Control] = []
var next_target_idx := 0

func _ready() -> void:
        for c in targets_parent.get_children():
                if c is Control:
                        targets.append(c as Control)
        draw_button.pressed.connect(_on_draw_pressed)
        _build_deck()

func _build_deck() -> void:
        for c in deck:
                if is_instance_valid(c):
                        c.queue_free()
        deck.clear()
        next_target_idx = 0
        for i in range(deck_size):
                var card := card_scene.instantiate() as Control
                add_child(card)
                card.global_position = deck_spawn.global_position + stack_offset * float(i)
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
        if "flip" in card:
                tw.tween_callback(Callable(card, "flip"))
