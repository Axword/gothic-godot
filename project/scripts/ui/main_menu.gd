extends Control

@onready var status: Label = $Content/Status
var options_open := false

func _ready() -> void:
	$Content/NewGame.pressed.connect(_new_game)
	$Content/LoadOne.pressed.connect(_load.bind(1))
	$Content/LoadTwo.pressed.connect(_load.bind(2))
	$Content/LoadThree.pressed.connect(_load.bind(3))
	$Content/Options.pressed.connect(_toggle_options)
	$Content/Master.pressed.connect(_master)
	$Content/Resolution.pressed.connect(_resolution)
	$Content/Fullscreen.pressed.connect(_fullscreen)
	$Content/Subtitles.pressed.connect(_subtitles)
	$Content/Back.pressed.connect(_toggle_options)
	$Content/Quit.pressed.connect(get_tree().quit)
	SaveSystem.saved.connect(_save_message)
	SettingsSystem.changed.connect(_refresh_options)
	_refresh_options()

func _new_game() -> void:
	GameState.reset(); get_tree().change_scene_to_file("res://scenes/game.tscn")

func _load(slot: int) -> void:
	if SaveSystem.load_slot(slot): get_tree().change_scene_to_file("res://scenes/game.tscn")

func _toggle_options() -> void:
	options_open = not options_open
	for name: String in ["NewGame", "LoadOne", "LoadTwo", "LoadThree", "Options", "Quit"]:
		var control := get_node("Content/" + name) as Control
		if control != null: control.visible = not options_open
	for name: String in ["Master", "Resolution", "Fullscreen", "Subtitles", "Back"]:
		var control := get_node("Content/" + name) as Control
		if control != null: control.visible = options_open
	_refresh_options()

func _master() -> void:
	SettingsSystem.cycle_master()
func _resolution() -> void:
	SettingsSystem.cycle_resolution()
func _fullscreen() -> void:
	SettingsSystem.toggle_fullscreen()
func _subtitles() -> void:
	SettingsSystem.toggle_subtitles()

func _refresh_options() -> void:
	$Content/Master.text = "Master: %d dB" % int(SettingsSystem.master_db)
	var res: Vector2i = SettingsSystem.RESOLUTIONS[SettingsSystem.resolution_index]
	$Content/Resolution.text = "Rozdzielczość: %d × %d" % [res.x, res.y]
	$Content/Fullscreen.text = "Pełny ekran: " + ("tak" if SettingsSystem.fullscreen else "nie")
	$Content/Subtitles.text = "Napisy: " + ("tak" if SettingsSystem.subtitles else "nie")

func _save_message(_ok: bool, message: String) -> void:
	status.text = message
