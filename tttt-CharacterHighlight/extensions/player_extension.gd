extends "res://entities/units/player/player.gd"

# Improves character visibility with two independent highlight features
# Works independently of vanilla "Highlight your character" setting

const MOD_NAME: String = "CharacterHighlight"

# ModOptions integration
var _mod_options_node = null

# Circle Highlight Feature
var _circle_enabled: bool = true
var _circle_scale: float = 1.5
var _circle_brightness: float = 1.0
var _mod_highlight_circle: Sprite = null
var _original_z_indices: Dictionary = {}

# Outline Highlight Feature
var _outline_enabled: bool = true
var _outline_scale: float = 1.5
var _outline_brightness: float = 1.0
var _outline_shader_material: ShaderMaterial = null
var _original_sprite_material = null
var _player_sprite: Sprite = null
var _outline_z_indices_saved: bool = false


func _ready():
	._ready()
	call_deferred("_initialize_mod_highlight")
	call_deferred("_setup_mod_options_listener")


func init_effect_behaviors() -> void:
	# Check if already initialized to prevent double initialization
	if effect_behaviors.get_child_count() > 0:
		ModLoaderLog.warning("Effect behaviors already initialized, skipping duplicate init", MOD_NAME)
		return
	 
	# Call parent implementation
	.init_effect_behaviors()


func _initialize_mod_highlight() -> void:
	_load_mod_options()
	
	if _circle_enabled:
		_create_circle_highlight()
	
	if _outline_enabled:
		_create_outline()


# ========================================
# Circle Highlight Implementation
# ========================================

func _create_circle_highlight() -> void:
	if not is_instance_valid(highlight):
		return
	
	# Create independent sprite node to avoid interfering with vanilla highlight
	_mod_highlight_circle = Sprite.new()
	_mod_highlight_circle.name = "ModHighlightCircle"
	_mod_highlight_circle.texture = highlight.texture
	_mod_highlight_circle.position = highlight.position
	
	var animation_node = highlight.get_parent()
	if is_instance_valid(animation_node):
		animation_node.add_child(_mod_highlight_circle)
		_calculate_and_apply_z_indices(animation_node)
	
	_apply_circle_scale()
	_apply_circle_appearance()


func _apply_circle_scale() -> void:
	if is_instance_valid(_mod_highlight_circle):
		_mod_highlight_circle.scale = Vector2(_circle_scale, _circle_scale)


func _apply_circle_appearance() -> void:
	if not is_instance_valid(_mod_highlight_circle):
		return
	
	_mod_highlight_circle.visible = true
	
	# Get player-specific color in coop, default cyan in single player
	var base_color: Color
	if RunData.is_coop_run:
		base_color = CoopService.get_player_color(player_index)
	else:
		base_color = Utils.HIGHLIGHT_COLOR
	
	# Use HSV color space to preserve hue at all brightness levels
	# This prevents white-out at high brightness values
	var highlight_color: Color
	if _circle_brightness != 1.0:
		highlight_color = Color.from_hsv(
			base_color.h,
			base_color.s,
			clamp(base_color.v * _circle_brightness, 0.0, 1.0),
			1.0
		)
	else:
		highlight_color = base_color
		highlight_color.a = 1.0
	
	_mod_highlight_circle.modulate = highlight_color


func _toggle_circle_visibility(enabled: bool) -> void:
	if enabled:
		if is_instance_valid(_mod_highlight_circle):
			_mod_highlight_circle.visible = true
			_reapply_z_indices()
		else:
			_create_circle_highlight()
	else:
		if is_instance_valid(_mod_highlight_circle):
			_mod_highlight_circle.visible = false
			# Keep z_index elevated if outline is still active
			if not is_instance_valid(_outline_shader_material):
				_restore_z_indices()
			else:
				# Transfer z_index management to outline
				_outline_z_indices_saved = true


func _cleanup_circle() -> void:
	# Only restore z_indices if outline is not managing them
	if not is_instance_valid(_outline_shader_material):
		_restore_z_indices()
	else:
		_outline_z_indices_saved = true
	
	if is_instance_valid(_mod_highlight_circle):
		_mod_highlight_circle.visible = false
		_mod_highlight_circle.queue_free()
		_mod_highlight_circle = null


# ========================================
# ModOptions Integration
# ========================================

