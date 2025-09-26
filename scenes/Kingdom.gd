extends Node3D

const BUILDING_TILE_SCENE := preload("res://scenes/ui/BuildingTile.tscn")

@onready var play_button: TextureButton = $UI/PlayButton
@onready var building_tile_container: HBoxContainer = $UI/BuildingTileContainer/TileList
@onready var level_root: Node3D = $LevelRoot

func _ready() -> void:
	_wire_ui()
	_create_building_tiles()


func _wire_ui() -> void:
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)


func _create_building_tiles() -> void:
	if not building_tile_container:
		return

	for child in building_tile_container.get_children():
		child.queue_free()

	var buildings: Array[Node3D] = []
	for child in level_root.get_children():
		if child is Node3D and child.name.begins_with("Building"):
			buildings.append(child)
			child.visible = false

	for building in buildings:
		var tile := BUILDING_TILE_SCENE.instantiate()
		building_tile_container.add_child(tile)
		tile.setup(building)
		
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicsTable.tscn")
	
