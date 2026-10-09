extends Node
## Authoritative MeatCraft simulation. Presentation observes signals and never owns inventory.

signal state_changed
signal event_posted(message: String, kind: String)
signal stage_changed(stage: String)
signal save_completed(ok: bool)

const CONFIG_PATH := "res://config/meatcraft_game.json"
const SAVE_PATH := "user://meatcraft_v3.json"
const LEGACY_SAVE_PATH := "user://meatcraft_v2.json"
const STAGE_ORDER := ["preparation", "spice_prep", "marination", "hanging", "drying", "slicing", "packaging"]
const MANUAL_STAGE_ROLES := {
	"preparation": "production_operator", "spice_prep": "production_operator",
	"hanging": "production_operator", "slicing": "production_operator",
	"packaging": "packaging_operator"
}

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
var transactions: Array[Dictionary] = []
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
var workforce: WorkforceSystem = preload("res://scripts/meatcraft/workforce_system.gd").new()
var machinery: MachineSystem = preload("res://scripts/meatcraft/machine_system.gd").new()
var quality: QualitySystem = preload("res://scripts/meatcraft/quality_system.gd").new()
var contracts: ContractSystem = preload("res://scripts/meatcraft/contract_system.gd").new()

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
	transactions.clear()
	machine_condition = 100.0
	hygiene = 92.0
	batches_completed = 0
	lots_received = 0
	last_receiving_lot = ""
	last_supplier_quality = 0.88
	_batch_sequence = 0
	workforce.reset(config.workforce, absolute_game_minutes())
	machinery.reset(config.machines)
	quality.reset(config.quality)
	contracts.reset(config.contracts, absolute_game_minutes())
	orders = contracts.orders
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
	workforce.seed_starter_crew()
	_assign_starter_crew()
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
		"hold_reason": "",
		"quality_status": "released",
		"task_id": "",
		"marination_loaded": false,
		"assigned_operators": [],
		"started_day": game_day,
		"started_minute": game_minute,
		"machine_history": ["Preparation table"],
		"inspection_history": []
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
	if not workforce.complete_instant_task("mid_cycle_inspection", "quality_technician", "DRY-001", str(active_batch.id)):
		_post(tr("Inspection waiting: a Quality Technician is required."), "warning")
		return false
	var inspector := _last_completed_worker("mid_cycle_inspection", str(active_batch.id))
	active_batch.inspection_required = false
	active_batch.inspection_done = true
	active_batch.inspection_history.append({"day": game_day, "minute": game_minute, "employee_id": inspector, "result": "passed"})
	quality.record_inspection(str(active_batch.id), inspector, "passed", game_day, game_minute)
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
	if quality.has_held_finished_recipe(recipe_id):
		_post(tr("Dispatch blocked: a finished batch is in quality quarantine."), "warning")
		return false
	var recipe: Dictionary = config.recipes[recipe_id]
	var revenue := packs * float(recipe.sale_per_pack)
	inventory[key] = 0
	_earn(revenue, "Open-market dispatch", "sales")
	reputation = minf(5.0, reputation + minf(0.18, packs * 0.002))
	quality.consume_finished(recipe_id, packs, "OPEN-MARKET", game_day, game_minute)
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
	if machinery.records.has("DRY-001"):
		var dryer: Dictionary = machinery.records["DRY-001"]
		dryer.condition = machine_condition
		dryer.wear = 100.0 - machine_condition
		dryer.last_service_hours = float(dryer.running_hours)
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
	if not workforce.complete_instant_task("cleaning", "quality_technician", "PREP-001", "FACTORY"):
		_post(tr("Cleaning waiting: a Quality Technician is required."), "warning")
		return false
	_spend(CLEANING_COST, "Cleaning supplies")
	hygiene = minf(100.0, hygiene + 20.0)
	_post(tr("Cleaning round completed and recorded."), "quality")
	save_game()
	state_changed.emit()
	return true

func hire_employee(role_id: String) -> bool:
	var role: Dictionary = config.workforce.roles.get(role_id, {})
	if role.is_empty() or cash < float(role.hire_cost):
		return false
	var result := workforce.hire(role_id)
	if not bool(result.get("ok", false)):
		return false
	_spend(float(result.cost), "Employee recruitment", "payroll")
	_post(tr("{name} joined the team as {role}.").format({"name": result.employee.display_name, "role": tr(str(role.name))}), "milestone")
	save_game()
	state_changed.emit()
	return true

