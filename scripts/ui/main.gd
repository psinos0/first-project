extends Control
## Responsive interface. Every player-facing string uses Godot's translation system.

const FACTORY := preload("res://scenes/factory.tscn")
const BODY := preload("res://assets/Body.ttf")
const HEADING := preload("res://assets/Heading.ttf")
const DARK := Color("163e35")
const MUTED := Color("7c927f")
const PAPER := Color("f2efdf")
const GOLD := Color("e9bd72")
var factory: Node2D
var ui: Control
var modal: Control
var screen := "menu"
var selected := 0
var coins_label: Label
var rank_label: Label
var batch_label: Label
var status_label: Label
var state_label: Label
var start_button: Button
var upgrade_button: Button
var machine_title: Label
var machine_description: Label
var machine_stats: Label
var level_label: Label
var save_label: Label
var rank_progress: ProgressBar
var station_buttons: Array[Button] = []
var station_progress: Array[ProgressBar] = []
var _refresh := 0.0

func _ready() -> void:
	TranslationServer.set_locale(Game.language)
	_build_theme()
	factory = FACTORY.instantiate()
	add_child(factory)
	factory.station_selected.connect(_select_station)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.z_index = 30
	add_child(ui)
	Game.changed.connect(_update_values)
	Game.sold.connect(_on_sale)
	Game.notice.connect(_toast)
	resized.connect(_layout)
	_show_menu()
	# CLI flags used only by the documented visual/UI smoke tests.
	if "--smoke-factory" in OS.get_cmdline_user_args():
		Game.new_game()
		_show_factory()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font = BODY
	skin.default_font_size = 16
	skin.set_color("font_color", "Label", DARK)
	skin.set_color("font_color", "Button", DARK)
	for type in ["Button", "CheckButton"]:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			skin.set_color(state, type, DARK)
	skin.set_color("font_disabled_color", "Button", Color("84988a"))
	skin.set_font("font", "Button", HEADING)
	skin.set_constant("outline_size", "Button", 0)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var color := Color("e8e8d7")
		if state == "hover": color = Color("d5ddc6")
		if state == "pressed": color = Color("c4d4bc")
		if state == "disabled": color = Color("e3e5d8")
		var style := _style(color, 12)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = GOLD
			style.set_border_width_all(3)
		skin.set_stylebox(state, "Button", style)
	skin.set_stylebox("background", "ProgressBar", _style(Color("dce2cf"), 5))
	skin.set_stylebox("fill", "ProgressBar", _style(Color("5f9473"), 5))
	theme = skin

func _style(color: Color, radius: int = 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Node, color: Color = PAPER, radius: int = 20) -> Panel:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _style(color, radius))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, font_size: int = 16,
		color: Color = DARK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", HEADING)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 58
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var color := GOLD if state == "normal" else GOLD.lightened(0.10) if state == "hover" else GOLD.darkened(0.08)
			var style := _style(color, 12)
			style.content_margin_left = 18
			style.content_margin_right = 18
			button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		Sound.play()
		callback.call()
	)
	parent.add_child(button)
	return button

func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)

func _clear_ui() -> void:
	for child in ui.get_children():
		ui.remove_child(child)
		child.queue_free()
	station_buttons.clear()
	station_progress.clear()
	coins_label = null
	_save_modal_close()

func _show_menu() -> void:
	Game.playing = false
	factory.interactive = false
	factory.select(-1)
	screen = "menu"
	_clear_ui()
	var brand := _label(ui, "C / E     " + tr("THE SMALL-BATCH COMPANY"), 15, Color("a6b7a0"), true)
	brand.name = "Brand"
	var eyebrow := _label(ui, tr("GOOD THINGS TAKE CRAFT."), 14, GOLD, true)
	eyebrow.name = "Eyebrow"
	var title := _label(ui, "Craft Empire\nTycoon", 62, PAPER, true)
	title.name = "Title"
	var description := _label(ui, tr("A little workshop. A big ambition.\nTurn honest ingredients into your own empire."), 18, Color("b8c9b3"))
	description.name = "Description"
	var card := _panel(ui, Color("244b40"))
	card.name = "MenuCard"
	var heading := _label(card, tr("Your next chapter starts here."), 20, PAPER, true)
	_place(heading, 24, 20, 400, 32)
	var continue_button := _button(card, tr("Continue workshop") if Game.save_exists else tr("Open your workshop"), func():
		if not Game.save_exists:
			Game.new_game()
		_show_factory(), true)
	_place(continue_button, 24, 68, 392, 60)
	var new_button := _button(card, tr("New game"), _request_new_game)
	_place(new_button, 24, 140, 188, 56)
	var settings_button := _button(card, tr("Settings"), _show_settings)
	_place(settings_button, 228, 140, 188, 56)
	var footnote := _label(ui, tr("HANDCRAFTED SNACKS  /  CHAPTER 01"), 13, Color("92a88f"), true)
	footnote.name = "Footnote"
	var factory_badge := _panel(ui, Color("244b40"), 12)
	factory_badge.name = "FactoryBadge"
	var badge_text := _label(factory_badge, tr("THE FIRST WORKSHOP") + "   •   " + tr("Made with care"), 14, PAPER)
	_place(badge_text, 20, 8, 360, 28)
	_layout()

