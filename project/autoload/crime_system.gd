extends Node
## Witnesses must be explicitly supplied by the world visibility check; no global omniscience.
signal crime_reported(kind: String, owner_id: String, witnesses: Array[String])
var offences: Array[Dictionary] = []

func report(kind: String, owner_id: String, witnesses: Array[String]) -> String:
	var level := "none"
	if witnesses.size() == 1: level = "warning"
	elif witnesses.size() == 2: level = "fine"
	elif witnesses.size() > 2: level = "alarm"
	offences.append({"kind":kind,"owner_id":owner_id,"witnesses":witnesses,"response":level})
	crime_reported.emit(kind, owner_id, witnesses)
	return level
