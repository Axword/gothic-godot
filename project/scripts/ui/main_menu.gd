extends Control

@onready var status: Label = $Content/Status
var volume_step := 0

func _ready() -> void:
	$Content/NewGame.pressed.connect(_new_game)
	$Content/LoadOne.pressed.connect(_load.bind(1))
	$Content/LoadTwo.pressed.connect(_load.bind(2))
	$Content/LoadThree.pressed.connect(_load.bind(3))
	$Content/Options.pressed.connect(_options)
	$Content/Quit.pressed.connect(get_tree().quit)
	SaveSystem.saved.connect(_save_message)

func _new_game() -> void:
	GameState.reset()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _load(slot: int) -> void:
	if SaveSystem.load_slot(slot): get_tree().change_scene_to_file("res://scenes/game.tscn")

func _options() -> void:
	volume_step = (volume_step + 1) % 4
	var db := [-18.0, -9.0, -3.0, 0.0][volume_step]
	AudioServer.set_bus_volume_db(0, db)
	status.text = "Głośność master: %d%%" % int((db + 18.0) / 18.0 * 100.0)

func _save_message(ok: bool, message: String) -> void:
	status.text = message
