extends Control

@onready var preview_root: Node3D = $ViewportContainer/SubViewport/PreviewRoot
@onready var spawn_button: TextureButton = $SpawnButton

var building_node: Node3D
var preview_instance: Node3D = null

func setup(building: Node3D) -> void:
    building_node = building
    if building_node:
        building_node.visible = false
    _populate_preview()
    if not spawn_button.pressed.is_connected(_on_spawn_pressed):
        spawn_button.pressed.connect(_on_spawn_pressed)


func _populate_preview() -> void:
    if preview_instance:
        preview_instance.queue_free()
        preview_instance = null
    if not building_node:
        return
    preview_instance = building_node.duplicate()
    preview_instance.visible = true
    preview_instance.transform = Transform3D.IDENTITY
    preview_instance.scale = Vector3.ONE * 0.2
    preview_root.add_child(preview_instance)


func _on_spawn_pressed() -> void:
    if not building_node:
        return
    building_node.visible = true
    spawn_button.disabled = true
