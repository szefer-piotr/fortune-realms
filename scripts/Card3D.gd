extends RigidBody3D

@export var face_textures: Array[Texture2D] = [
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/coins.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/draws.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/thief.png"),
]

# Auto-filled when you set the texture
@export var icon_type: String = "unknown"
@export var glow_color: Color = Color(1.0, 0.9, 0.4)
@export var glow_energy := 1.8

var number_value: int = 0
var _is_highlighted := false

@onready var number_label: Label3D = $NumberLabel
@onready var front: MeshInstance3D = $Front
@onready var combo_fx: CPUParticles3D = $ComboFX

var _base_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D

func _ready() -> void:
	number_value = randi_range(1, 6)
	number_label.text = str(number_value)

	# Prepare materials
	var existing := front.material_override
	if existing is StandardMaterial3D:
		_base_mat = (existing as StandardMaterial3D).duplicate()
	else:
		_base_mat = StandardMaterial3D.new()

	_glow_mat = _base_mat.duplicate()
	_glow_mat.emission_enabled = true
	_glow_mat.emission = glow_color
	_glow_mat.emission_energy_multiplier = glow_energy

	# Start with base material
	front.material_override = _base_mat

	# Ensure we have particles child
	if not combo_fx:
		combo_fx = _make_combo_fx()
		add_child(combo_fx)

func set_face_texture(tex: Texture2D) -> void:
	# Assign to both base & glow so switching is instant
	_base_mat.albedo_texture = tex
	_glow_mat.albedo_texture = tex
	front.material_override = _glow_mat if _is_highlighted else _base_mat

	# Best-effort: infer icon name from the texture filename
	icon_type = _infer_icon_from_texture(tex)

func set_highlight(on: bool) -> void:
	if _is_highlighted == on:
		return
	_is_highlighted = on
	front.material_override = _glow_mat if on else _base_mat
	if combo_fx:
		combo_fx.emitting = on

func _infer_icon_from_texture(tex: Texture2D) -> String:
	var p := tex.resource_path
	if p == "":
		return "unknown"
	# "res://.../coins.png" -> "coins"
	return p.get_file().get_basename()

func _make_combo_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "ComboFX"
	p.one_shot = false
	p.amount = 160
	p.lifetime = 1.1
	p.local_coords = true
	p.emitting = false
	p.transform.origin = Vector3(0, -0.02, 0)  # slightly below the card

	# Mesh for particles (little squares)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	p.mesh = quad

	# Particle motion parameters
	p.direction = Vector3(0, 1, 0)
	p.spread = 85.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 8.0
	p.angular_velocity_min = -6.0
	p.angular_velocity_max = 6.0
	p.gravity = Vector3(0, -5.5, 0)
	p.scale_min = 0.08
	p.scale_max = 0.16

	# 🎨 Correct way: build a Gradient, wrap it in GradientTexture1D
	var grad := Gradient.new()
	grad.add_point(0.00, Color.html("#ff5470"))
	grad.add_point(0.25, Color.html("#ffd166"))
	grad.add_point(0.50, Color.html("#06d6a0"))
	grad.add_point(0.75, Color.html("#118ab2"))
	grad.add_point(1.00, Color.WHITE)

	var ramp := Gradient.new()
	ramp.gradient = grad

	# Assign the texture (this is what CPUParticles3D expects)
	#p.color_ramp = ramp
	p.color_ramp = ramp

	return p
