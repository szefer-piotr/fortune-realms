extends Control

var card_scene: PackedScene = preload("res://scenes/card.tscn")
var total_score := 0
var current_score := 0
var cards := []
var current_card: Control

func _ready():
	randomize()
        $DrawButton.pressed.connect(_on_draw_pressed)
        $HoldButton.pressed.connect(_on_hold_pressed)
        $AceMenu.id_pressed.connect(_on_ace_selected)
        $StarMenu.id_pressed.connect(_on_star_selected)
        $ScoreLabel.text = "Score: 0 | Total: 0"
        $AceMenu.add_item("1", 1)
        $AceMenu.add_item("10", 10)
        for i in range(1, 11):
                $StarMenu.add_item(str(i), i)
        call_deferred("_setup_buttons")

func _setup_buttons():
        for button in [$DrawButton, $HoldButton]:
                button.button_down.connect(_on_button_down.bind(button))
                button.button_up.connect(_on_button_up.bind(button))
                _make_button_round(button)
                button.pivot_offset = button.size / 2

func _on_draw_pressed():
        while current_score <= 15:
                var num := randi() % 6 + 1
                var card = card_scene.instantiate()
                $CardsContainer.add_child(card)
                card.position = Vector2(cards.size() * 60, 0)
                cards.append(card)
                card.set_number(num)
                current_card = card
                current_score += num
        _update_score()

func _on_ace_selected(id):
        current_card.set_value(id)
        current_score += id
        _update_score()

func _on_star_selected(id):
        current_card.set_value(id)
        current_score += id
        _update_score()

func _on_hold_pressed():
        total_score += current_score
        current_score = 0
        for card in cards:
                card.queue_free()
        cards.clear()
        _update_score()

func _update_score():
        $ScoreLabel.text = "Score: %d | Total: %d" % [current_score, total_score]

func _on_button_down(button):
        button.scale = Vector2(0.9, 0.9)

func _on_button_up(button):
        button.scale = Vector2(1, 1)

func _make_button_round(button):
        for state in ["normal", "hover", "pressed"]:
                var sb = button.get_theme_stylebox(state)
                if sb:
                        sb = sb.duplicate()
                        if sb is StyleBoxFlat:
                                sb.corner_radius_all = max(button.size.x, button.size.y)
                        button.add_theme_stylebox_override(state, sb)
