extends Control

@onready var icon_rect: TextureRect = $Content/IconContainer/Icon
@onready var spawn_button: TextureButton = $Content/SpawnButton

var building_config: BuildingConfig
var spawn_point: Node3D
var active_building: Node3D

func setup(config: BuildingConfig, spawn: Node3D) -> void:
	building_config = config
	spawn_point = spawn
	if active_building:
		active_building.queue_free()
		active_building = null
	_update_icon()
	spawn_button.disabled = not _can_spawn()
	spawn_button.hint_tooltip = building_config.display_name if building_config else ""
	if not spawn_button.pressed.is_connected(_on_spawn_pressed):
		spawn_button.pressed.connect(_on_spawn_pressed)


func _update_icon() -> void:
	if not icon_rect:
		return

	var texture: Texture2D = null

	if building_config:
		for level_config in building_config.levels:
			if level_config and level_config.icon:
				texture = level_config.icon
				break

	icon_rect.texture = texture
	icon_rect.visible = texture != null


func _can_spawn() -> bool:
	return building_config != null and spawn_point != null and building_config.levels.size() > 0


func _on_spawn_pressed() -> void:
	if not _can_spawn():
		push_warning("Cannot spawn building without a valid config, spawn point, and level definition.")
		return

	if active_building:
		return

	var level_config: BuildingLevelConfig = null

	for level in building_config.levels:
		if level and level.scene:
			level_config = level
			break

	if not level_config:
		push_warning("No valid scene found for building '%s'." % building_config.display_name)
		return

	active_building = level_config.scene.instantiate()
	spawn_point.add_child(active_building)
	spawn_button.disabled = true
