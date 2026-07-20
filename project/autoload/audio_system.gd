extends Node
## Small original procedural SFX rendered to WAV; routed through Master bus.
var player: AudioStreamPlayer
var streams: Dictionary = {
	"sword_hit": preload("res://assets/audio/sword_hit.wav"),
	"fire_cast": preload("res://assets/audio/fire_cast.wav"),
	"ice_cast": preload("res://assets/audio/ice_cast.wav"),
	"chest_open": preload("res://assets/audio/chest_open.wav"),
	"alarm": preload("res://assets/audio/alarm.wav")
}
func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = &"Master"
	add_child(player)
func play_effect(effect_id: String) -> void:
	var stream: AudioStream = streams.get(effect_id, null)
	if stream == null: return
	player.stream = stream
	player.play()