func dismiss_employee(employee_id: String) -> bool:
	if not workforce.dismiss(employee_id):
		return false
	_post(tr("Employee contract ended. Active work was not interrupted."), "info")
	save_game()
	state_changed.emit()
	return true

func assign_employee(employee_id: String, machine_id: String) -> bool:
	var ok := workforce.assign_machine(employee_id, machine_id)
	if ok:
		save_game()
		state_changed.emit()
	return ok

func trigger_machine_fault(machine_id: String, fault_type: String = "test_fault") -> bool:
	var record_id := _record_id(machine_id)
	if not machinery.trigger_fault(record_id, fault_type):
		return false
	var record: Dictionary = machinery.records[record_id]
	_post(tr("Machine fault: {machine}. {fault}").format({"machine": tr(str(record.display_name)), "fault": tr(str(record.fault_state.description))}), "critical")
	if record_id == "DRY-001" and not active_batch.is_empty() and str(active_batch.stage) == "drying":
		trigger_quality_incident("dryer_monitoring_fault", str(active_batch.id), record_id)
	save_game()
	state_changed.emit()
	return true

func repair_machine(machine_id: String) -> bool:
	var record_id := _record_id(machine_id)
	var requirements := machinery.repair_requirements(record_id)
	if requirements.is_empty() or not bool(requirements.part_available) or cash < float(requirements.cost):
		return false
	if not workforce.has_available_role("maintenance_technician"):
		if machinery.records.has(record_id):
			machinery.records[record_id].operating_status = "waiting_for_technician"
		_post(tr("Repair waiting: hire an available Maintenance Technician."), "warning")
		return false
	var task_id := workforce.create_task("repair", "maintenance_technician", record_id, "", float(requirements.duration), 100)
	var task := workforce.get_task(task_id)
	if str(task.get("assigned_employee_id", "")).is_empty() or not machinery.begin_repair(record_id, task_id):
		return false
	task.machine_record_id = record_id
	_spend(float(requirements.cost), "Machine repair", "repairs")
	_post(tr("Repair started on {machine}.").format({"machine": tr(str(machinery.records[record_id].display_name))}), "maintenance")
	save_game()
	state_changed.emit()
	return true

func restock_spare_parts() -> bool:
	var cost := float(config.machines.parts_restock_cost)
	if cash < cost:
		return false
	_spend(cost, "Spare-parts restock", "repairs")
	machinery.restock_parts()
	_post(tr("Spare-parts cabinet restocked."), "delivery")
	save_game()
	state_changed.emit()
	return true

func trigger_quality_incident(incident_type: String, batch_id := "", machine_id := "") -> String:
	if batch_id.is_empty() and not active_batch.is_empty():
		batch_id = str(active_batch.id)
	var incident := quality.trigger_incident(incident_type, batch_id, machine_id, game_day, game_minute)
	if incident.is_empty():
		return ""
	if not active_batch.is_empty() and str(active_batch.id) == batch_id and quality.is_batch_held(batch_id):
		active_batch.held = true
		active_batch.hold_reason = "quality"
		active_batch.quality_status = "quarantined"
	_post(tr("Quality incident {id}: batch {batch} is under review.").format({"id": incident.incident_id, "batch": batch_id}), "critical")
	save_game()
	state_changed.emit()
	return str(incident.incident_id)

func begin_corrective_action(incident_id: String, action: String) -> bool:
	var incident := quality.get_incident(incident_id)
	if incident.is_empty() or not workforce.has_available_role("quality_technician"):
		return false
	var task_id := workforce.create_task("quality_action", "quality_technician", str(incident.related_equipment), str(incident.related_batch), float(config.quality.corrective_action_duration), 95)
	var task := workforce.get_task(task_id)
	if str(task.get("assigned_employee_id", "")).is_empty():
		return false
	task.incident_id = incident_id
	task.corrective_action = action
	if not quality.begin_corrective_action(incident_id, str(task.assigned_employee_id), task_id):
		return false
	_post(tr("Corrective action assigned to {name}.").format({"name": workforce.get_employee(str(task.assigned_employee_id)).display_name}), "quality")
	save_game()
	state_changed.emit()
	return true

