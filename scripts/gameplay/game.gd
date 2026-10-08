extends Node
## All economy and production rules live here. UI and artwork observe signals.

signal changed
signal stage_changed
signal sold(amount: int)
signal notice(message: String)

const BALANCE_PATH := "res://config/balance.json"
var balance: Dictionary
var economy: WorkshopEconomy
var coins := 120
var earned := 0
var batches := 0
var levels: Array[int] = [1, 1, 1]
var stage := -1
var elapsed := 0.0
var transferring := false
var batch_units := 0
var batch_revenue := 0
var batch_durations: Array[float] = []
var playing := false
var sound_enabled := true
var reduced_motion := false
var language := "en"
var save_exists := false
var save_error: Error = OK
var _autosave := 0.0
var _resume_playing := false

func _ready() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	assert(not balance.is_empty(), "Missing economy configuration")
	economy = WorkshopEconomy.new(balance)
	load_game()
	set_process(true)

func _process(delta: float) -> void:
	if not playing:
		return
	advance(delta)
	_autosave += delta
	if _autosave >= 10.0:
		_autosave = 0.0
		save_game()

func new_game() -> void:
	coins = int(balance.starting_coins)
	earned = 0
	batches = 0
	levels = [1, 1, 1]
	stage = -1
	elapsed = 0.0
	transferring = false
	batch_units = 0
	batch_revenue = 0
	batch_durations.clear()
	playing = true
	save_game()
	changed.emit()
	stage_changed.emit()

func start_batch() -> bool:
	if stage != -1 or coins < int(balance.batch_cost):
		return false
	coins -= int(balance.batch_cost)
	batch_units = next_units()
	batch_revenue = next_revenue()
	batch_durations.clear()
	for i in range(4):
		batch_durations.append(duration(i))
	stage = 0
	elapsed = 0.0
	transferring = false
	save_game()
	changed.emit()
	stage_changed.emit()
	return true

func advance(delta: float) -> void:
	# Consume remaining time across boundaries, including on slow mobile frames.
	var remaining := maxf(delta, 0.0)
	while stage >= 0 and remaining > 0.0:
		var target := current_duration()
		var step := minf(remaining, maxf(target - elapsed, 0.0))
		elapsed += step
		remaining -= step
		if elapsed + 0.00001 < target:
			break
		elapsed = 0.0
		if transferring:
			transferring = false
		elif stage < 3:
			stage += 1
			transferring = true
		else:
			coins += batch_revenue
			earned += batch_revenue
			batches += 1
			stage = -1
			sold.emit(batch_revenue)
		stage_changed.emit()
		changed.emit()
		save_game()

func current_duration() -> float:
	if transferring:
		return float(balance.transfer_seconds)
	if stage < 0:
		return 1.0
	return batch_durations[stage]

func progress() -> float:
	return clampf(elapsed / current_duration(), 0.0, 1.0) if stage >= 0 else 0.0

func duration(index: int) -> float:
	return economy.duration(index, levels)

func next_units() -> int:
	return economy.units(levels)

func next_revenue() -> int:
	return economy.revenue(levels)

func upgrade_cost(index: int) -> int:
	return economy.upgrade_cost(index, levels)

func upgrade(index: int) -> bool:
	if index < 0 or index >= 3 or levels[index] >= int(balance.max_level):
		return false
	var cost := upgrade_cost(index)
	# Reserve ingredients so upgrades cannot strand the player without a batch.
	if coins - cost < int(balance.batch_cost):
		notice.emit("Keep enough coins for your next batch.")
		return false
	coins -= cost
	levels[index] += 1
	save_game()
	changed.emit()
	return true

func rank_index() -> int:
	return economy.rank_index(earned)

func snapshot() -> Dictionary:
	return {"version": int(balance.save_version), "coins": coins, "earned": earned,
		"batches": batches, "levels": levels, "stage": stage, "elapsed": elapsed,
		"transferring": transferring, "batch_units": batch_units,
		"batch_revenue": batch_revenue, "batch_durations": batch_durations,
		"sound_enabled": sound_enabled, "reduced_motion": reduced_motion,
		"language": language}

func restore(data: Dictionary) -> void:
	coins = clampi(int(data.get("coins", balance.starting_coins)), 0, 1000000000)
	earned = clampi(int(data.get("earned", 0)), 0, 1000000000)
	batches = clampi(int(data.get("batches", 0)), 0, 1000000000)
	var saved_levels: Variant = data.get("levels", [1, 1, 1])
	levels = [1, 1, 1]
	if saved_levels is Array and saved_levels.size() == 3:
		for i in range(3):
			levels[i] = clampi(int(saved_levels[i]), 1, int(balance.max_level))
	stage = clampi(int(data.get("stage", -1)), -1, 3)
	transferring = bool(data.get("transferring", false)) and stage > 0
	batch_units = clampi(int(data.get("batch_units", next_units())), 1, 1000)
	batch_revenue = clampi(int(data.get("batch_revenue", next_revenue())), 1, 100000)
	batch_durations.clear()
	var saved_durations: Variant = data.get("batch_durations", [])
	for i in range(4):
		var value := duration(i)
		if saved_durations is Array and saved_durations.size() == 4:
			value = clampf(float(saved_durations[i]), 0.1, 60.0)
		batch_durations.append(value)
	elapsed = clampf(float(data.get("elapsed", 0.0)), 0.0, current_duration())
	sound_enabled = bool(data.get("sound_enabled", true))
	reduced_motion = bool(data.get("reduced_motion", false))
	language = str(data.get("language", "en"))
	if language not in ["en", "pl"]:
		language = "en"
	changed.emit()
	stage_changed.emit()

func load_game() -> bool:
	var data := SaveStore.read_save()
	save_exists = not data.is_empty()
	if save_exists:
		restore(data)
	return save_exists

func save_game() -> Error:
	save_error = SaveStore.write_save(snapshot())
	if save_error == OK:
		save_exists = true
	else:
		notice.emit("Could not save. Check available storage.")
	return save_error

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_resume_playing = playing
		playing = false
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		playing = _resume_playing
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if save_exists:
			save_game()