func _show_factory() -> void:
	screen = "factory"
	Game.playing = true
	factory.interactive = true
	_clear_ui()
	var header := _panel(ui, Color("163a32"), 0)
	header.name = "Header"
	var brand := _label(header, "CRAFT EMPIRE", 22, PAPER, true)
	_place(brand, 30, 23, 270, 36)
	var subtitle := _label(header, tr("THE SMALL-BATCH COMPANY"), 11, Color("9ab299"), true)
	_place(subtitle, 31, 59, 280, 22)
	var coin_panel := _panel(header, Color("2a5141"), 14)
	coin_panel.name = "CoinPanel"
	_label(coin_panel, "●", 32, GOLD).position = Vector2(18, 11)
	coins_label = _label(coin_panel, "", 26, PAPER, true)
	_place(coins_label, 61, 6, 160, 39)
	var coin_caption := _label(coin_panel, tr("AVAILABLE COINS"), 10, Color("b5c5a8"), true)
	_place(coin_caption, 62, 43, 160, 20)
	var menu_button := _button(header, tr("Menu"), func():
		Game.save_game()
		_show_menu())
	menu_button.name = "MenuButton"
	var settings_button := _button(header, tr("Settings"), _show_settings)
	settings_button.name = "SettingsButton"
	var room_title := _label(ui, tr("The first workshop"), 25, PAPER, true)
	room_title.name = "RoomTitle"
	var room_caption := _label(ui, tr("Handcrafted dried snacks") + "   /   " + tr("Tap a machine to improve it"), 14, Color("b0bda1"))
	room_caption.name = "RoomCaption"
	var sidebar := _panel(ui)
	sidebar.name = "Sidebar"
	_label(sidebar, tr("PRODUCTION LINE"), 12, Color("68836e"), true).position = Vector2(24, 22)
	for i in range(4):
		var station_button := _button(sidebar, "", _select_station.bind(i))
		station_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_place(station_button, 20, 55 + i * 62, 292, 53)
		station_buttons.append(station_button)
		var progress := ProgressBar.new()
		progress.show_percentage = false
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sidebar.add_child(progress)
		_place(progress, 35, 100 + i * 62, 262, 4)
		station_progress.append(progress)
	var divider := ColorRect.new()
	divider.color = Color("d8dfcc")
	sidebar.add_child(divider)
	_place(divider, 24, 315, 284, 1)
	machine_title = _label(sidebar, "", 22, DARK, true)
	_place(machine_title, 24, 333, 284, 38)
	level_label = _label(sidebar, "", 13, Color("68836e"), true)
	_place(level_label, 24, 376, 284, 25)
	machine_description = _label(sidebar, "", 14)
	machine_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(machine_description, 24, 411, 284, 58)
	machine_stats = _label(sidebar, "", 14, Color("59745e"))
	_place(machine_stats, 24, 473, 284, 55)
	upgrade_button = _button(sidebar, "", _upgrade_selected, true)
	upgrade_button.name = "UpgradeButton"
	var bottom := _panel(ui, Color("f0eedc"), 18)
	bottom.name = "Bottom"
	_label(bottom, tr("TODAY'S SPECIAL"), 11, Color("6c856b"), true).position = Vector2(25, 17)
	batch_label = _label(bottom, "", 20, DARK, true)
	_place(batch_label, 24, 35, 440, 36)
	status_label = _label(bottom, "", 13, Color("6b8069"))
	_place(status_label, 25, 75, 590, 25)
	start_button = _button(bottom, "", _start_batch, true)
	start_button.name = "StartButton"
	var progression := _panel(ui, Color("244b40"), 16)
	progression.name = "Progression"
	_label(progression, tr("YOUR GROWING EMPIRE"), 10, Color("b0c0a1"), true).position = Vector2(20, 12)
	rank_label = _label(progression, "", 18, PAPER, true)
	_place(rank_label, 20, 32, 285, 29)
	state_label = _label(progression, "", 12, Color("acbd9e"))
	_place(state_label, 20, 72, 285, 25)
	rank_progress = ProgressBar.new()
	rank_progress.show_percentage = false
	rank_progress.add_theme_stylebox_override("background", _style(Color("41664d"), 3))
	rank_progress.add_theme_stylebox_override("fill", _style(GOLD, 3))
	progression.add_child(rank_progress)
	_place(rank_progress, 20, 65, 292, 5)
	save_label = _label(ui, tr("Progress saved on this device"), 11, Color("91a888"))
	save_label.name = "SaveLabel"
	_select_station(selected)
	_layout()
	_update_values()