func accept_contract(order_id: String) -> bool:
	if not contracts.accept_order(order_id):
		return false
	_post(tr("Customer contract {order} accepted. Revenue is paid only after valid dispatch.").format({"order": order_id}), "info")
	save_game()
	state_changed.emit()
	return true

func dispatch_contract(order_id: String) -> bool:
	var order := contracts.get_order(order_id)
	if order.is_empty() or str(order.status) not in ["accepted", "in_production", "ready_for_dispatch"]:
		return false
	var recipe_id := str(order.recipe_id)
	if quality.has_held_finished_recipe(recipe_id):
		_post(tr("Dispatch blocked by quality quarantine."), "warning")
		return false
	var packs := int(inventory.get("finished_" + recipe_id, 0))
	var ready := contracts.ready_orders(recipe_id, packs, _finished_quality(recipe_id), absolute_game_minutes())
	if not ready.has(order):
		return false
	var result := contracts.complete_order(order_id, absolute_game_minutes())
	if not bool(result.get("ok", false)):
		return false
	inventory["finished_" + recipe_id] = packs - int(order.quantity)
	quality.consume_finished(recipe_id, int(order.quantity), order_id, game_day, game_minute)
	_earn(float(result.reward), "Customer contract " + order_id, "contracts")
	reputation = minf(5.0, reputation + 0.25)
	_post(tr("Contract {order} completed. +£{reward}").format({"order": order_id, "reward": "%.2f" % float(result.reward)}), "sale")
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
	workforce.begin_tick()
	_advance_clock(game_minutes_delta)
	_process_payroll()
	_advance_delivery(game_minutes_delta)
	_advance_batch(game_minutes_delta)
	_advance_background_tasks(game_minutes_delta)
	workforce.end_tick(game_minutes_delta)
	_process_contract_deadlines()
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
		var stage := str(active_batch.stage)
		if quality.is_batch_held(str(active_batch.id)):
			active_batch.held = true
			active_batch.hold_reason = "quality"
			active_batch.blocker = "quality_hold"
			break
		var machine_id := machinery.machine_for_stage(stage)
		if not machinery.can_operate(machine_id):
			active_batch.blocker = "machine_broken"
			break
		if stage == "drying" and bool(active_batch.inspection_required):
			active_batch.blocker = "inspection_required"
			break
		if stage == "marination" and not bool(active_batch.get("marination_loaded", false)):
			var load_result := _advance_manual_stage("load_marination", "production_operator", machine_id, minf(30.0, float(active_batch.stage_duration)), remaining)
			var load_used := float(load_result.get("used", 0.0))
			remaining -= load_used
			active_batch.stage_elapsed = float(active_batch.stage_elapsed) + load_used
			machinery.advance_operation(machine_id, load_used)
			if bool(load_result.get("completed", false)):
				active_batch.marination_loaded = true
				active_batch.task_id = ""
				active_batch.blocker = ""
				continue
			active_batch.blocker = "missing_worker" if load_used <= 0.0 else "worker_task"
			break
		if MANUAL_STAGE_ROLES.has(stage):
			var manual_result := _advance_manual_stage(stage, str(MANUAL_STAGE_ROLES[stage]), machine_id, maxf(1.0, float(active_batch.stage_duration) - float(active_batch.stage_elapsed)), remaining)
			var used := float(manual_result.get("used", 0.0))
			remaining -= used
			active_batch.stage_elapsed = float(active_batch.stage_elapsed) + used
			machinery.advance_operation(machine_id, used)
			if bool(manual_result.get("completed", false)):
				active_batch.task_id = ""
				active_batch.blocker = ""
				_complete_stage()
				continue
			active_batch.blocker = "missing_worker" if used <= 0.0 else "worker_task"
			break
		var duration := float(active_batch.stage_duration)
		var available := duration - float(active_batch.stage_elapsed)
		var step := minf(remaining, available)
		active_batch.stage_elapsed = float(active_batch.stage_elapsed) + step
		active_batch.blocker = ""
		machinery.advance_operation(machine_id, step)
		if machine_id == "DRY-001":
			machine_condition = machinery.condition(machine_id)
		remaining -= step
		if stage == "drying" and not bool(active_batch.inspection_done) and float(active_batch.stage_elapsed) >= duration * 0.5:
			active_batch.stage_elapsed = duration * 0.5
			active_batch.inspection_required = true
			active_batch.blocker = "inspection_required"
			_post(tr("Batch paused at day 3.5: mid-cycle drying inspection required."), "warning")
			save_game()
			break
		if float(active_batch.stage_elapsed) + 0.0001 >= duration:
			_complete_stage()

