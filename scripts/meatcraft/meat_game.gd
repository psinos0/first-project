extends Node
## Authoritative MeatCraft simulation. Presentation observes signals and never owns inventory.

signal state_changed
signal event_posted(message: String, kind: String)
signal stage_changed(stage: String)
signal save_completed(ok: bool)

const CONFIG_PATH := "res://config/meatcraft_game.json"
const SAVE_PATH := "user://meatcraft_v2.json"
const STAGE_ORDER := ["preparation", "spice_prep", "marination", "hanging", "drying", "slicing", "packaging"]

var config: Dictionary = {}
var cash := 0.0
var lifetime_revenue := 0.0
var lifetime_expenses := 0.0
var property_owned := false
var hall_id := ""
var industry_selected := false
var starter_line_owned := false
var tutorial_step := 0
var tutorial_complete := false
var reputation := 1.0
var game_day := 1
var game_minute := 8.0 * 60.0
var time_scale := 1
var simulation_paused := true
var inventory: Dictionary = {}
var pending_delivery: Dictionary = {}
var active_batch: Dictionary = {}
var orders: Array[Dictionary] = []
var machine_condition := 100.0
var hygiene := 92.0
var batches_completed := 0
var lots_received := 0
var last_receiving_lot := ""
var last_supplier_quality := 0.88
var save_exists := false
var event_log: Array[Dictionary] = []
var language := "en"
var master_volume := 0.8
var sfx_volume := 0.8
var reduced_motion := false
var _autosave_real_seconds := 0.0
var _batch_sequence := 0

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		config = parsed
	else:
		push_error("MeatCraft configuration is missing or invalid")
		return
	load_game()
	set_process(true)

func _process(delta: float) -> void:
	if simulation_paused or not property_owned:
		return
	advance_simulation(delta * float(time_scale) * float(config.game_minutes_per_real_second))
	_autosave_real_seconds += delta
	if _autosave_real_seconds >= 12.0:
		_autosave_real_seconds = 0.0
		save_game()

func new_company() -> void:
	cash = float(config.starting_cash)
	lifetime_revenue = 0.0
	lifetime_expenses = 0.0
	property_owned = false
	hall_id = ""
	industry_selected = false
	starter_line_owned = false
	tutorial_step = 0
	tutorial_complete = false
	reputation = 1.0
	game_day = 1
	game_minute = 8.0 * 60.0
	time_scale = 1
	simulation_paused = true
	inventory = {
		"raw_beef_kg": 0.0,
		"coriander": 10,
		"chilli": 8,
		"bbq": 8,
		"vinegar": 12,
		"soy_sauce": 12,
		"packaging": int(config.starting_packaging),
		"finished_coriander": 0,
		"finished_chilli": 0,
		"finished_bbq": 0
	}
	pending_delivery.clear()
	active_batch.clear()
	orders.clear()
	machine_condition = 100.0
	hygiene = 92.0
	batches_completed = 0
	lots_received = 0
	last_receiving_lot = ""
	last_supplier_quality = 0.88
	_batch_sequence = 0
	event_log.clear()
	_post(tr("Welcome to MeatCraft Empire. Choose your first premises."), "milestone")
	save_game()
	state_changed.emit()

func acquire_small_hall() -> bool:
	if property_owned or cash < float(config.small_hall_cost):
		return false
	_spend(float(config.small_hall_cost), "Small Workshop purchase")
	property_owned = true
	hall_id = "small_workshop"
	tutorial_step = maxi(tutorial_step, 1)
	_post(tr("Small Workshop acquired. Choose the MeatCraft business."), "milestone")
	save_game()
	state_changed.emit()
	return true

func select_meatcraft() -> bool:
	if not property_owned or industry_selected:
		return false
	industry_selected = true
	tutorial_step = maxi(tutorial_step, 2)
	_post(tr("MeatCraft registered — Where Health Meets Flavour."), "milestone")
	save_game()
	state_changed.emit()
	return true