func _layout() -> void:
	if not is_instance_valid(factory) or not is_instance_valid(ui):
		return
	queue_redraw()
	var w := size.x
	var h := size.y
	if screen == "menu":
		_place(ui.get_node("Brand"), 64, 38, 600, 32)
		_place(ui.get_node("Eyebrow"), 72, h * 0.21, 450, 30)
		_place(ui.get_node("Title"), 67, h * 0.21 + 42, 505, 186)
		_place(ui.get_node("Description"), 72, h * 0.21 + 238, 520, 68)
		_place(ui.get_node("MenuCard"), 72, h * 0.21 + 339, 440, 222)
		_place(ui.get_node("Footnote"), 72, h - 60, 520, 28)
		_place(ui.get_node("FactoryBadge"), w * 0.6 - 40, h - 111, 376, 45)
		factory.fit_to(Rect2(w * 0.37, 136, w * 0.63 - 25, h - 270))
	else:
		var side_x := w - 362
		var header: Control = ui.get_node("Header")
		_place(header, 0, 0, w, 100)
		_place(header.get_node("CoinPanel"), w * 0.43, 14, 225, 72)
		_place(header.get_node("MenuButton"), w - 255, 22, 98, 56)
		_place(header.get_node("SettingsButton"), w - 145, 22, 115, 56)
		_place(ui.get_node("RoomTitle"), 36, 122, 650, 42)
		_place(ui.get_node("RoomCaption"), 38, 165, 780, 28)
		_place(ui.get_node("Sidebar"), side_x, 126, 332, h - 289)
		_place(upgrade_button, 24, h - 367, 284, 56)
		factory.fit_to(Rect2(20, 193, side_x - 35, h - 363))
		_place(ui.get_node("Bottom"), 30, h - 155, side_x - 52, 115)
		_place(start_button, side_x - 340, 25, 260, 65)
		_place(ui.get_node("Progression"), side_x, h - 155, 332, 115)
		_place(save_label, 36, h - 34, 750, 22)
	if is_instance_valid(modal):
		var card := modal.get_node_or_null("Card") as Control
		if card:
			card.position = (size - card.size) * 0.5

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("173e35"))
	for i in range(10, 0, -1):
		draw_circle(Vector2(size.x * 0.61, size.y * 0.46), 120 + i * 52, Color(0.52, 0.63, 0.40, 0.009))
	for i in range(22):
		var x := float(i) * 100.0 - 500
		draw_line(Vector2(x, size.y), Vector2(x + size.y, 0), Color(0.53, 0.64, 0.46, 0.025), 1, true)

func _process(delta: float) -> void:
	if screen != "factory":
		return
	_refresh += delta
	if _refresh < 0.1:
		return
	_refresh = 0.0
	_update_values()

