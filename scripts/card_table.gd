extends Control

var card_scene: PackedScene = preload("res://scenes/card.tscn")
var total_score := 0
var cards := []
var current_card: Control

func _ready():
	randomize()
	$DrawButton.pressed.connect(_on_draw_pressed)
	$HoldButton.pressed.connect(_on_hold_pressed)
	$AceMenu.id_pressed.connect(_on_ace_selected)
	$StarMenu.id_pressed.connect(_on_star_selected)
	$ScoreLabel.text = "Score: 0"
	$AceMenu.add_item("1", 1)
	$AceMenu.add_item("10", 10)
	for i in range(1, 11):
		$StarMenu.add_item(str(i), i)

func _on_draw_pressed():
	var values = [1,2,3,4,5,6,7,8,9,10,"A","Star"]
	var choice = values[randi() % values.size()]
	var card = card_scene.instantiate()
	$CardsContainer.add_child(card)
	card.position = Vector2(cards.size() * 60, 0)
	cards.append(card)
	card.set_value(choice)
	if choice == "A":
		current_card = card
		$AceMenu.popup()
	elif choice == "Star":
		current_card = card
		$StarMenu.popup()
	else:
		total_score += int(choice)
		_update_score()

func _on_ace_selected(id):
	current_card.set_value(id)
	total_score += id
	_update_score()

func _on_star_selected(id):
	current_card.set_value(id)
	total_score += id
	_update_score()

func _on_hold_pressed():
	$DrawButton.disabled = true

func _update_score():
	$ScoreLabel.text = "Score: %d" % total_score