func purchase_starter_line() -> bool:
	if not industry_selected or starter_line_owned or cash < float(config.starter_line_cost):
		return false
	_spend(float(config.starter_line_cost), "Starter production line")
	starter_line_owned = true
	tutorial_step = maxi(tutorial_step, 3)
	simulation_paused = false
	_post(tr("Starter line installed. Order your first beef delivery."), "milestone")
	save_game()
	state_changed.emit()
	return true

func order_beef(supplier_id: String, quantity_kg: float = 20.0) -> bool:
	if not starter_line_owned or not pending_delivery.is_empty() or quantity_kg <= 0.0:
		return false
	var supplier: Dictionary = config.suppliers.get(supplier_id, {})
	if supplier.is_empty():
		return false
	var price := float(supplier.price_per_kg) * quantity_kg
	if cash < price:
		return false
	_spend(price, "Beef procurement")
	lots_received += 1
	pending_delivery = {
		"supplier_id": supplier_id,
		"supplier_name": str(supplier.name),
		"quantity_kg": quantity_kg,
		"quality": float(supplier.quality),
		"remaining": float(supplier.lead_minutes),
		"lot_id": "BEEF-%03d-D%02d" % [lots_received, game_day]
	}
	tutorial_step = maxi(tutorial_step, 4)
	_post(tr("Beef ordered from {supplier}. Delivery van is on its way.").format({"supplier": tr(str(supplier.name))}), "info")
	save_game()
	state_changed.emit()
	return true

func start_batch(recipe_id: String, raw_kg: float = 10.0) -> bool:
	if not starter_line_owned or not active_batch.is_empty() or raw_kg <= 0.0:
		return false
	var recipe: Dictionary = config.recipes.get(recipe_id, {})
	if recipe.is_empty():
		return false
	var spice_key := str(recipe.spice)
	var spice_required := int(recipe.spice_units)
	if float(inventory.raw_beef_kg) < raw_kg or int(inventory.get(spice_key, 0)) < spice_required:
		_post(tr("Production blocked: beef or recipe ingredients are missing."), "warning")
		return false
	if int(inventory.vinegar) < 1 or int(inventory.soy_sauce) < 1:
		_post(tr("Production blocked: marination liquids are missing."), "warning")
		return false
	_batch_sequence += 1
	inventory.raw_beef_kg = snappedf(float(inventory.raw_beef_kg) - raw_kg, 0.001)
	inventory[spice_key] = int(inventory[spice_key]) - spice_required
	inventory.vinegar = int(inventory.vinegar) - 1
	inventory.soy_sauce = int(inventory.soy_sauce) - 1
	active_batch = {
		"id": "MC-%04d" % _batch_sequence,
		"recipe_id": recipe_id,
		"recipe_name": str(recipe.name),
		"stage": "preparation",
		"stage_elapsed": 0.0,
		"stage_duration": float(config.stages.preparation),
		"raw_kg": raw_kg,
		"prepared_kg": snappedf(raw_kg * float(config.preparation_yield), 0.001),
		"finished_kg": 0.0,
		"packs": 0,
		"supplier_lot": last_receiving_lot if not last_receiving_lot.is_empty() else "RECEIVING-STOCK",
		"quality": last_supplier_quality,
		"inspection_required": false,
		"inspection_done": false,
		"held": false,
		"machine_history": ["Preparation table"]
	}
	tutorial_step = maxi(tutorial_step, 5)
	_post(tr("Batch {batch} started: {recipe}.").format({"batch": active_batch.id, "recipe": tr(str(recipe.name))}), "production")
	stage_changed.emit("preparation")
	save_game()
	state_changed.emit()
	return true

func perform_mid_dry_inspection() -> bool:
	if active_batch.is_empty() or str(active_batch.stage) != "drying" or not bool(active_batch.inspection_required):
		return false
	active_batch.inspection_required = false
	active_batch.inspection_done = true
	hygiene = minf(100.0, hygiene + 1.0)
	_post(tr("Mid-cycle inspection recorded. Airflow, racks and traceability checked."), "quality")
	save_game()
	state_changed.emit()
	return true

