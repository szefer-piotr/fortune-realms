extends Control

const BUILD_LEVEL_ICON := preload("res://assets/icons/build.png")
const REWARD_LEVEL_ICON := preload("res://assets/icons/reward.png")

@onready var icon_rect := get_node_or_null("Content/IconContainer/Icon") as TextureRect
@onready var name_label := get_node_or_null("Content/NameLabel") as Label
@onready var level_icons := get_node_or_null("Content/LevelIcons") as HBoxContainer
@onready var cost_label := get_node_or_null("TextureButton/CostContainer/CostLabel") as Label
@onready var coin_icon := get_node_or_null("TextureButton/CostContainer/CoinIcon") as TextureRect
@onready var spawn_button := get_node_or_null("TextureButton") as TextureButton

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
	_update_level_icons()

        if name_label:
                name_label.text = building_config.display_name if building_config else ""

        if cost_label:
                if next_level:
                        cost_label.text = String.num_int64(next_level.cost)
                        if coin_icon:
                                coin_icon.visible = true
                elif building_config:
                        cost_label.text = "Max"
                        if coin_icon:
                                coin_icon.visible = false
                else:
                        cost_label.text = ""
                        if coin_icon:
                                coin_icon.visible = false

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


func _update_level_icons() -> void:
		if not level_icons:
				return

		for child in level_icons.get_children():
				child.queue_free()

		if not building_config or building_config.levels.is_empty():
				level_icons.visible = false
				return

		level_icons.visible = true

		var total_levels := building_config.levels.size()

		for index in total_levels:
				var icon_texture := BUILD_LEVEL_ICON if index < total_levels - 1 else REWARD_LEVEL_ICON
				var icon_rect_instance := TextureRect.new()
				icon_rect_instance.texture = icon_texture
				icon_rect_instance.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

				var completed := index <= active_level_index
				var next_up := index == active_level_index + 1

				if completed:
						icon_rect_instance.modulate = Color(1, 1, 1, 1)
				elif next_up:
						icon_rect_instance.modulate = Color(1, 1, 1, 0.8)
				else:
						icon_rect_instance.modulate = Color(1, 1, 1, 0.35)

				icon_rect_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				icon_rect_instance.custom_minimum_size = Vector2(24, 24)

				level_icons.add_child(icon_rect_instance)


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
