extends SceneTree
## Requires a graphics display. Captures four layouts and exercises real GUI input.

var failures := 0
var main: Control

func _initialize() -> void:
	_run.call_deferred()

func click(button: Button) -> void:
	var center := button.get_global_rect().get_center()
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = center
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(filename: String) -> void:
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("CRAFT_CAPTURE_DIR")
	if output.is_empty():
		output = "/tmp"
	var error := root.get_texture().get_image().save_png(output.path_join(filename))
	if error != OK:
		failures += 1
	print("CAPTURE: " + filename + " (" + str(error) + ")")

func _run() -> void:
	root.get_node("Game").set_process(false)
	root.get_node("Game").new_game()
	root.get_node("Game").language = "en"
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await capture("craft-menu.png")
	var continue_button: Button = main.ui.get_node("MenuCard").get_child(1)
	await click(continue_button)
	if main.screen != "factory":
		push_error("Real mouse input did not open the factory")
		failures += 1
	await capture("craft-factory.png")
	await click(main.start_button)
	var game: Node = root.get_node("Game")
	if game.stage != 0:
		push_error("Real mouse input did not start production")
		failures += 1
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = main.factory.get_global_transform_with_canvas() * (main.factory.machines[1].position - Vector2(0, 80))
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame
	if main.selected != 1:
		push_error("Real mouse input did not select a workshop machine")
		failures += 1
	game.advance(4.2)
	await capture("craft-production.png")
	main._show_settings()
	if main.modal.z_index <= main.ui.z_index:
		push_error("Settings must draw above the workshop UI")
		failures += 1
	await capture("craft-settings.png")
	main._save_modal_close()
	game.language = "pl"
	TranslationServer.set_locale("pl")
	main._show_factory()
	await capture("craft-polish.png")
	# Simulated viewport sizes exercise layout only; this is not device testing.
	root.size = Vector2i(1600, 900)
	main.size = Vector2(1600, 900)
	main._layout()
	await capture("craft-wide.png")
	print("VISUAL RESULT: %d failures" % failures)
	main.queue_free()
	await process_frame
	quit(1 if failures else 0)
