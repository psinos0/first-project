extends SceneTree
## Run with --headless --script res://scripts/tests/gameplay_test.gd.
## Use an isolated XDG_DATA_HOME: tests intentionally exercise New Game.

var checks := 0
var failures := 0
var game: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func _run() -> void:
	game = root.get_node("Game")
	game.set_process(false)
	game.new_game()
	check(game.coins == 120 and game.stage == -1, "New workshop begins with 120 coins")
	check(game.start_batch(), "Player can start production")
	check(game.coins == 108 and game.stage == 0, "Ingredients debited once; preparation begins")
	check(not game.start_batch() and game.coins == 108, "Second click cannot buy a duplicate active batch")
	game.advance(3.0)
	check(game.stage == 1 and game.transferring, "Preparation feeds the first conveyor")
	game.advance(0.7)
	check(game.stage == 1 and not game.transferring, "Drying begins after visible transfer")
	game.advance(4.5)
	check(game.stage == 2 and game.transferring, "Drying feeds packaging")
	game.advance(0.7)
	game.advance(2.5)
	check(game.stage == 3 and game.transferring, "Packaging feeds delivery")
	game.advance(1.5)
	check(game.stage == -1 and game.coins == 150 and game.batches == 1, "Full cycle sells for 42 coins (30 net)")
	game.advance(100.0)
	check(game.coins == 150, "Idle advance cannot credit the sale twice")
	var old_duration: float = game.duration(0)
	check(game.upgrade(0) and game.levels[0] == 2 and game.coins == 105, "Preparation upgrade charges the configured cost")
	check(game.duration(0) < old_duration and game.next_units() == 10, "Upgrade improves speed and capacity")
	check(game.next_revenue() == 48, "Increased capacity raises revenue")
	game.coins = 60
	check(not game.upgrade(2) and game.coins == 60, "Upgrade keeps enough ingredients to avoid economic deadlock")
	game.coins = 500
	check(game.start_batch(), "Upgraded batch starts")
	var frozen_duration: float = game.batch_durations[0]
	var frozen_revenue: int = game.batch_revenue
	check(game.upgrade(0), "Machine can be upgraded during production")
	check(game.batch_durations[0] == frozen_duration and game.batch_revenue == frozen_revenue, "In-flight batch terms stay fixed")
	game.advance(1.25)
	var saved_coins: int = game.coins
	check(game.save_game() == OK, "Active production saves successfully")
	game.stage = -1
	game.coins = 0
	check(game.load_game(), "Saved workshop loads")
	check(game.stage == 0 and is_equal_approx(game.elapsed, 1.25) and game.coins == saved_coins, "Reload preserves balance, upgrades and production timer")
	game.advance(200.0)
	check(game.stage == -1 and game.batches == 2 and game.coins == saved_coins + frozen_revenue, "Large frame delta completes an upgraded batch exactly once")
	game.earned = 500
	check(game.rank_index() == 2, "Lifetime sales unlock the expected rank")
	game.language = "pl"
	game.sound_enabled = false
	game.reduced_motion = true
	game.save_game()
	game.language = "en"
	game.sound_enabled = true
	game.reduced_motion = false
	game.load_game()
	check(game.language == "pl" and not game.sound_enabled and game.reduced_motion, "Language and accessibility settings survive reload")
	var saved: Dictionary = game.snapshot()
	var path := "user://test-save.json"
	check(SaveStore.write_save(saved, path) == OK, "Persistence writes an independent snapshot")
	check(SaveStore.write_save(saved, path) == OK, "Repeated persistence creates a backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken JSON")
	file.close()
	check(SaveStore.read_save(path).get("coins") == saved.coins, "Corrupt primary recovers from the last good backup")
	check(SaveStore.write_save(saved, path) == OK, "Saving after recovery succeeds")
	check(not SaveStore.read_save(path + ".bak").is_empty(), "Recovery does not overwrite the valid backup with corrupt data")
	file = FileAccess.open(path, FileAccess.WRITE)
	var malformed := saved.duplicate(true)
	malformed["levels"] = ["invalid", 2, 3]
	file.store_string(JSON.stringify(malformed))
	file.close()
	var recovered_levels: Array = SaveStore.read_save(path).get("levels", [])
	check(recovered_levels.size() == 3 and recovered_levels[0] == saved.levels[0] and recovered_levels[1] == saved.levels[1] and recovered_levels[2] == saved.levels[2], "Malformed economy fields also fall back to a valid backup")
	game.restore({"version": 1, "coins": -1, "levels": [99, -8, 2], "stage": 99})
	check(game.coins == 0 and game.levels == [8, 1, 2] and game.stage == 3, "Out-of-range save data is bounded")
	game.new_game()
	check(game.coins == 120 and game.earned == 0 and game.levels == [1, 1, 1], "New Game clears prior progression")
	# Instantiate the actual scene and exercise player-facing controls, not just rules.
	var main: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main._show_factory()
	check(main.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Factory input is not blocked by the fullscreen UI root")
	check(is_instance_valid(main.start_button) and not main.start_button.disabled, "Factory UI exposes a usable batch action")
	main.start_button.pressed.emit()
	check(game.stage == 0 and game.coins == 108, "Batch button is wired to gameplay")
	main._select_station(2)
	check(main.selected == 2 and main.factory.selected == 2, "Selecting equipment connects artwork and upgrade panel")
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = main.factory.get_global_transform_with_canvas() * (main.factory.machines[1].position - Vector2(0, 85))
	main.factory._unhandled_input(touch)
	check(main.selected == 1, "Touch coordinates select the drying machine")
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = main.factory.get_global_transform_with_canvas() * (main.factory.machines[2].position - Vector2(0, 85))
	main.factory._unhandled_input(click)
	check(main.selected == 2, "Mouse coordinates select the packaging machine")
	main.upgrade_button.pressed.emit()
	check(game.levels[2] == 2, "Upgrade button changes the selected machine")
	main._show_settings()
	check(is_instance_valid(main.modal), "Settings overlay opens")
	main._save_modal_close()
	main._show_menu()
	var pause_elapsed: float = game.elapsed
	game._process(1.0)
	check(not game.playing and game.elapsed == pause_elapsed, "Main menu pauses production")
	main._show_factory()
	check(game.playing and game.stage == 0, "Continue resumes the saved production")
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game._process(20.0)
	check(not game.playing and game.elapsed == pause_elapsed, "Mobile suspension pauses production and saves")
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(game.playing, "Mobile resume restores the running workshop")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	main.queue_free()
	await process_frame
	root.get_node("Sound").player.stop()
	root.get_node("Sound").player.stream = null
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
