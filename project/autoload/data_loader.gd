extends Node
## Small typed JSON gateway with actionable errors for editor/CI use.
signal data_error(path: String, message: String)

func load_array(path: String) -> Array[Dictionary]:
	var parsed: Variant = _parse(path)
	var result: Array[Dictionary] = []
	if parsed is Array:
		for row: Variant in parsed:
			if row is Dictionary:
				result.append(row as Dictionary)
	return result

func load_dictionary(path: String) -> Dictionary:
	var parsed: Variant = _parse(path)
	return parsed as Dictionary if parsed is Dictionary else {}

func _parse(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_report(path, "nie można otworzyć pliku")
		return null
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	if error != OK:
		_report(path, "JSON: %s, wiersz %d" % [json.get_error_message(), json.get_error_line()])
		return null
	return json.data

func validate_ids(path: String) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for row: Dictionary in load_array(path):
		var id: String = str(row.get("id", ""))
		if id.is_empty() or seen.has(id):
			errors.append("%s: brakujące lub zduplikowane id '%s'" % [path, id])
		seen[id] = true
	return errors

func _report(path: String, message: String) -> void:
	push_error("DataLoader [%s]: %s" % [path, message])
	data_error.emit(path, message)
