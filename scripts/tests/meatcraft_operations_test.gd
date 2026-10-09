extends SceneTree
## Deterministic Mission 02 integration tests for staff, machinery, quality, contracts and v3 saves.

var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func bootstrap() -> void:
	game.new_company()
	game.acquire_small_hall()
	game.select_meatcraft()
	game.purchase_starter_line()

func employee_for_role(role_id: String) -> Dictionary:
	for employee in game.workforce.employees:
		if str(employee.role_id) == role_id:
			return employee
	return {}

func transaction_count(category: String) -> int:
	var result := 0
	for transaction in game.transactions:
		if str(transaction.category) == category:
			result += 1
	return result

func _run() -> void:
	game = root.get_node("MeatGame")
	game.set_process(false)
	game.new_company()
	check(int(game.config.schema_version) == 3, "Mission 02 uses version 3 configuration")
	check(game.workforce.employees.is_empty(), "A company without a line does not display employed factory workers")
	bootstrap()
	check(game.workforce.employees.size() == 3, "Starter line includes a viable three-person starter crew")
	check(not employee_for_role("production_operator").is_empty(), "Starter crew has a production operator")
	check(not employee_for_role("packaging_operator").is_empty(), "Starter crew has a packaging operator")
	check(not employee_for_role("quality_technician").is_empty(), "Starter crew has a quality technician")
	var before_hire: float = game.cash
	check(game.hire_employee("maintenance_technician"), "Player can hire a maintenance technician")
	check(is_equal_approx(before_hire - game.cash, 520.0), "Hiring deducts the configured recruitment cost")
	var technician := employee_for_role("maintenance_technician")
	check(not technician.is_empty() and str(technician.employee_id).begins_with("EMP-"), "Hired worker receives a unique stable ID")
	check(game.assign_employee(str(technician.employee_id), "DRY-001"), "Idle employee can be reassigned to a machine")

	# Payroll is keyed by monotonic periods and remains exact across large time jumps and reloads.
	bootstrap()
	var daily_payroll := 95.0 + 82.0 + 110.0
	var cash_before_payroll: float = game.cash
	game.advance_simulation(960.0)
	check(is_equal_approx(cash_before_payroll - game.cash, daily_payroll), "Crossing one payroll boundary charges one daily payroll")
	var cash_after_one: float = game.cash
	game.advance_simulation(30.0)
	check(is_equal_approx(game.cash, cash_after_one), "Repeated signals inside one payroll period cannot charge twice")
	game.advance_simulation(2880.0)
	check(is_equal_approx(cash_after_one - game.cash, daily_payroll * 2.0), "Large time skip charges exactly two additional payroll periods")
	var payroll_transactions := transaction_count("payroll")
	var cash_before_reload: float = game.cash
	check(game.save_game() and game.load_game(), "Workforce and payroll state survive save and reload")
	game.advance_simulation(1.0)
	check(is_equal_approx(game.cash, cash_before_reload) and transaction_count("payroll") == payroll_transactions, "Reload cannot duplicate the most recent payroll")

	# Manual production waits for qualified labour, then resumes through authoritative task completion.
	bootstrap()
	var production_worker := employee_for_role("production_operator")
	check(game.dismiss_employee(str(production_worker.employee_id)), "Idle employee can be dismissed")
	check(game.order_beef("standard", 20.0), "Operations scenario orders traceable beef")
	game.advance_simulation(240.0)
	check(game.start_batch("coriander", 10.0), "Operations scenario starts a Coriander batch")
	game.advance_simulation(90.0)
	check(game.active_batch.stage == "preparation" and game.active_batch.blocker == "missing_worker", "Preparation waits when no qualified operator exists")
	check(game.hire_employee("production_operator"), "Player can recover by hiring the missing operator")
	game.advance_simulation(90.0)
	check(game.active_batch.stage == "spice_prep", "Assigned production task completes the preparation stage exactly once")
	var replacement := employee_for_role("production_operator")
	check(float(replacement.experience) > 0.0 and float(replacement.fatigue) > 0.0, "Real work changes employee experience and fatigue")

	# Deterministic machine fault, paid repair, parts and resume.
	check(game.hire_employee("maintenance_technician"), "Technician is hired for the repair workflow")
	check(game.trigger_machine_fault("spice_prep", "test_fault"), "Deterministic machine fault can be triggered")
	game.advance_simulation(30.0)
	check(game.active_batch.stage == "spice_prep" and game.active_batch.blocker == "machine_broken", "Broken spice station blocks its production stage")
	var repair_cash: float = game.cash
	var parts_before := int(game.machinery.spare_parts.electrical_parts)
	check(game.repair_machine("spice_prep"), "Available technician can start a paid repair")
	check(is_equal_approx(repair_cash - game.cash, 180.0), "Repair deducts the stated cost once")
	check(int(game.machinery.spare_parts.electrical_parts) == parts_before - 1, "Repair consumes the required spare part")
	var repair_cash_saved: float = game.cash
	check(game.save_game() and game.load_game(), "Active repair persists through save and reload")
	check(game.machinery.status("SPICE-001") == "under_repair" and is_equal_approx(game.cash, repair_cash_saved), "Reload restores repair without charging again")
	game.advance_simulation(120.0)
	check(game.machinery.status("SPICE-001") == "idle", "Technician task restores the machine to service")
	game.advance_simulation(30.0)
	check(game.active_batch.stage == "marination", "Production resumes safely after repair")
	check(game.machinery.repair_history.size() == 1 and transaction_count("repairs") == 1, "One repair creates one history and one expense entry")

	# Serious quality incident holds the batch and requires a qualified corrective action.
	game.advance_simulation(1440.0 + 45.0)
	check(game.active_batch.stage == "drying", "Repaired production reaches the drying chamber")
	var incident_id: String = game.trigger_quality_incident("dryer_monitoring_fault", str(game.active_batch.id), "DRY-001")
	check(not incident_id.is_empty() and game.active_batch.held, "Serious quality incident quarantines the active batch")
	var held_progress := float(game.active_batch.stage_elapsed)
	game.advance_simulation(500.0)
	check(is_equal_approx(float(game.active_batch.stage_elapsed), held_progress), "Quarantined batch cannot progress")
	check(game.begin_corrective_action(incident_id, "reinspect"), "Quality technician can be assigned a corrective action")
	check(game.save_game() and game.load_game(), "Incident and active corrective task survive reload")
	game.advance_simulation(60.0)
	check(not game.active_batch.held and not game.quality.is_batch_held(str(game.active_batch.id)), "Completed corrective action releases the batch")
	check(game.quality.get_incident(incident_id).status == "resolved", "Resolved incident remains in quality history")

	# Complete the real seven-day flow and fulfil a customer order from real inventory.
	check(game.accept_contract("ORD-001"), "Small retail contract can be accepted without granting revenue")
	var revenue_before_production: float = game.lifetime_revenue
	game.advance_simulation(5040.0)
	check(game.active_batch.inspection_required, "Day 3.5 inspection remains mandatory")
	check(game.perform_mid_dry_inspection(), "Quality technician records the drying inspection")
	game.advance_simulation(5040.0 + 90.0 + 60.0)
	check(game.inventory.finished_coriander == 94, "Staffed workflow preserves the exact 94-pack mass balance")
	check(game.quality.batch_history.size() == 1 and game.quality.batch_history[0].operators.size() > 0, "Completed batch retains operators and traceability")
	check(is_equal_approx(game.lifetime_revenue, revenue_before_production), "Accepted contract does not grant money before dispatch")
	var contract_cash: float = game.cash
	check(game.dispatch_contract("ORD-001"), "Valid released inventory completes the accepted contract")
	check(game.inventory.finished_coriander == 34, "Contract dispatch consumes exactly the ordered 60 packs")
	check(is_equal_approx(game.cash - contract_cash, 261.0), "Contract credits quantity times configured unit price")
	check(game.contracts.get_order("ORD-001").status == "completed", "Completed contract has a persistent terminal status")
	var cash_after_contract: float = game.cash
	check(not game.dispatch_contract("ORD-001") and is_equal_approx(game.cash, cash_after_contract), "Completed contract cannot be rewarded twice")
	check(transaction_count("payroll") > 0 and transaction_count("contracts") == 1, "Financial ledger records payroll and contract revenue")

	# A held finished batch cannot bypass the dispatch gate.
	var finished_batch_id := str(game.quality.batch_history[0].batch_id)
	var finished_incident: String = game.trigger_quality_incident("allergen_label_error", finished_batch_id, "PACK-001")
	check(not finished_incident.is_empty() and not game.dispatch_order("coriander"), "Quality hold blocks legacy open-market dispatch too")
	check(game.begin_corrective_action(finished_incident, "relabel"), "Finished inventory can receive an explicit corrective action")
	game.advance_simulation(60.0)
	check(game.quality.get_incident(finished_incident).status == "resolved", "Finished-batch corrective action resolves without duplicating stock")

	# Synthetic v2 migration keeps progress while creating safe defaults for every new subsystem.
	bootstrap()
	game.inventory.raw_beef_kg = 10.0
	game.start_batch("chilli", 10.0)
	game.advance_simulation(200.0)
	var old_v2: Dictionary = game.snapshot()
	old_v2.version = 2
	for key in ["workforce", "machinery", "quality", "contracts", "transactions"]:
		old_v2.erase(key)
	var migrated: Dictionary = game._migrate_v2(old_v2)
	check(int(old_v2.version) == 2 and int(migrated.version) == 3, "Migration does not overwrite the original v2 data")
	check(migrated.has("workforce") and migrated.has("machinery") and migrated.has("quality") and migrated.has("contracts"), "Migration creates every mandatory version 3 subsystem")
	check(game.restore(migrated), "Migrated v2 snapshot restores as a valid v3 game")
	check(game.active_batch.stage == "marination" and game.workforce.employees.size() == 3, "Migration preserves active production and supplies the viable starter crew")
	var migrated_cash: float = game.cash
	var migrated_beef := float(game.inventory.raw_beef_kg)
	check(game.save_game() and game.load_game(), "Migrated state writes and reloads in the v3 save location")
	check(is_equal_approx(game.cash, migrated_cash) and is_equal_approx(float(game.inventory.raw_beef_kg), migrated_beef), "Migration and reload do not duplicate cash or inventory")

	print("MEATCRAFT OPERATIONS RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
