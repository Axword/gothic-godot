extends Node
## Scene supplies actual visible witnesses; this system never invents global witnesses.
signal theft_resolved(owner_id: String, outcome: String)

func attempt(owner_id: String, item_id: String, witnesses: Array[String]) -> String:
	if witnesses.is_empty():
		GameState.add_item(item_id)
		theft_resolved.emit(owner_id, "success")
		return "success"
	var response := CrimeSystem.report("theft", owner_id, witnesses)
	theft_resolved.emit(owner_id, response)
	return response
