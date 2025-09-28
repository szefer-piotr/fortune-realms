extends Node3D

const BUILDING_TILE_SCENE := preload("res://scenes/ui/BuildingTile.tscn")

@export var kingdom_config: KingdomConfig

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

        if not kingdom_config:
                push_warning("No kingdom config assigned to Kingdom.")
                return

        if not kingdom_config.environment_scene:
                push_warning("No environment scene assigned in the KingdomConfig resource.")
                return

        if active_environment:
                active_environment.queue_free()
                active_environment = null

        active_environment = kingdom_config.environment_scene.instantiate()
        level_root.add_child(active_environment)

func _wire_ui() -> void:
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)

func _create_building_tiles() -> void:
        if not building_tile_container or not level_root:
                return

        for child in building_tile_container.get_children():
                child.queue_free()

        if not kingdom_config:
                return

        if not active_environment:
                push_warning("Cannot create building tiles without an active environment instance.")
                return

        for building_config in kingdom_config.buildings:
                if building_config == null:
                        continue

                var tile := BUILDING_TILE_SCENE.instantiate()
                building_tile_container.add_child(tile)
                tile.setup(building_config, active_environment)
		
	
func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/PhysicsTable.tscn")
	
