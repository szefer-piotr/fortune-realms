extends Control

@onready var icon_rect: TextureRect = $Content/IconContainer/Icon
@onready var name_label: Label = $Content/NameLabel
@onready var cost_label: Label = $Content/CostLabel
@onready var spawn_button: TextureButton = $Content/SpawnButton
@onready var spawn_label: Label = $Content/SpawnButton/Label

var building_config: BuildingConfig
var environment_root: Node
var spawn_point: Node3D
var active_building: Node3D
var active_level_index: int = -1
var placeholders_hidden: bool = false
var spawn_warning_emitted: bool = false

func setup(config: BuildingConfig, environment: Node = null, spawn_override: Node3D = null) -> void:
	building_config = config
	environment_root = environment
	spawn_point = spawn_override
	active_level_index = -1
	placeholders_hidden = false
	spawn_warning_emitted = false

	if active_building and is_instance_valid(active_building):
		active_building.queue_free()
		active_building = null

	_ensure_spawn_point()
	_update_ui()

	if spawn_button:
		spawn_button.tooltip_text = building_config.display_name if building_config else ""
	if not spawn_button.pressed.is_connected(_on_spawn_pressed):
		spawn_button.pressed.connect(_on_spawn_pressed)


func _ensure_spawn_point() -> void:
	if spawn_point:
		return

	if not building_config:
		return

	if not environment_root:
		return

	if building_config.spawn_point_path.is_empty():
		if not spawn_warning_emitted:
			push_warning("Building '%s' is missing a spawn point path." % building_config.display_name)
			spawn_warning_emitted = true
		return

	var found := environment_root.get_node_or_null(building_config.spawn_point_path)
	if found and found is Node3D:
		spawn_point = found
	else:
		if not spawn_warning_emitted:
			push_warning("Spawn point '%s' not found for building '%s'." % [
				String(building_config.spawn_point_path),
				building_config.display_name
			])
			spawn_warning_emitted = true


func _update_ui() -> void:
	_ensure_spawn_point()

	var next_level_index := active_level_index + 1
	var next_level := _get_level_config(next_level_index)
	var display_level := next_level if next_level else _get_level_config(active_level_index)

	_update_icon(display_level)

	if name_label:
		name_label.text = building_config.display_name if building_config else ""

	if cost_label:
		if next_level:
			cost_label.text = "Cost: %d" % next_level.cost
		elif building_config:
			cost_label.text = "Max level reached"
		else:
			cost_label.text = ""

	if spawn_label:
		if next_level:
			spawn_label.text = "Build" if active_level_index < 0 else "Upgrade"
		elif building_config:
			spawn_label.text = "Max Level"
		else:
			spawn_label.text = ""

	if spawn_button:
		spawn_button.disabled = not _can_spawn()


func _update_icon(level_config: BuildingLevelConfig) -> void:
	if not icon_rect:
		return

	var texture: Texture2D = null

	if level_config and level_config.icon:
		texture = level_config.icon
	elif building_config:
		for config_level in building_config.levels:
			if config_level and config_level.icon:
				texture = config_level.icon
				break

	icon_rect.texture = texture
	icon_rect.visible = texture != null


func _get_level_config(index: int) -> BuildingLevelConfig:
	if not building_config:
		return null

	if index < 0 or index >= building_config.levels.size():
		return null

	var level = building_config.levels[index]
	return level if level is BuildingLevelConfig else null


func _can_spawn() -> bool:
	_ensure_spawn_point()
	return building_config != null and spawn_point != null and _get_level_config(active_level_index + 1) != null


func _on_spawn_pressed() -> void:
	if not _can_spawn():
		push_warning("Cannot spawn building without a valid config, spawn point, and level definition.")
		return

	var level_index := active_level_index + 1
	var level_config := _get_level_config(level_index)
	if not level_config:
		push_warning("No valid scene found for building '%s'." % (building_config.display_name if building_config else ""))
		return

	if not level_config.scene:
		push_warning("Level %d for building '%s' is missing a scene." % [level_index + 1, building_config.display_name])
		return

	var instance := level_config.scene.instantiate()
	if not instance:
		push_warning("Failed to instance scene for building '%s'." % building_config.display_name)
		return

	_clear_placeholders()

	if active_building and is_instance_valid(active_building):
		active_building.queue_free()

	spawn_point.add_child(instance)
	active_building = instance
	active_level_index = level_index

	_update_ui()


func _clear_placeholders() -> void:
	if placeholders_hidden or not spawn_point:
		return

	for child in spawn_point.get_children():
		if child == active_building:
			continue

		if child is Node3D:
			child.visible = false

	placeholders_hidden = true

func get_active_level_config() -> BuildingLevelConfig:
	return _get_level_config(active_level_index)


func get_next_level_config() -> BuildingLevelConfig:
	return _get_level_config(active_level_index + 1)