func _load_mod_options() -> void:
	_mod_options_node = _get_mod_options_node()
	if not is_instance_valid(_mod_options_node):
		return
	
	if not _mod_options_node.has_method("get_value"):
		return
	
	# Load circle options
	var circle_enabled = _mod_options_node.get_value("CharacterHighlight", "circle_enabled")
	if circle_enabled != null:
		_circle_enabled = circle_enabled
	
	var circle_scale = _mod_options_node.get_value("CharacterHighlight", "circle_scale")
	if circle_scale != null:
		_circle_scale = circle_scale
	
	var circle_brightness = _mod_options_node.get_value("CharacterHighlight", "circle_brightness")
	if circle_brightness != null:
		_circle_brightness = circle_brightness
	
	# Load outline options
	var outline_enabled = _mod_options_node.get_value("CharacterHighlight", "outline_enabled")
	if outline_enabled != null:
		_outline_enabled = outline_enabled
	
	var outline_scale = _mod_options_node.get_value("CharacterHighlight", "outline_scale")
	if outline_scale != null:
		_outline_scale = outline_scale
	
	var outline_brightness = _mod_options_node.get_value("CharacterHighlight", "outline_brightness")
	if outline_brightness != null:
		_outline_brightness = outline_brightness


func _get_mod_options_node() -> Node:
	var mod_loader = get_tree().get_root().get_node_or_null("ModLoader")
	if not is_instance_valid(mod_loader):
		return null
	
	var mod_options_mod = mod_loader.get_node_or_null("Oudstand-ModOptions")
	if not is_instance_valid(mod_options_mod):
		return null
	
	return mod_options_mod.get_node_or_null("ModOptions")


func _setup_mod_options_listener() -> void:
	if not is_instance_valid(_mod_options_node):
		return
	
	if not _mod_options_node.has_signal("config_changed"):
		return
	
	var error = _mod_options_node.connect("config_changed", self, "_on_mod_config_changed")
	if error != OK:
		ModLoaderLog.error("Failed to connect to ModOptions signal: %s" % str(error), MOD_NAME)


func _on_mod_config_changed(mod_id: String, option_id: String, new_value) -> void:
	if mod_id != "CharacterHighlight":
		return
	
	match option_id:
		"circle_enabled":
			_circle_enabled = new_value
			_toggle_circle_visibility(new_value)
		"circle_scale":
			_circle_scale = new_value
			_apply_circle_scale()
		"circle_brightness":
			_circle_brightness = new_value
			_apply_circle_appearance()
		"outline_enabled":
			_outline_enabled = new_value
			_toggle_outline_visibility(new_value)
		"outline_scale":
			_outline_scale = new_value
			_apply_outline_scale()
		"outline_brightness":
			_outline_brightness = new_value
			_apply_outline_appearance()


# ========================================
# Z-Index Management
# ========================================

func _calculate_and_apply_z_indices(animation_node: Node) -> void:
	var all_z_indices = []
	var nodes_to_modify = []
	
	# Collect z_index values from animation children (except our own highlight)
	for child in animation_node.get_children():
		if child == _mod_highlight_circle or child.name == "ModHighlightCircle":
			continue
		if child.has_method("get") and "z_index" in child:
			all_z_indices.append(child.z_index)
			nodes_to_modify.append(child)
	
	# Collect z_index values from weapons
	var weapons_node = get_node_or_null("Weapons")
	if is_instance_valid(weapons_node):
		if weapons_node.has_method("get") and "z_index" in weapons_node:
			all_z_indices.append(weapons_node.z_index)
			nodes_to_modify.append(weapons_node)
		
		for weapon in weapons_node.get_children():
			if weapon.has_method("get") and "z_index" in weapon:
				all_z_indices.append(weapon.z_index)
				nodes_to_modify.append(weapon)
	
	# Find minimum z_index to determine enemy layer
	var min_z_index = 0
	if all_z_indices.size() > 0:
		min_z_index = all_z_indices[0]
		for z in all_z_indices:
			if z < min_z_index:
				min_z_index = z
	
	# Raise all player elements by +2 to create gap for circle highlight
	# Final order: enemies (z≤min) < circle (z=min+1) < player elements (z≥min+2)
	var z_offset = 2
	for node in nodes_to_modify:
		var original_z = node.z_index
		_original_z_indices[node.get_path()] = original_z
		node.z_index = original_z + z_offset
	
	_mod_highlight_circle.z_index = min_z_index + 1


func _reapply_z_indices() -> void:
	var animation_node = get_node_or_null("Animation")
	if is_instance_valid(animation_node):
		_calculate_and_apply_z_indices(animation_node)


func _restore_z_indices() -> void:
	for node_path in _original_z_indices.keys():
		var node = get_node_or_null(node_path)
		if is_instance_valid(node) and node.has_method("get") and "z_index" in node:
			node.z_index = _original_z_indices[node_path]


# ========================================
# Outline Highlight Implementation
# ========================================