func _complete_stage() -> void:
	var current := str(active_batch.stage)
	var index := STAGE_ORDER.find(current)
	var current_machine := machinery.machine_for_stage(current)
	machinery.mark_idle(current_machine)
	if current == "drying":
		active_batch.finished_kg = snappedf(float(active_batch.prepared_kg) * float(config.drying_yield), 0.001)
		machine_condition = machinery.condition("DRY-001")
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
		active_batch.packs = packs
		_spend(float(config.electricity_per_batch) + packs * float(config.packaging_cost), "Utilities and packaging")
		batches_completed += 1
		quality.record_completed_batch({
			"batch_id": str(active_batch.id), "recipe_id": recipe_id, "recipe_name": str(active_batch.recipe_name),
			"supplier_lot": str(active_batch.supplier_lot), "raw_kg": float(active_batch.raw_kg),
			"prepared_kg": float(active_batch.prepared_kg), "finished_kg": float(active_batch.finished_kg),
			"packs": packs, "remaining_packs": packs, "quality": float(active_batch.quality),
			"quality_status": "released", "operators": active_batch.assigned_operators.duplicate(true),
			"inspection_history": active_batch.inspection_history.duplicate(true),
			"completed_day": game_day, "completed_minute": game_minute, "machine_history": active_batch.machine_history.duplicate(true)
		})
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
		active_batch.task_id = ""
		active_batch.blocker = ""
		active_batch.marination_loaded = false
		active_batch.machine_history.append(_machine_for_stage(next_stage))
		_post(tr("Batch {batch} moved to {stage}.").format({"batch": active_batch.id, "stage": stage_name(next_stage)}), "production")
		stage_changed.emit(next_stage)
		save_game()

func _advance_manual_stage(task_type: String, role_id: String, machine_id: String, duration: float, available_minutes: float) -> Dictionary:
	var task_id := str(active_batch.get("task_id", ""))
	var task := workforce.get_task(task_id)
	if task.is_empty() or str(task.get("state", "")) == "completed" or str(task.get("task_type", "")) != task_type:
		task_id = workforce.create_task(task_type, role_id, machine_id, str(active_batch.id), duration, 70)
		active_batch.task_id = task_id
		task = workforce.get_task(task_id)
	if task.is_empty():
		return {"used": 0.0, "completed": false}
	var result := workforce.advance_task(task_id, available_minutes)
	var employee_id := str(task.get("assigned_employee_id", ""))
	if not active_batch.assigned_operators.has(employee_id):
		if not employee_id.is_empty():
			active_batch.assigned_operators.append(employee_id)
	return result

func _advance_background_tasks(minutes: float) -> void:
	for task in workforce.active_tasks():
		if str(task.task_type) not in ["repair", "quality_action"]:
			continue
		var result := workforce.advance_task(str(task.task_id), minutes)
		if not bool(result.get("completed", false)) or bool(task.get("completion_applied", false)):
			continue
		task.completion_applied = true
		if str(task.task_type) == "repair":
			var machine_id := str(task.get("machine_record_id", task.machine_id))
			if machinery.complete_repair(machine_id, game_day, game_minute):
				_post(tr("{machine} repaired and returned to service.").format({"machine": tr(str(machinery.records[machine_id].display_name))}), "maintenance")
		elif str(task.task_type) == "quality_action":
			var resolution := quality.complete_corrective_action(str(task.get("incident_id", "")), str(task.get("corrective_action", "")))
			if bool(resolution.get("ok", false)):
				_apply_quality_resolution(str(resolution.batch_id), bool(resolution.rejected))
				_post(tr("Corrective action completed. Batch status updated."), "quality")

