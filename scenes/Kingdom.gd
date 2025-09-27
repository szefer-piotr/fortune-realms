extends Node3D

const BUILDING_TILE_SCENE := preload("res://scenes/ui/BuildingTile.tscn")

@export var environment_scene: PackedScene

var active_environment: Node3D

@onready var play_button: TextureButton = $UI/PlayButton
@onready var building_tile_container: HBoxContainer = $UI/BuildingTileContainer/TileList
@onready var level_root: Node3D = $LevelRoot

func _ready() -> void:
	_instance_environment()
	_wire_ui()
	_create_building_tiles()

func _instance_environment() -> void:
	if not level_root:
		return
		
	if not environment_scene:
		push_warning("No environment scene assigned to Kingdom.")
		return
		
	if active_environment:
		active_environment.queue_free()
		active_environment = null
	
	active_environment = environment_scene.instantiate()
	level_root.add_child(active_environment)

func _wire_ui() -> void:
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)

func _create_building_tiles() -> void:
	if not building_tile_container or not level_root:
		return

	for child in building_tile_container.get_children():
		child.queue_free()

	var buildings:= _find_building_nodes(level_root)
	
	for building in buildings:
		var tile := BUILDING_TILE_SCENE.instantiate()
		building_tile_container.add_child(tile)
		tile.setup(building)
		
func _find_building_nodes(root: Node) -> Array[Node3D]:
	var buildings: Array[Node3D] = []
	
	if not root:
		return buildings
		
	for child in root.get_children():
		if child is Node3D:
			if child.name.begins_with("Building"):
				buildings.append(child)
			buildings.append_array(_find_building_nodes(child))
	
	return buildings
		
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicsTable.tscn")
	