func dispatch_order(recipe_id: String) -> bool:
	var key := "finished_" + recipe_id
	var packs := int(inventory.get(key, 0))
	if packs <= 0:
		return false
	var recipe: Dictionary = config.recipes[recipe_id]
	var revenue := packs * float(recipe.sale_per_pack)
	inventory[key] = 0
	cash += revenue
	lifetime_revenue += revenue
	reputation = minf(5.0, reputation + minf(0.18, packs * 0.002))
	_post(tr("Order dispatched: {packs} packs of {recipe}. +£{revenue}").format({"packs": packs, "recipe": tr(str(recipe.name)), "revenue": "%.2f" % revenue}), "sale")
	if batches_completed == 1:
		tutorial_step = maxi(tutorial_step, 7)
		tutorial_complete = true
	save_game()
	state_changed.emit()
	return true

func maintain_dryer() -> bool:
	var cost := float(config.maintenance_cost)
	if cash < cost or machine_condition >= 99.0:
		return false
	_spend(cost, "Preventive maintenance")
	machine_condition = minf(100.0, machine_condition + 35.0)
	_post(tr("Drying chamber serviced. Failure risk reduced."), "maintenance")
	save_game()
	state_changed.emit()
	return true

func buy_packaging() -> bool:
	var cost := float(config.packaging_restock_cost)
	if cash < cost:
		return false
	_spend(cost, "Packaging material restock")
	inventory.packaging = int(inventory.packaging) + int(config.packaging_restock_quantity)
	if not active_batch.is_empty() and bool(active_batch.get("held", false)) and str(active_batch.stage) == "packaging":
		active_batch.held = false
		_complete_stage()
	_post(tr("Packaging materials delivered to the clean storage zone."), "delivery")
	save_game()
	state_changed.emit()
	return true

func clean_factory() -> bool:
	const CLEANING_COST := 45.0
	if cash < CLEANING_COST or hygiene >= 99.0:
		return false
	_spend(CLEANING_COST, "Cleaning supplies")
	hygiene = minf(100.0, hygiene + 20.0)
	_post(tr("Cleaning round completed and recorded."), "quality")
	save_game()
	state_changed.emit()
	return true

func set_time_scale(value: int) -> void:
	time_scale = clampi(value, 1, 4)
	simulation_paused = false
	state_changed.emit()

func toggle_pause() -> void:
	simulation_paused = not simulation_paused
	state_changed.emit()

func advance_simulation(game_minutes_delta: float) -> void:
	if game_minutes_delta <= 0.0:
		return
	_advance_clock(game_minutes_delta)
	_advance_delivery(game_minutes_delta)
	_advance_batch(game_minutes_delta)
	# A slow fictional hygiene drift creates a management consequence without constant clicking.
	hygiene = maxf(35.0, hygiene - game_minutes_delta / 7200.0)
	state_changed.emit()

func _advance_clock(minutes: float) -> void:
	game_minute += minutes
	while game_minute >= 1440.0:
		game_minute -= 1440.0
		game_day += 1

func _advance_delivery(minutes: float) -> void:
	if pending_delivery.is_empty():
		return
	pending_delivery.remaining = float(pending_delivery.remaining) - minutes
	if float(pending_delivery.remaining) > 0.0:
		return
	var quantity := float(pending_delivery.quantity_kg)
	var lot := str(pending_delivery.lot_id)
	inventory.raw_beef_kg = snappedf(float(inventory.raw_beef_kg) + quantity, 0.001)
	var delivered := pending_delivery.duplicate(true)
	pending_delivery.clear()
	last_receiving_lot = lot
	last_supplier_quality = float(delivered.quality)
	_post(tr("Delivery received: {quantity} kg beef, lot {lot}. Receiving check passed.").format({"quantity": "%.1f" % quantity, "lot": lot}), "delivery")
	tutorial_step = maxi(tutorial_step, 5)
	save_game()

