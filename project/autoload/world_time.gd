extends Node
signal minute_changed(total_minutes: int)
const MINUTES_PER_SECOND := 4.0
func _process(delta: float) -> void:
	var previous := int(GameState.world_minutes)
	GameState.world_minutes = fmod(GameState.world_minutes + delta * MINUTES_PER_SECOND, 1440.0)
	if int(GameState.world_minutes) != previous: minute_changed.emit(int(GameState.world_minutes))
func is_night() -> bool:
	var hour := int(GameState.world_minutes / 60.0); return hour < 6 or hour >= 20
