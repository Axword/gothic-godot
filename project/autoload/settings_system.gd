extends Node
## Engine-facing settings intentionally live separately from savegame state.
signal changed
const PATH := "user://settings.json"
var master_db: float = -3.0
var music_db: float = -6.0
var sfx_db: float = -3.0
var resolution_index: int = 0
var fullscreen: bool = false
var mouse_sensitivity: float = 1.0
var subtitles: bool = true
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1280, 720), Vector2i(1600, 900)]

func _ready() -> void:
	load_settings()
	apply()

func cycle_master() -> void:
	master_db = [0.0, -3.0, -9.0, -18.0][( [0.0, -3.0, -9.0, -18.0].find(master_db) + 1) % 4]
	apply(); save_settings()

func cycle_resolution() -> void:
	resolution_index = (resolution_index + 1) % RESOLUTIONS.size()
	apply(); save_settings()

func toggle_fullscreen() -> void:
	fullscreen = not fullscreen
	apply(); save_settings()

func toggle_subtitles() -> void:
	subtitles = not subtitles
	save_settings(); changed.emit()

func apply() -> void:
	AudioServer.set_bus_volume_db(0, master_db)
	DisplayServer.window_set_size(RESOLUTIONS[resolution_index])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()

func save_settings() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"master_db": master_db, "music_db": music_db, "sfx_db": sfx_db, "resolution_index": resolution_index, "fullscreen": fullscreen, "mouse_sensitivity": mouse_sensitivity, "subtitles": subtitles}))

func load_settings() -> void:
	if not FileAccess.file_exists(PATH): return
	var file := FileAccess.open(PATH, FileAccess.READ); var json := JSON.new()
	if file != null and json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		master_db = float(data.get("master_db", master_db)); music_db = float(data.get("music_db", music_db)); sfx_db = float(data.get("sfx_db", sfx_db))
		resolution_index = clampi(int(data.get("resolution_index", resolution_index)), 0, RESOLUTIONS.size() - 1)
		fullscreen = bool(data.get("fullscreen", fullscreen)); mouse_sensitivity = float(data.get("mouse_sensitivity", mouse_sensitivity)); subtitles = bool(data.get("subtitles", subtitles))