func _update_values() -> void:
	if screen != "factory" or not is_instance_valid(coins_label):
		return
	coins_label.text = str(Game.coins)
	var names := [tr("Preparation"), tr("Drying"), tr("Packaging"), tr("Delivery")]
	for i in range(4):
		var suffix := "  •  " + tr("Lv. {level}").format({"level": Game.levels[i]}) if i < 3 else ""
		station_buttons[i].text = "%02d   %s%s" % [i + 1, names[i], suffix]
		var is_active := Game.stage == i
		station_progress[i].value = Game.progress() * 100 if is_active and not Game.transferring else 100 if Game.stage > i else 0
		station_buttons[i].add_theme_stylebox_override("normal", _style(Color("cddcc3") if i == selected else Color("e5e8d8"), 10))
	machine_title.text = names[selected]
	if selected < 3:
		var level: int = Game.levels[selected]
		level_label.text = tr("LEVEL {level} / {max}").format({"level": level, "max": int(Game.balance.max_level)})
		var descriptions := [tr("Slice fresh ingredients. Bigger batches begin with better preparation."), tr("Slow craft, made faster. Warm-air drying brings out every bit of flavour."), tr("Seal in the goodness. Beautiful packaging earns a better sale price.")]
		machine_description.text = descriptions[selected]
		var stats := tr("Cycle: {seconds}s").format({"seconds": "%.1f" % Game.duration(selected)})
		stats += "\n" + (tr("Batch size: {units} snacks").format({"units": Game.next_units()}) if selected == 0 else tr("Cycle time per upgrade: −{percent}%").format({"percent": roundi((1.0 - float(Game.balance.speed_factor)) * 100.0)}) if selected == 1 else tr("Sale value: {coins} coins").format({"coins": Game.next_revenue()}))
		machine_stats.text = stats
		var maxed := level >= int(Game.balance.max_level)
		upgrade_button.text = tr("Fully upgraded") if maxed else tr("Upgrade • {coins} coins").format({"coins": Game.upgrade_cost(selected)})
		upgrade_button.disabled = maxed or Game.coins - Game.upgrade_cost(selected) < int(Game.balance.batch_cost)
		upgrade_button.tooltip_text = tr("Keep {coins} coins for ingredients. Upgrades apply to the next batch.").format({"coins": int(Game.balance.batch_cost)})
	else:
		level_label.text = tr("LOCAL MARKET")
		machine_description.text = tr("Packed with care, sent with pride. Every finished batch sells automatically.")
		machine_stats.text = tr("Batches delivered: {count}").format({"count": Game.batches}) + "\n" + tr("Lifetime sales: {coins} coins").format({"coins": Game.earned})
		upgrade_button.text = tr("Ready for dispatch")
		upgrade_button.disabled = true
	var units: int = Game.batch_units if Game.stage >= 0 else Game.next_units()
	batch_label.text = tr("Dried snacks") + "   /   " + tr("{units} per batch").format({"units": units})
	if Game.stage < 0:
		status_label.text = tr("Ingredients: {cost} coins  •  Sale: {revenue} coins").format({"cost": Game.balance.batch_cost, "revenue": Game.next_revenue()})
		start_button.text = tr("Start a batch") + "   →"
		start_button.disabled = Game.coins < int(Game.balance.batch_cost)
	else:
		status_label.text = tr("Moving to {station}…").format({"station": names[Game.stage]}) if Game.transferring else tr("{station} in progress • {seconds}s left").format({"station": names[Game.stage], "seconds": "%.1f" % (Game.current_duration() - Game.elapsed)})
		start_button.text = tr("Crafting") + "   %d%%" % _total_progress()
		start_button.disabled = true
	var rank: int = Game.rank_index()
	rank_label.text = tr(Game.balance.ranks[rank].name)
	if rank < Game.balance.ranks.size() - 1:
		var threshold: int = int(Game.balance.ranks[rank + 1].earned)
		var previous: int = int(Game.balance.ranks[rank].earned)
		rank_progress.value = 100.0 * (Game.earned - previous) / (threshold - previous)
		state_label.text = tr("{coins} / {target} lifetime sales").format({"coins": Game.earned, "target": threshold})
	else:
		rank_progress.value = 100
		state_label.text = tr("A little workshop, a real empire.")
	save_label.text = tr("Progress saved on this device") if Game.save_error == OK else tr("Save failed — check device storage")

func _total_progress() -> int:
	var total := float(Game.balance.transfer_seconds) * 3.0
	var complete := 0.0
	for i in range(4):
		total += Game.batch_durations[i]
		if i < Game.stage:
			complete += Game.batch_durations[i]
			if i > 0:
				complete += float(Game.balance.transfer_seconds)
	if Game.stage > 0 and not Game.transferring:
		complete += float(Game.balance.transfer_seconds)
	return clampi(roundi((complete + Game.elapsed) / total * 100.0), 0, 100)

