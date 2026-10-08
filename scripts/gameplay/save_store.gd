class_name SaveStore
extends RefCounted
## Atomic local persistence. A corrupt primary falls back to the previous snapshot.

const PATH := "user://workshop.json"

static func read_save(path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		if parser.parse(file.get_as_text()) == OK and _valid_data(parser.data):
			return parser.data
	return {}

static func _valid_data(data: Variant) -> bool:
	if not data is Dictionary or data.get("version", 0) != 1:
		return false
	for key in ["coins", "earned", "batches", "stage", "elapsed"]:
		if typeof(data.get(key)) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	var levels: Variant = data.get("levels")
	if not levels is Array or levels.size() != 3:
		return false
	for level in levels:
		if typeof(level) not in [TYPE_INT, TYPE_FLOAT]:
			return false
	var durations: Variant = data.get("batch_durations", [])
	if not durations is Array or durations.size() not in [0, 4]:
		return false
	for duration in durations:
		if typeof(duration) not in [TYPE_INT, TYPE_FLOAT] or float(duration) <= 0.0:
			return false
	return true

static func write_save(data: Dictionary, path: String = PATH) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	var primary := JSON.new()
	if FileAccess.file_exists(path) and primary.parse(FileAccess.get_file_as_string(path)) == OK and _valid_data(primary.data):
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temporary, path)
