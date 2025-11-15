extends Node

const MOD_DIR_NAME := "tttt-CharacterHighlight"
const MOD_ID := "tttt-CharacterHighlight"

var mod_dir_path := ""


func _init():
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR_NAME)
	_install_extensions(mod_dir_path)


func _ready():
	call_deferred("_register_mod_options")


func _install_extensions(mod_dir_path: String) -> void:
	var extensions_dir := mod_dir_path.plus_file("extensions")
	ModLoaderMod.install_script_extension(extensions_dir.plus_file("player_extension.gd"))


func _get_mod_options() -> Node:
	var parent = get_parent()
	if not parent:
		return null
	
	var mod_options_mod = parent.get_node_or_null("Oudstand-ModOptions")
	if not mod_options_mod:
		return null
	
	return mod_options_mod.get_node_or_null("ModOptions")


func _register_mod_options() -> void:
	var mod_options = _get_mod_options()
	if not mod_options:
		return
	
	mod_options.register_mod_options("CharacterHighlight", {
		"tab_title": "Character Highlight",
		"options": [
			{
				"type": "toggle",
				"id": "circle_enabled",
				"label": "Enable Circle Highlight",
				"default": true
			},
			{
				"type": "slider",
				"id": "circle_scale",
				"label": "Circle Size",
				"min": 1.0,
				"max": 3.0,
				"step": 0.1,
				"default": 1.5
			},
			{
				"type": "slider",
				"id": "circle_brightness",
				"label": "Circle Brightness",
				"min": 0.5,
				"max": 2.0,
				"step": 0.1,
				"default": 1.0
			},
			{
				"type": "toggle",
				"id": "outline_enabled",
				"label": "Enable Outline Highlight",
				"default": true
			},
			{
				"type": "slider",
				"id": "outline_scale",
				"label": "Outline Highlight Width",
				"min": 1.0,
				"max": 3.0,
				"step": 0.1,
				"default": 1.5
			},
			{
				"type": "slider",
				"id": "outline_brightness",
				"label": "Outline Highlight Brightness",
				"min": 0.5,
				"max": 2.0,
				"step": 0.1,
				"default": 1.0
			}
		],
		"info_text": "Two independent features: Circle Highlight (ground glow) and Outline Highlight (edge glow). Both can be active simultaneously!"
	})