func _process_payroll() -> void:
	for payroll in workforce.process_payroll(absolute_game_minutes()):
		var paid := minf(cash, float(payroll.due))
		if paid > 0.0:
			_spend(paid, "Payroll period %d" % int(payroll.period), "payroll")
		workforce.settle_payroll(payroll, paid)
		if workforce.payroll_debt > 0.0:
			_post(tr("Payroll partially unpaid: £{debt} remains due.").format({"debt": "%.2f" % workforce.payroll_debt}), "critical")
		else:
			_post(tr("Payroll completed: £{amount}.").format({"amount": "%.2f" % paid}), "finance")

func _process_contract_deadlines() -> void:
	for order in contracts.update_deadlines(absolute_game_minutes()):
		var penalty := minf(cash, float(order.penalty))
		if penalty > 0.0:
			_spend(penalty, "Failed contract " + str(order.order_id), "contracts")
		_post(tr("Contract {order} missed its deadline.").format({"order": order.order_id}), "warning")

func _apply_quality_resolution(batch_id: String, rejected: bool) -> void:
	if not active_batch.is_empty() and str(active_batch.id) == batch_id:
		if rejected:
			active_batch.clear()
			stage_changed.emit("rejected")
		else:
			active_batch.held = false
			active_batch.hold_reason = ""
			active_batch.quality_status = "released"
			active_batch.blocker = ""
	if rejected:
		for record in quality.batch_history:
			if str(record.get("batch_id", "")) == batch_id:
				var key := "finished_" + str(record.recipe_id)
				inventory[key] = maxi(0, int(inventory.get(key, 0)) - int(record.get("remaining_packs", 0)))
				record.remaining_packs = 0
				record.quality_status = "rejected"

func _assign_starter_crew() -> void:
	for employee in workforce.employees:
		match str(employee.role_id):
			"production_operator": employee.assigned_machine_id = "PREP-001"
			"packaging_operator": employee.assigned_machine_id = "PACK-001"
			"quality_technician": employee.assigned_machine_id = "DRY-001"

func _last_completed_worker(task_type: String, batch_id: String) -> String:
	for index in range(workforce.tasks.size() - 1, -1, -1):
		var task: Dictionary = workforce.tasks[index]
		if str(task.task_type) == task_type and str(task.batch_id) == batch_id and str(task.state) == "completed":
			return str(task.assigned_employee_id)
	return ""

func _record_id(machine_id: String) -> String:
	if machinery.records.has(machine_id):
		return machine_id
	for record_id in machinery.records:
		if str(machinery.records[record_id].machine_type) == machine_id:
			return str(record_id)
	return machine_id

func machine_record(machine_id: String) -> Dictionary:
	return machinery.records.get(_record_id(machine_id), {})

func _finished_quality(recipe_id: String) -> float:
	var total := 0.0
	var count := 0
	for record in quality.batch_history:
		if str(record.get("recipe_id", "")) == recipe_id and int(record.get("remaining_packs", 0)) > 0:
			total += float(record.get("quality", 0.0))
			count += 1
	return total / count if count > 0 else 0.0

func absolute_game_minutes() -> float:
	return float(game_day - 1) * 1440.0 + game_minute

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
		"master_volume": master_volume, "sfx_volume": sfx_volume, "reduced_motion": reduced_motion,
		"transactions": transactions, "workforce": workforce.snapshot(), "machinery": machinery.snapshot(),
		"quality": quality.snapshot(), "contracts": contracts.snapshot()
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
	transactions.clear()
	for transaction in data.get("transactions", []):
		if transaction is Dictionary:
			transactions.append(transaction.duplicate(true))
	workforce.restore(data.get("workforce", {}), config.workforce, absolute_game_minutes())
	machinery.restore(data.get("machinery", {}), config.machines)
	quality.restore(data.get("quality", {}), config.quality)
	contracts.restore(data.get("contracts", {}), config.contracts, absolute_game_minutes())
	orders = contracts.orders
	if starter_line_owned and workforce.employees.is_empty():
		workforce.seed_starter_crew()
		_assign_starter_crew()
	if machinery.records.has("DRY-001"):
		machine_condition = machinery.condition("DRY-001")
	_normalize_active_batch()
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
	for path in [LEGACY_SAVE_PATH, LEGACY_SAVE_PATH + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) == OK and parser.data is Dictionary and int(parser.data.get("version", 0)) == 2:
			var migrated := _migrate_v2(parser.data)
			if restore(migrated):
				save_game()
				save_exists = true
				_post(tr("Previous MeatCraft save migrated safely to version 3."), "milestone")
				return true
	save_exists = false
	return false