func _advance_batch(minutes: float) -> void:
	if active_batch.is_empty() or bool(active_batch.get("held", false)):
		return
	var remaining := minutes
	while remaining > 0.0 and not active_batch.is_empty():
		if str(active_batch.stage) == "drying" and bool(active_batch.inspection_required):
			break
		var duration := float(active_batch.stage_duration)
		var available := duration - float(active_batch.stage_elapsed)
		var step := minf(remaining, available)
		active_batch.stage_elapsed = float(active_batch.stage_elapsed) + step
		remaining -= step
		if str(active_batch.stage) == "drying" and not bool(active_batch.inspection_done) and float(active_batch.stage_elapsed) >= duration * 0.5:
			active_batch.stage_elapsed = duration * 0.5
			active_batch.inspection_required = true
			_post(tr("Batch paused at day 3.5: mid-cycle drying inspection required."), "warning")
			save_game()
			break
		if float(active_batch.stage_elapsed) + 0.0001 >= duration:
			_complete_stage()

func _complete_stage() -> void:
	var current := str(active_batch.stage)
	var index := STAGE_ORDER.find(current)
	if current == "drying":
		active_batch.finished_kg = snappedf(float(active_batch.prepared_kg) * float(config.drying_yield), 0.001)
		machine_condition = maxf(0.0, machine_condition - 4.5)
		active_batch.machine_history.append("Drying chamber DC-01")
	if current == "packaging":
		var packs := floori(float(active_batch.finished_kg) / float(config.pack_size_kg))
		if int(inventory.packaging) < packs:
			active_batch.held = true
			_post(tr("Batch held: insufficient packaging materials."), "warning")
			return
		inventory.packaging = int(inventory.packaging) - packs
		var recipe_id := str(active_batch.recipe_id)
		inventory["finished_" + recipe_id] = int(inventory.get("finished_" + recipe_id, 0)) + packs
		_spend(float(config.electricity_per_batch) + packs * float(config.packaging_cost), "Utilities and packaging")
		batches_completed += 1
		_post(tr("Batch {batch} completed: {kg} kg → {packs} × 50 g packs.").format({"batch": active_batch.id, "kg": "%.2f" % active_batch.finished_kg, "packs": packs}), "milestone")
		active_batch.clear()
		tutorial_step = maxi(tutorial_step, 6)
		stage_changed.emit("finished")
		save_game()
		return
	if index >= 0 and index + 1 < STAGE_ORDER.size():
		var next_stage: String = STAGE_ORDER[index + 1]
		active_batch.stage = next_stage
		active_batch.stage_elapsed = 0.0
		active_batch.stage_duration = float(config.stages[next_stage])
		active_batch.machine_history.append(_machine_for_stage(next_stage))
		_post(tr("Batch {batch} moved to {stage}.").format({"batch": active_batch.id, "stage": stage_name(next_stage)}), "production")
		stage_changed.emit(next_stage)
		save_game()

func stage_progress() -> float:
	if active_batch.is_empty():
		return 0.0
	return clampf(float(active_batch.stage_elapsed) / maxf(float(active_batch.stage_duration), 0.001), 0.0, 1.0)

func stage_remaining() -> float:
	if active_batch.is_empty():
		return 0.0
	return maxf(0.0, float(active_batch.stage_duration) - float(active_batch.stage_elapsed))

func game_clock_text() -> String:
	var hours := floori(game_minute / 60.0)
	var minutes := floori(game_minute) % 60
	return tr("Day {day}  {time}").format({"day": game_day, "time": "%02d:%02d" % [hours, minutes]})

func stage_name(stage: String) -> String:
	return tr({
		"preparation": "Preparation", "spice_prep": "Spice prep", "marination": "Marination",
		"hanging": "Hanging", "drying": "Drying", "slicing": "Slicing", "packaging": "Packaging"
	}.get(stage, stage.replace("_", " ")))

func snapshot() -> Dictionary:
	return {
		"version": int(config.schema_version), "cash": cash, "lifetime_revenue": lifetime_revenue,
		"lifetime_expenses": lifetime_expenses, "property_owned": property_owned, "hall_id": hall_id,
		"industry_selected": industry_selected, "starter_line_owned": starter_line_owned,
		"tutorial_step": tutorial_step, "tutorial_complete": tutorial_complete, "reputation": reputation,
		"game_day": game_day, "game_minute": game_minute, "time_scale": time_scale,
		"inventory": inventory, "pending_delivery": pending_delivery, "active_batch": active_batch,
		"orders": orders, "machine_condition": machine_condition, "hygiene": hygiene,
		"batches_completed": batches_completed, "lots_received": lots_received,
		"last_receiving_lot": last_receiving_lot, "last_supplier_quality": last_supplier_quality,
		"batch_sequence": _batch_sequence, "event_log": event_log, "language": language,
		"master_volume": master_volume, "sfx_volume": sfx_volume, "reduced_motion": reduced_motion
	}

