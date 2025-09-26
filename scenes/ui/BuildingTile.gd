extends Control

const BUILDING_ICON_PATHS := {
	"Building1": "res://assets/kingdoms/kingdom1/icons/b1.png",
	"Building2": "res://assets/kingdoms/kingdom1/icons/b2.png",
	"Building3": "res://assets/kingdoms/kingdom1/icons/b3.png",
	"Building4": "res://assets/kingdoms/kingdom1/icons/b4.png",
	"Building5": "res://assets/kingdoms/kingdom1/icons/b5.png",
}

@onready var icon_rect: TextureRect = $Content/IconContainer/Icon
@onready var spawn_button: TextureButton = $Content/SpawnButton

var building_node: Node3D

func setup(building: Node3D) -> void:
	building_node = building
	if building_node:
		building_node.visible = false
	_update_icon()
	if not spawn_button.pressed.is_connected(_on_spawn_pressed):
		spawn_button.pressed.connect(_on_spawn_pressed)


func _update_icon() -> void:
	if not icon_rect:
		return
	var texture: Texture2D = null
	if building_node:
		var key := building_node.name
		if BUILDING_ICON_PATHS.has(key):
			var icon_path: String = BUILDING_ICON_PATHS[key]
			if ResourceLoader.exists(icon_path, "Texture2D"):
				texture = load(icon_path)
	icon_rect.texture = texture
	icon_rect.visible = texture != null


func _on_spawn_pressed() -> void:
	if not building_node:
		return
	building_node.visible = true
	spawn_button.disabled = true
