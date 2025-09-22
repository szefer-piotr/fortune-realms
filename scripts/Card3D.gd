extends RigidBody3D

@export var face_textures: Array[Texture2D] = [
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/coins.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/draws.png"),
	preload("res://assets/cards_png/gpt_game_assets/cards_simple/thief.png"),
]

# Auto-filled when you set the texture
@export var icon_type: String = "unknown"
@export var highlight_emission_color: Color = Color(1.0, 1.0, 0.94)
@export var highlight_emission_min := 0.1
@export var highlight_emission_max := 0.5
@export var highlight_scale_multiplier := 1.08
@export var highlight_pulse_duration := 0.8

var number_value: int = 0
var _is_highlighted := false

@onready var edge: MeshInstance3D = $Edge
@onready var front: MeshInstance3D = $Front
@onready var back: MeshInstance3D = $Back
@onready var number_label: Label3D = $NumberLabel
@onready var combo_fx: CPUParticles3D = $ComboFX


var _base_mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _visual_nodes: Array[Node3D] = []
var _baseline_scales: Dictionary = {}
var _highlight_tween: Tween

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
	_glow_mat.emission = highlight_emission_color
	_glow_mat.emission_energy_multiplier = highlight_emission_min

	# Start with base material
	front.material_override = _base_mat

	# Ensure we have particles child
	if not combo_fx:
		combo_fx = _make_combo_fx()
		add_child(combo_fx)
		
	for node in [edge, front, back, number_label, combo_fx]:
		if node:
			_visual_nodes.append(node)
			_baseline_scales[node] = node.scale

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
	if on:
		front.material_override = _glow_mat
		_start_highlight_tween()
		if combo_fx:
			combo_fx.emitting = false
			if combo_fx.has_method("restart"):
				combo_fx.restart()
			combo_fx.emitting = true
	else:
		_stop_highlight_tween()
		front.material_override = _base_mat
		if combo_fx:
			combo_fx.emitting = false
			
func _start_highlight_tween() -> void:
	_stop_highlight_tween()
	_glow_mat.emission_energy_multiplier = highlight_emission_min
	var duration : float = max(highlight_pulse_duration, 0.01)
	var half_duration := duration * 0.5
	_highlight_tween = create_tween()
	_highlight_tween.set_loops()
	var energy_up := _highlight_tween.tween_property(
		_glow_mat,
		"emission_energy_multiplier",
		highlight_emission_max,
		half_duration
	)
	energy_up.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for node in _visual_nodes:
		_highlight_tween.parallel().tween_property(
			node,
			"scale",
			(_baseline_scales.get(node, node.scale) as Vector3) * highlight_scale_multiplier,
			half_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var energy_down := _highlight_tween.tween_property(
		_glow_mat,
		"emission_energy_multiplier",
		highlight_emission_min,
		half_duration
	)
	energy_down.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for node in _visual_nodes:
		_highlight_tween.parallel().tween_property(
			node,
			"scale",
			_baseline_scales.get(node, node.scale),
			half_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_highlight_tween() -> void:
	if _highlight_tween:
		_highlight_tween.kill()
		_highlight_tween = null
	for node in _visual_nodes:
		node.scale = _baseline_scales.get(node, node.scale)
	_glow_mat.emission_energy_multiplier = highlight_emission_min

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