func _select_station(index: int) -> void:
	selected = clampi(index, 0, 3)
	factory.select(selected)
	_update_values()

func _start_batch() -> void:
	if Game.start_batch():
		_toast(tr("Fresh ingredients, big possibilities."))

func _upgrade_selected() -> void:
	if Game.upgrade(selected):
		_toast(tr("Machine upgraded. Your next batch gets better."))

func _on_sale(amount: int) -> void:
	Sound.play(true)
	_toast(tr("Batch delivered! +{coins} coins").format({"coins": amount}), true)

func _toast(message: String, celebratory: bool = false) -> void:
	var toast := _panel(self, GOLD if celebratory else Color("e2e7cd"), 14)
	toast.z_index = 40
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text := _label(toast, tr(message), 17, DARK, true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(toast, (size.x - 620) * 0.5, 108, 620, 52)
	_place(text, 14, 10, 592, 32)
	var tween := create_tween()
	if not Game.reduced_motion:
		toast.position.y += 10
		tween.tween_property(toast, "position:y", 108, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(toast.queue_free)

func _make_modal(height: float) -> Panel:
	_save_modal_close()
	modal = Control.new()
	modal.z_index = 50
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.10, 0.075, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var card := _panel(modal)
	card.name = "Card"
	card.size = Vector2(520, height)
	card.position = (size - card.size) * 0.5
	return card

func _save_modal_close() -> void:
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null

func _request_new_game() -> void:
	if not Game.save_exists:
		Game.new_game()
		_show_factory()
		return
	var card := _make_modal(266)
	_label(card, tr("A fresh beginning?"), 27, DARK, true).position = Vector2(32, 28)
	var body := _label(card, tr("This replaces your saved workshop.\nYour settings will stay the same."), 16)
	_place(body, 32, 84, 456, 70)
	_place(_button(card, tr("Cancel"), _save_modal_close), 32, 176, 216, 58)
	_place(_button(card, tr("Start fresh"), func():
		Game.new_game()
		_show_factory(), true), 264, 176, 224, 58)

func _show_settings() -> void:
	var card := _make_modal(470)
	_label(card, tr("Make yourself at home."), 25, DARK, true).position = Vector2(32, 26)
	_label(card, tr("SETTINGS"), 12, Color("68836e"), true).position = Vector2(34, 69)
	var audio := CheckButton.new()
	audio.text = tr("Workshop sounds")
	audio.button_pressed = Game.sound_enabled
	audio.toggled.connect(func(enabled: bool):
		Game.sound_enabled = enabled
		if Game.save_exists: Game.save_game())
	card.add_child(audio)
	_place(audio, 32, 111, 450, 58)
	var motion := CheckButton.new()
	motion.text = tr("Reduce ambient motion")
	motion.button_pressed = Game.reduced_motion
	motion.toggled.connect(func(enabled: bool):
		Game.reduced_motion = enabled
		if Game.save_exists: Game.save_game())
	card.add_child(motion)
	_place(motion, 32, 177, 450, 58)
	var language := _button(card, tr("Language: English / Polski"), func():
		Game.language = "pl" if Game.language == "en" else "en"
		TranslationServer.set_locale(Game.language)
		if Game.save_exists: Game.save_game()
		if screen == "menu": _show_menu()
		else: _show_factory()
		_show_settings())
	_place(language, 32, 247, 456, 56)
	var note := _label(card, tr("Local saves • no account needed\nProduction pauses when you leave the workshop."), 13, Color("69816a"))
	_place(note, 32, 320, 456, 65)
	_place(_button(card, tr("Back to the workshop") if screen == "factory" else tr("Done"), _save_modal_close, true), 32, 389, 456, 56)

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_instance_valid(modal):
			_save_modal_close()
		elif screen == "factory":
			Game.save_game()
			_show_menu()
		get_viewport().set_input_as_handled()

func _capture() -> void:
	# Run under a real display (e.g. Xvfb), not the headless dummy renderer.
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture")
	if index >= 0 and index + 1 < args.size():
		get_viewport().get_texture().get_image().save_png(args[index + 1])
	get_tree().quit()
