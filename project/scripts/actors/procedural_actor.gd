class_name ProceduralActor
extends Node2D
## Reusable animation component for prototype NPCs/enemies without external runtime dependencies.
signal animation_finished(animation_name: String)

enum State { IDLE, WALK, ATTACK, CAST, HIT, DEATH }
@export var body_color := Color("d6c39a")
@export var facing := Vector2.DOWN
var state: State = State.IDLE
var state_time := 0.0
var dead := false

func play(next_state: State) -> void:
	if dead and next_state != State.DEATH: return
	state = next_state
	state_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	state_time += delta
	if state in [State.ATTACK, State.CAST, State.HIT] and state_time > 0.35:
		state = State.IDLE; animation_finished.emit("action")
	if state == State.DEATH and state_time > 0.8:
		dead = true; animation_finished.emit("death")
	queue_redraw()

func _draw() -> void:
	if dead: return
	var bob := sin(state_time * (10.0 if state == State.WALK else 3.0)) * (2.0 if state == State.WALK else 0.7)
	var alpha := 1.0 if state != State.DEATH else maxf(0.0, 1.0 - state_time / 0.8)
	draw_circle(Vector2(0.0, bob), 12, Color(body_color.r, body_color.g, body_color.b, alpha))
	if state == State.ATTACK:
		draw_arc(facing * 13.0, 15.0, facing.angle() - 1.1, facing.angle() + 1.1, 10, Color("e8bb68"), 3.0)
	elif state == State.CAST:
		draw_circle(facing * 20.0, 10.0 + sin(state_time * 20.0) * 3.0, Color(0.95, 0.40, 0.12, alpha))
	elif state == State.HIT:
		draw_arc(Vector2.ZERO, 19.0, 0.0, TAU, 12, Color("f3d070"), 2.0)
