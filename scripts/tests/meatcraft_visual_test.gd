extends SceneTree
## Real-render visual and integration checks. Requires a graphics display.

var failures := 0
var checks := 0
var main: Node
var game: Node
var output := "/tmp"

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func capture(filename: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output.path_join(filename))
	check(error == OK, "Captured " + filename)

func _run() -> void:
	if not OS.get_environment("CRAFT_CAPTURE_DIR").is_empty():
		output = OS.get_environment("CRAFT_CAPTURE_DIR")
	game = root.get_node("MeatGame")
	game.set_process(false)
	game.new_company()
	main = load("res://scenes/meatcraft_main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	check(main.factory.machines.size() == 8, "Eight functional 3D machine/area selection targets exist")
	check(main.factory.meat_strips.size() == 21, "Drying chamber contains 21 individually generated strips")
	check(main.factory.fans.size() == 2 and main.factory.workers.size() == 8, "Dryer fans and workforce visual slots are instantiated")
	await capture("main_menu.png")
	main.ui.show_property_selection()
	await capture("property_selection.png")
	check(game.acquire_small_hall() and game.select_meatcraft() and game.purchase_starter_line(), "Acquisition flow prepares the starter factory")
	main.ui.show_factory()
	await capture("starter_factory.png")
	check(main.factory.workers.filter(func(worker: Node3D): return worker.visible).size() == 3, "Exactly the employed starter crew is visible in 3D")
	main.ui.current_tab = "employees"
	main.ui._refresh_ui()
	check(main.ui.panel_body.get_child_count() >= 5 and main.ui.panel_body.size.y > 100.0, "Employee management panel renders scrollable content")
	await capture("workforce_management.png")
	var dryer_point: Vector2 = main.camera_rig.camera.unproject_position(main.factory.machines.dryer.global_position + Vector3(0, 2.2, 0))
	var picked: String = main.factory.pick_from_screen(main.camera_rig.camera, dryer_point)
	check(picked == "dryer", "Rendered dryer can be selected through its 3D collider")
	check(game.order_beef("standard", 20.0), "Visual run orders real inventory")
	game.advance_simulation(240.0)
	check(game.start_batch("coriander", 10.0), "Visual run starts a traced Coriander batch")
	main.ui._refresh_ui()
	await capture("production_line.png")
	game.advance_simulation(10.0)
	await create_timer(0.8).timeout
	await capture("living_workers.png")
	check(not game.workforce.active_tasks().is_empty(), "Moving worker represents an authoritative production task")
	game.advance_simulation(80.0 + 30.0 + 1440.0 + 45.0)
	main.ui.current_tab = "production"
	main.ui._refresh_ui()
	main.camera_rig.focus(main.factory.machines.dryer.global_position, 17.0)
	await create_timer(0.5).timeout
	await capture("drying_chamber.png")
	game.advance_simulation(5040.0)
	main.ui._refresh_ui()
	await capture("mid_cycle_inspection.png")
	check(game.active_batch.inspection_required, "Inspection screenshot represents a real paused state")
	game.perform_mid_dry_inspection()
	game.advance_simulation(5040.0 + 90.0)
	main.ui.machine_selected("packaging")
	main.ui.current_tab = "machine"
	main.ui._refresh_ui()
	main.camera_rig.focus(main.factory.machines.packaging.global_position, 12.5)
	await create_timer(0.5).timeout
	await capture("packaging_station.png")
	game.advance_simulation(60.0)
	main.ui.current_tab = "production"
	main.ui._refresh_ui()
	await capture("finished_order.png")
	check(game.inventory.finished_coriander == 94, "Visual loop ends with the correct finished inventory")
	check(game.accept_contract("ORD-001"), "Rendered contract panel uses a real accepted order")
	main.ui.current_tab = "orders"
	main.ui._refresh_ui()
	check(main.ui.panel_body.get_child_count() >= 3 and main.ui.panel_body.size.y > 100.0, "Contract panel renders order cards")
	await capture("customer_contracts.png")
	var finished_batch_id := str(game.quality.batch_history[0].batch_id)
	var incident_id: String = game.trigger_quality_incident("allergen_label_error", finished_batch_id, "PACK-001")
	main.ui.current_tab = "haccp"
	main.ui._refresh_ui()
	check(main.ui.panel_body.get_child_count() >= 4 and main.ui.panel_body.size.y > 100.0, "HACCP panel renders incident and history content")
	await capture("quality_quarantine.png")
	check(not game.dispatch_order("coriander"), "Rendered quarantine state blocks the legacy dispatch path")
	check(game.begin_corrective_action(incident_id, "relabel"), "Visual run assigns a real quality corrective action")
	game.advance_simulation(60.0)
	check(game.dispatch_contract("ORD-001"), "Visual run dispatches real inventory into the accepted contract")
	check(game.hire_employee("maintenance_technician"), "Visual run hires a technician for repair")
	check(game.trigger_machine_fault("packaging", "packaging_jam"), "Visual run creates a deterministic packaging fault")
	main.ui.current_tab = "machine"
	main.ui.machine_selected("packaging")
	main.ui._refresh_ui()
	check(main.ui.panel_body.get_child_count() >= 5 and main.ui.panel_body.size.y > 100.0, "Machine panel renders fault and repair controls")
	main.camera_rig.focus(main.factory.machines.packaging.global_position, 12.5)
	await create_timer(0.5).timeout
	await capture("machine_breakdown.png")
	check(game.repair_machine("packaging"), "Technician begins the paid repair shown in 3D")
	main.ui._refresh_ui()
	await create_timer(5.5).timeout
	await capture("technician_repair.png")
	game.advance_simulation(120.0)
	check(game.machinery.status("PACK-001") == "idle", "Rendered repair restores the machine")
	game.language = "pl"
	TranslationServer.set_locale("pl")
	main.ui.current_tab = "production"
	main.ui.show_factory()
	await capture("polish_factory.png")
	check(main.ui.panel_title.text == "Sterowanie produkcją", "Polish gameplay interface loads from external translations")
	# Responsive landscape floor: validate the supported minimum without claiming device testing.
	root.size = Vector2i(960, 540)
	await process_frame
	await process_frame
	main.ui.show_factory()
	await capture("landscape_960x540.png")
	check(not main.ui.right_panel.get_global_rect().intersects(main.ui.objective_panel.get_global_rect()), "Management and objective panels do not overlap at the supported landscape minimum")
	print("MEATCRAFT VISUAL RESULT: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