func _migrate_v2(source: Dictionary) -> Dictionary:
	var migrated := source.duplicate(true)
	migrated.version = int(config.schema_version)
	var absolute_minute := float(maxi(1, int(source.get("game_day", 1))) - 1) * 1440.0 + clampf(float(source.get("game_minute", 480.0)), 0.0, 1439.999)
	var migrated_workforce := WorkforceSystem.new()
	migrated_workforce.reset(config.workforce, absolute_minute)
	if bool(source.get("starter_line_owned", false)):
		migrated_workforce.seed_starter_crew()
	migrated.workforce = migrated_workforce.snapshot()
	var migrated_machinery := MachineSystem.new()
	migrated_machinery.reset(config.machines)
	var old_condition := clampf(float(source.get("machine_condition", 100.0)), 0.0, 100.0)
	migrated_machinery.records["DRY-001"].condition = old_condition
	migrated_machinery.records["DRY-001"].wear = 100.0 - old_condition
	migrated.machinery = migrated_machinery.snapshot()
	var migrated_quality := QualitySystem.new()
	migrated_quality.reset(config.quality)
	var old_inventory: Dictionary = source.get("inventory", {})
	for recipe_id in ["coriander", "chilli", "bbq"]:
		var packs := int(old_inventory.get("finished_" + recipe_id, 0))
		if packs > 0:
			migrated_quality.record_completed_batch({
				"batch_id": "LEGACY-" + recipe_id.to_upper(), "recipe_id": recipe_id,
				"recipe_name": str(config.recipes[recipe_id].name), "supplier_lot": str(source.get("last_receiving_lot", "LEGACY-STOCK")),
				"packs": packs, "remaining_packs": packs, "quality": float(source.get("last_supplier_quality", 0.88)),
				"quality_status": "released", "operators": [], "inspection_history": [], "machine_history": []
			})
	migrated.quality = migrated_quality.snapshot()
	var migrated_contracts := ContractSystem.new()
	migrated_contracts.reset(config.contracts, absolute_minute)
	migrated.contracts = migrated_contracts.snapshot()
	migrated.transactions = []
	return migrated

func _normalize_active_batch() -> void:
	if active_batch.is_empty():
		return
	var defaults := {
		"hold_reason": "quality" if quality.is_batch_held(str(active_batch.get("id", ""))) else "",
		"quality_status": "quarantined" if quality.is_batch_held(str(active_batch.get("id", ""))) else "released",
		"task_id": "", "marination_loaded": str(active_batch.get("stage", "")) != "marination",
		"assigned_operators": [], "inspection_history": [], "blocker": "",
		"started_day": game_day, "started_minute": game_minute
	}
	for key in defaults:
		if not active_batch.has(key):
			active_batch[key] = defaults[key]

func _spend(amount: float, reason: String, category := "operating") -> void:
	cash = maxf(0.0, cash - amount)
	lifetime_expenses += amount
	event_log.push_front({"day": game_day, "minute": game_minute, "message": reason, "amount": -amount})
	_record_transaction(-amount, reason, category)
	if event_log.size() > 30:
		event_log.resize(30)

func _earn(amount: float, reason: String, category := "sales") -> void:
	cash += amount
	lifetime_revenue += amount
	_record_transaction(amount, reason, category)

func _record_transaction(amount: float, reason: String, category: String) -> void:
	transactions.push_front({
		"id": "TX-%05d" % (transactions.size() + 1), "day": game_day, "minute": game_minute,
		"amount": amount, "reason": reason, "category": category, "balance": cash
	})
	if transactions.size() > 100:
		transactions.resize(100)

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