func _create_outline() -> void:
	var animation_node = get_node_or_null("Animation")
	if not is_instance_valid(animation_node):
		return
	
	_player_sprite = animation_node.get_node_or_null("Sprite")
	if not is_instance_valid(_player_sprite):
		return
	
	# Manage z_index independently if circle is not active
	# This ensures outline is always visible above enemies
	if not is_instance_valid(_mod_highlight_circle):
		_calculate_and_apply_z_indices(animation_node)
		_outline_z_indices_saved = true
	else:
		_outline_z_indices_saved = false
	
	_original_sprite_material = _player_sprite.material
	
	if not is_instance_valid(outline_material):
		return
	
	# Use game's native outline shader for consistent look with cursed enemies
	_outline_shader_material = ShaderMaterial.new()
	_outline_shader_material.shader = outline_material.shader
	
	_player_sprite.material = _outline_shader_material
	_update_outline_shader_parameters()


func _toggle_outline_visibility(enabled: bool) -> void:
	if enabled:
		if not is_instance_valid(_outline_shader_material):
			_create_outline()
		else:
			if is_instance_valid(_player_sprite):
				_player_sprite.material = _outline_shader_material
				_update_outline_shader_parameters()
			
			# Re-apply z_index if we need to manage it independently
			if not is_instance_valid(_mod_highlight_circle):
				var animation_node = get_node_or_null("Animation")
				if is_instance_valid(animation_node):
					_calculate_and_apply_z_indices(animation_node)
					_outline_z_indices_saved = true
	else:
		if is_instance_valid(_player_sprite):
			_player_sprite.material = _original_sprite_material
		
		# Restore z_index only if we were managing it independently
		if _outline_z_indices_saved and not is_instance_valid(_mod_highlight_circle):
			_restore_z_indices()
			_outline_z_indices_saved = false


func _apply_outline_scale() -> void:
	_update_outline_shader_parameters()


func _apply_outline_appearance() -> void:
	_update_outline_shader_parameters()


func _update_outline_shader_parameters() -> void:
	if not is_instance_valid(_outline_shader_material) or not is_instance_valid(_player_sprite):
		return
	
	# Set required shader parameters
	if is_instance_valid(_player_sprite.texture):
		_outline_shader_material.set_shader_param("texture_size", _player_sprite.texture.get_size())
	
	# Keep character fully opaque (alpha=1.0) to prevent transparency issues
	_outline_shader_material.set_shader_param("alpha", 1.0)
	_outline_shader_material.set_shader_param("desaturation", 0.0)
	
	# Map scale 1.0-3.0 to outline width 1.0-6.0 pixels
	var outline_width = 1.0 + (_outline_scale - 1.0) * 2.5
	_outline_shader_material.set_shader_param("width", outline_width)
	
	# Get player-specific color in coop, default cyan in single player
	var base_color: Color
	if RunData.is_coop_run:
		base_color = CoopService.get_player_color(player_index)
	else:
		base_color = Utils.HIGHLIGHT_COLOR
	
	# Use HSV color space to preserve hue at all brightness levels
	var outline_color: Color
	if _outline_brightness != 1.0:
		outline_color = Color.from_hsv(
			base_color.h,
			base_color.s,
			clamp(base_color.v * _outline_brightness, 0.0, 1.0),
			1.0
		)
	else:
		outline_color = base_color
	
	# Set outline color (only use first color slot)
	_outline_shader_material.set_shader_param("outline_color_0", outline_color)
	_outline_shader_material.set_shader_param("outline_color_1", Color(0, 0, 0, 0))
	_outline_shader_material.set_shader_param("outline_color_2", Color(0, 0, 0, 0))
	_outline_shader_material.set_shader_param("outline_color_3", Color(0, 0, 0, 0))


func _cleanup_outline() -> void:
	if is_instance_valid(_player_sprite) and _original_sprite_material != null:
		_player_sprite.material = _original_sprite_material
	
	# Restore z_index only if we were managing it independently
	if _outline_z_indices_saved and not is_instance_valid(_mod_highlight_circle):
		_restore_z_indices()
		_outline_z_indices_saved = false
	
	_outline_shader_material = null
	_original_sprite_material = null
	_player_sprite = null


# ========================================
# Cleanup
# ========================================

func die(args = Entity.DieArgs.new()) -> void:
	.die(args)
	
	_cleanup_circle()
	_cleanup_outline()
	
	if is_instance_valid(_mod_options_node) and _mod_options_node.has_signal("config_changed"):
		if _mod_options_node.is_connected("config_changed", self, "_on_mod_config_changed"):
			_mod_options_node.disconnect("config_changed", self, "_on_mod_config_changed")