func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != int(config.schema_version):
		return false
	cash = clampf(float(data.get("cash", config.starting_cash)), 0.0, 1.0e12)
	lifetime_revenue = maxf(0.0, float(data.get("lifetime_revenue", 0.0)))
	lifetime_expenses = maxf(0.0, float(data.get("lifetime_expenses", 0.0)))
	property_owned = bool(data.get("property_owned", false))
	hall_id = str(data.get("hall_id", ""))
	industry_selected = bool(data.get("industry_selected", false))
	starter_line_owned = bool(data.get("starter_line_owned", false))
	tutorial_step = clampi(int(data.get("tutorial_step", 0)), 0, 20)
	tutorial_complete = bool(data.get("tutorial_complete", false))
	reputation = clampf(float(data.get("reputation", 1.0)), 0.0, 5.0)
	game_day = maxi(1, int(data.get("game_day", 1)))
	game_minute = clampf(float(data.get("game_minute", 480.0)), 0.0, 1439.999)
	time_scale = clampi(int(data.get("time_scale", 1)), 1, 4)
	inventory = data.get("inventory", {}).duplicate(true)
	pending_delivery = data.get("pending_delivery", {}).duplicate(true)
	active_batch = data.get("active_batch", {}).duplicate(true)
	orders = []
	for order in data.get("orders", []):
		if order is Dictionary:
			orders.append(order.duplicate(true))
	machine_condition = clampf(float(data.get("machine_condition", 100.0)), 0.0, 100.0)
	hygiene = clampf(float(data.get("hygiene", 92.0)), 0.0, 100.0)
	batches_completed = maxi(0, int(data.get("batches_completed", 0)))
	lots_received = maxi(0, int(data.get("lots_received", 0)))
	last_receiving_lot = str(data.get("last_receiving_lot", ""))
	last_supplier_quality = clampf(float(data.get("last_supplier_quality", 0.88)), 0.0, 1.0)
	_batch_sequence = maxi(batches_completed, int(data.get("batch_sequence", batches_completed)))
	event_log = []
	for entry in data.get("event_log", []):
		if entry is Dictionary:
			event_log.append(entry.duplicate(true))
	language = str(data.get("language", "en"))
	master_volume = clampf(float(data.get("master_volume", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 0.8)), 0.0, 1.0)
	reduced_motion = bool(data.get("reduced_motion", false))
	simulation_paused = not starter_line_owned
	state_changed.emit()
	return true

func save_game() -> bool:
	var temporary := SAVE_PATH + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		save_completed.emit(false)
		return false
	file.store_string(JSON.stringify(snapshot(), "\t"))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		save_completed.emit(false)
		return false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
	ok = DirAccess.rename_absolute(temporary, SAVE_PATH) == OK
	save_exists = ok
	save_completed.emit(ok)
	return ok

func load_game() -> bool:
	for path in [SAVE_PATH, SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary:
			if restore(parser.data):
				save_exists = true
				return true
	save_exists = false
	return false

func _spend(amount: float, reason: String) -> void:
	cash = maxf(0.0, cash - amount)
	lifetime_expenses += amount
	event_log.push_front({"day": game_day, "minute": game_minute, "message": reason, "amount": -amount})
	if event_log.size() > 30:
		event_log.resize(30)

func _post(message: String, kind: String) -> void:
	event_log.push_front({"day": game_day, "minute": game_minute, "message": message, "kind": kind})
	if event_log.size() > 30:
		event_log.resize(30)
	event_posted.emit(message, kind)

func _machine_for_stage(stage: String) -> String:
	return {
		"spice_prep": "Spice station", "marination": "Marination drums", "hanging": "Rack HR-01",
		"drying": "Drying chamber DC-01", "slicing": "Slicer SL-01", "packaging": "Pack line PK-01"
	}.get(stage, "Production line")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
