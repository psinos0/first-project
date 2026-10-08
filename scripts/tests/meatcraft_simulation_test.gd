extends SceneTree
## Isolated deterministic test for the complete MeatCraft pipeline.

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

func _run() -> void:
	game = root.get_node("MeatGame")
	game.set_process(false)
	game.new_company()
	check(is_equal_approx(game.cash, 48000.0), "New company receives configured capital")
	check(not game.starter_line_owned and game.inventory.raw_beef_kg == 0.0, "New company starts without factory equipment or free beef")
	check(game.acquire_small_hall(), "Small Workshop can be acquired")
	check(is_equal_approx(game.cash, 36000.0) and game.hall_id == "small_workshop", "Property purchase deducts exactly £12,000")
	check(not game.acquire_small_hall(), "Property cannot be purchased twice")
	check(game.select_meatcraft() and game.industry_selected, "MeatCraft business selection works")
	check(game.purchase_starter_line(), "Starter production line can be installed")
	check(is_equal_approx(game.cash, 19500.0), "Starter line deducts its configured cost")
	check(game.order_beef("standard", 20.0), "Standard supplier accepts a 20 kg order")
	check(is_equal_approx(game.cash, 19352.0), "Procurement deducts supplier price × mass")
	check(not game.order_beef("premium", 20.0), "Only one inbound delivery can occupy receiving")
	game.advance_simulation(239.0)
	check(game.inventory.raw_beef_kg == 0.0, "Beef is not credited before delivery arrival")
	game.advance_simulation(1.0)
	check(is_equal_approx(game.inventory.raw_beef_kg, 20.0) and game.pending_delivery.is_empty(), "Arrival credits exactly 20 kg and clears inbound delivery")
	check(not game.start_batch("missing", 10.0), "Unknown recipes cannot start")
	var coriander_before: int = game.inventory.coriander
	check(game.start_batch("coriander", 10.0), "Coriander batch starts with available inputs")
	check(is_equal_approx(game.inventory.raw_beef_kg, 10.0), "Batch consumes exactly 10 kg raw beef")
	check(game.inventory.coriander == coriander_before - 2 and game.inventory.vinegar == 11 and game.inventory.soy_sauce == 11, "Seasoning and marination ingredients are conserved")
	check(not game.start_batch("chilli", 10.0), "Parallel batch cannot duplicate the single starter line")
	game.advance_simulation(90.0)
	check(game.active_batch.stage == "spice_prep", "Preparation advances to spice preparation")
	game.advance_simulation(30.0 + 1440.0 + 45.0)
	check(game.active_batch.stage == "drying", "Spice, marination and hanging reach the drying chamber")
	check(is_equal_approx(game.active_batch.prepared_kg, 9.4), "Preparation yield records 9.4 kg from 10 kg raw")
	game.advance_simulation(5040.0)
	check(game.active_batch.stage == "drying" and game.active_batch.inspection_required, "Drying pauses at day 3.5 for an actual inspection")
	var held_elapsed: float = game.active_batch.stage_elapsed
	game.advance_simulation(1000.0)
	check(is_equal_approx(game.active_batch.stage_elapsed, held_elapsed), "Required inspection prevents hidden drying progress")
	check(game.perform_mid_dry_inspection(), "Mid-cycle inspection is recorded")
	game.advance_simulation(5040.0 + 90.0 + 60.0)
	check(game.active_batch.is_empty() and game.batches_completed == 1, "Inspected batch completes slicing and packaging")
	check(game.inventory.finished_coriander == 94, "9.4 kg prepared × 50% yield creates exactly 94 × 50 g packs")
	check(game.inventory.packaging == 120 - 94, "Packaging consumption matches saleable pack count")
	check(game.inventory.finished_coriander == 94, "Completed mass remains bounded after packaging")
	var before_sale: float = game.cash
	check(game.dispatch_order("coriander"), "Finished products can be dispatched")
	check(game.inventory.finished_coriander == 0 and game.cash > before_sale, "Dispatch consumes inventory and credits revenue once")
	var after_sale: float = game.cash
	check(not game.dispatch_order("coriander") and is_equal_approx(game.cash, after_sale), "Empty inventory cannot generate duplicate revenue")
	check(str(game.config.recipes.bbq.claim).contains("sugar and honey"), "BBQ is never presented as sugar-free")
	check(game.config.recipes.coriander.allergens.has("soy") and game.config.recipes.coriander.allergens.has("gluten"), "Recipe allergen data includes soy and gluten")
	game.machine_condition = 55.0
	var before_maintenance: float = game.cash
	check(game.maintain_dryer() and game.machine_condition == 90.0, "Preventive maintenance restores dryer condition")
	check(is_equal_approx(before_maintenance - game.cash, 280.0), "Maintenance deducts configured cost")
	game.hygiene = 70.0
	check(game.clean_factory() and game.hygiene == 90.0, "Cleaning consumes resources and improves the hygiene meter")
	# Active marination survives a versioned save without resource duplication.
	game.inventory.raw_beef_kg = 10.0
	check(game.start_batch("chilli", 10.0), "Second recipe can enter production")
	game.advance_simulation(200.0)
	var saved_cash: float = game.cash
	var saved_beef: float = game.inventory.raw_beef_kg
	var saved_elapsed: float = game.active_batch.stage_elapsed
	check(game.save_game(), "Version 2 save writes atomically")
	game.cash = 1.0
	game.inventory.raw_beef_kg = 999.0
	game.active_batch.clear()
	check(game.load_game(), "Version 2 save loads")
	check(is_equal_approx(game.cash, saved_cash) and is_equal_approx(game.inventory.raw_beef_kg, saved_beef), "Load restores cash and inventory without duplication")
	check(game.active_batch.stage == "marination" and is_equal_approx(game.active_batch.stage_elapsed, saved_elapsed), "Active marination timer survives restart")
	print("MEATCRAFT RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
