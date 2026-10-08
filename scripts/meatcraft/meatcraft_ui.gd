class_name MeatCraftUI
extends Control

signal focus_machine_requested(machine_id: String)
signal screen_changed(screen: String)

const BODY := preload("res://assets/Body.ttf")
const HEADING := preload("res://assets/Heading.ttf")
const INK := Color("182629")
const PAPER := Color("f4f1e9")
const PANEL := Color("e8e8df")
const BRAND := Color("b64b33")
const GOLD := Color("e3a243")
const TEAL := Color("346d69")
const DARK := Color("182f31")
var current_screen := "menu"
var current_tab := "production"
var selected_machine := "dryer"
var backdrop: ColorRect
var content: Control
var toast_layer: Control
var cash_label: Label
var time_label: Label
var reputation_label: Label
var hygiene_label: Label
var objective_label: Label
var panel_title: Label
var panel_body: VBoxContainer
var pause_button: Button
var right_panel: PanelContainer
var objective_panel: PanelContainer
var _refresh := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	TranslationServer.set_locale(MeatGame.language)
	_build_theme()
	backdrop = ColorRect.new()
	backdrop.color = Color(0.025, 0.075, 0.072, 0.24)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	toast_layer = Control.new()
	toast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.z_index = 30
	add_child(toast_layer)
	MeatGame.state_changed.connect(_refresh_ui)
	MeatGame.event_posted.connect(_toast)
	resized.connect(_refresh_ui)
	show_menu()

func _build_theme() -> void:
	var skin := Theme.new()
	skin.default_font = BODY
	skin.default_font_size = 16
	for type in ["Label", "Button", "CheckButton"]:
		skin.set_color("font_color", type, INK)
	for state in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		skin.set_color(state, "Button", INK)
	skin.set_color("font_disabled_color", "Button", Color("7b8580"))
	skin.set_font("font", "Button", HEADING)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var colour := Color("edf0e7")
		if state == "hover": colour = Color("f4d7a7")
		if state == "pressed": colour = Color("dfbd81")
		if state == "disabled": colour = Color("d7dad2")
		var style := _style(colour, 10)
		style.content_margin_left = 18
		style.content_margin_right = 18
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = GOLD
			style.set_border_width_all(3)
		skin.set_stylebox(state, "Button", style)
	skin.set_stylebox("background", "ProgressBar", _style(Color("c7cec5"), 5))
	skin.set_stylebox("fill", "ProgressBar", _style(BRAND, 5))
	theme = skin

func _style(colour: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(radius)
	return style

func _clear() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	if is_instance_valid(toast_layer):
		for child in toast_layer.get_children():
			toast_layer.remove_child(child)
			child.queue_free()
	cash_label = null
	time_label = null
	panel_body = null

func _label(parent: Node, value: String, size_px := 16, colour := INK, bold := false) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", colour)
	if bold:
		label.add_theme_font_override("font", HEADING)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, callback: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(0, 52)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		for state in ["normal", "hover", "pressed"]:
			var colour := GOLD if state == "normal" else GOLD.lightened(0.12) if state == "hover" else GOLD.darkened(0.08)
			var style := _style(colour, 10)
			style.content_margin_left = 18
			style.content_margin_right = 18
			button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func():
		Sound.play()
		callback.call())
	parent.add_child(button)
	return button

func _panel(parent: Node, colour := PAPER, radius := 16) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(colour, radius))
	parent.add_child(panel)
	return panel

func _margin(parent: Node, margin := 24) -> MarginContainer:
	var margins := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, margin)
	parent.add_child(margins)
	return margins

func show_menu() -> void:
	current_screen = "menu"
	MeatGame.simulation_paused = true
	_clear()
	backdrop.color = Color(0.02, 0.06, 0.055, 0.50)
	var menu := _panel(content, Color(0.055, 0.12, 0.12, 0.96), 0)
	menu.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	menu.offset_right = 550
	var margins := _margin(menu, 54)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 17)
	margins.add_child(column)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 72
	column.add_child(spacer)
	_label(column, "MEATCRAFT", 17, GOLD, true)
	var title := _label(column, "EMPIRE", 66, PAPER, true)
	title.add_theme_constant_override("outline_size", 2)
	_label(column, tr("Biltong Factory Tycoon"), 22, Color("b8cdc5"))
	var line := ColorRect.new()
	line.color = BRAND
	line.custom_minimum_size = Vector2(110, 4)
	column.add_child(line)
	var slogan := _label(column, tr("Where Health Meets Flavour."), 19, Color("f0d29a"), true)
	slogan.custom_minimum_size.y = 55
	var new_button := _button(column, tr("Start a new company"), func():
		MeatGame.new_company()
		show_property_selection(), true)
	new_button.custom_minimum_size.y = 62
	var continue_button := _button(column, tr("Continue"), show_factory)
	continue_button.disabled = not MeatGame.save_exists or not MeatGame.property_owned
	_button(column, tr("Settings"), _show_settings)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(filler)
	_label(column, tr("TRUE 3D FACTORY • GODOT 4.7.2"), 11, Color("78948c"), true)
	screen_changed.emit(current_screen)

func show_property_selection() -> void:
	current_screen = "property"
	_clear()
	backdrop.color = Color(0.02, 0.06, 0.055, 0.67)
	var wrapper := _margin(content, 55)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	wrapper.add_child(column)
	_label(column, tr("CHAPTER 1 • YOUR FIRST PREMISES"), 14, GOLD, true)
	_label(column, tr("Choose where the MeatCraft story begins"), 38, PAPER, true)
	_label(column, tr("Start small, learn the craft and grow into a modern food-production business."), 17, Color("d3dfd8"))
	var cards := HBoxContainer.new()
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 20)
	column.add_child(cards)
	_property_card(cards, tr("Small Workshop"), "£12,000", tr("160 m² • 1 production line\nLow overheads • Ideal first site"), true, func():
		if MeatGame.acquire_small_hall():
			show_industry_selection())
	_property_card(cards, tr("Medium Industrial Unit"), "£58,000", tr("420 m² • 3 production lines\nRequires company level 4"), false, Callable())
	_property_card(cards, tr("Large Factory"), "£185,000", tr("1,100 m² • Automated logistics\nFuture expansion milestone"), false, Callable())
	var back := _button(column, tr("Back to main menu"), show_menu)
	back.custom_minimum_size.x = 260
	screen_changed.emit(current_screen)

func _property_card(parent: Node, title: String, price: String, description: String, enabled: bool, callback: Callable) -> void:
	var panel := _panel(parent, PAPER)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := _margin(panel, 28)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	margin.add_child(box)
	_label(box, tr("AVAILABLE") if enabled else tr("LOCKED"), 11, TEAL if enabled else Color("87918b"), true)
	_label(box, title, 26, INK, true)
	_label(box, price, 31, BRAND, true)
	var description_label := _label(box, description, 16, Color("52615e"))
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var button := _button(box, tr("Acquire premises") if enabled else tr("Not yet available"), callback, enabled)
	button.disabled = not enabled

func show_industry_selection() -> void:
	current_screen = "industry"
	_clear()
	backdrop.color = Color(0.02, 0.06, 0.055, 0.64)
	var card := _panel(content, PAPER)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-460, -285)
	card.size = Vector2(920, 570)
	var margin := _margin(card, 42)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 17)
	margin.add_child(box)
	_label(box, tr("YOUR BUSINESS"), 12, TEAL, true)
	_label(box, tr("MEATCRAFT — BILTONG MANUFACTURING"), 34, INK, true)
	_label(box, tr("Where Health Meets Flavour."), 20, BRAND, true)
	var copy := _label(box, tr("Build a small-batch biltong company from procurement to dispatch. Prepare beef, blend seasonings, marinate for 24 hours, hang every strip and control a seven-day drying cycle."), 17, Color("4d5d59"))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var feature_row := HBoxContainer.new()
	feature_row.add_theme_constant_override("separation", 12)
	box.add_child(feature_row)
	for feature in [tr("3 signature recipes"), tr("Traceable batches"), tr("50% drying yield"), tr("Food-safety gameplay")]:
		var badge := _panel(feature_row, Color("dce5dc"), 8)
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge_margin := _margin(badge, 12)
		var text := _label(badge_margin, feature, 13, DARK, true)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var button := _button(box, tr("Launch MeatCraft"), func():
		if MeatGame.select_meatcraft():
			show_factory(), true)
	button.custom_minimum_size.y = 64
	screen_changed.emit(current_screen)

func show_factory() -> void:
	if not MeatGame.property_owned:
		show_property_selection()
		return
	current_screen = "factory"
	backdrop.color = Color.TRANSPARENT
	MeatGame.simulation_paused = not MeatGame.starter_line_owned
	_clear()
	_build_hud()
	_refresh_ui()
	screen_changed.emit(current_screen)

func _build_hud() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(Color(0.055, 0.13, 0.13, 0.98), 0))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 88
	top.offset_bottom = 88
	content.add_child(top)
	var top_margin := _margin(top, 16)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	top_margin.add_child(row)
	var brand_box := VBoxContainer.new()
	brand_box.custom_minimum_size.x = 166
	row.add_child(brand_box)
	_label(brand_box, "MEATCRAFT EMPIRE", 19, PAPER, true)
	_label(brand_box, tr("SMALL WORKSHOP • LEVEL 1"), 10, Color("91aaa2"), true)
	cash_label = _metric(row, "£0.00", tr("CASH"), GOLD)
	time_label = _metric(row, "", tr("SIMULATION"), Color("b8d7d2"))
	reputation_label = _metric(row, "", tr("REPUTATION"), Color("8fc4a3"))
	hygiene_label = _metric(row, "", tr("HYGIENE"), Color("78b9c0"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	pause_button = _button(row, "Ⅱ", MeatGame.toggle_pause)
	pause_button.custom_minimum_size.x = 50
	for scale in [1, 2, 4]:
		var speed := _button(row, "%d×" % scale, MeatGame.set_time_scale.bind(scale))
		speed.custom_minimum_size.x = 43
	var overview := _button(row, tr("Overview"), func(): focus_machine_requested.emit("dryer"))
	overview.custom_minimum_size.x = 88
	var menu := _button(row, tr("Menu"), func():
		MeatGame.save_game()
		show_menu())
	menu.custom_minimum_size.x = 64

	var left := _panel(content, Color(0.055, 0.12, 0.12, 0.96), 0)
	left.position = Vector2(0, 88)
	left.size = Vector2(194, size.y - 88)
	var left_margin := _margin(left, 14)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	left_margin.add_child(nav)
	_label(nav, tr("MANAGEMENT"), 10, Color("7f9a91"), true)
	for item in [["production", tr("Production")], ["inventory", tr("Inventory")], ["orders", tr("Orders")], ["haccp", "HACCP"], ["finance", tr("Finance")]]:
		var tab_id: String = item[0]
		var nav_button := _button(nav, str(item[1]), func(): _set_tab(tab_id))
		nav_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sep := HSeparator.new()
	nav.add_child(sep)
	_label(nav, tr("EQUIPMENT"), 10, Color("7f9a91"), true)
	for machine in [["preparation", tr("Preparation")], ["spice_prep", tr("Spice prep")], ["marination", tr("Marination")], ["dryer", tr("Drying chamber")], ["slicing", tr("Slicing")], ["packaging", tr("Packaging")], ["dispatch", tr("Dispatch")]]:
		var machine_id: String = machine[0]
		var machine_button := _button(nav, str(machine[1]), func():
			current_tab = "machine"
			machine_selected(machine_id)
			focus_machine_requested.emit(machine_id))
		machine_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		machine_button.custom_minimum_size.y = 42
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(filler)
	_button(nav, tr("Settings"), _show_settings)

	var right := _panel(content, Color(0.96, 0.95, 0.91, 0.98), 0)
	right_panel = right
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -366
	right.offset_top = 88
	var right_margin := _margin(right, 22)
	var panel_column := VBoxContainer.new()
	panel_column.add_theme_constant_override("separation", 14)
	right_margin.add_child(panel_column)
	panel_title = _label(panel_column, tr("Production control"), 24, INK, true)
	var separator := HSeparator.new()
	panel_column.add_child(separator)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 11)
	panel_column.add_child(panel_body)

	var objective := _panel(content, Color(0.055, 0.13, 0.13, 0.97), 14)
	objective_panel = objective
	objective.position = Vector2(218, size.y - 112)
	objective.size = Vector2(maxf(460, size.x - 218 - 390), 88)
	var objective_margin := _margin(objective, 17)
	var objective_box := VBoxContainer.new()
	objective_margin.add_child(objective_box)
	_label(objective_box, tr("CURRENT OBJECTIVE"), 10, GOLD, true)
	objective_label = _label(objective_box, "", 17, PAPER, true)

func _metric(parent: Node, value: String, caption: String, accent: Color) -> Label:
	var card := _panel(parent, Color("244346"), 10)
	card.custom_minimum_size = Vector2(116, 57)
	var margin := _margin(card, 8)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var label := _label(box, value, 19, accent, true)
	_label(box, caption, 9, Color("9eb2aa"), true)
	return label

func _set_tab(tab_id: String) -> void:
	current_tab = tab_id
	_refresh_side_panel()

func machine_selected(machine_id: String) -> void:
	selected_machine = machine_id
	if current_screen == "factory" and current_tab == "machine":
		_refresh_side_panel()

func _refresh_ui() -> void:
	if current_screen != "factory" or not is_instance_valid(cash_label):
		return
	cash_label.text = "£%s" % _money(MeatGame.cash)
	time_label.text = MeatGame.game_clock_text()
	reputation_label.text = "%.1f / 5" % MeatGame.reputation
	hygiene_label.text = "%d%%" % roundi(MeatGame.hygiene)
	pause_button.text = "▶" if MeatGame.simulation_paused else "Ⅱ"
	objective_label.text = _objective_text()
	_refresh_side_panel()

func _refresh_side_panel() -> void:
	if not is_instance_valid(panel_body):
		return
	for child in panel_body.get_children():
		panel_body.remove_child(child)
		child.queue_free()
	if not MeatGame.starter_line_owned:
		panel_title.text = tr("Build your first production line")
		_label(panel_body, tr("Your hall is empty and ready. Install a complete starter line with preparation, spice and marination stations, hanging racks, a seven-day drying chamber, slicer and packaging line."), 15, Color("50605c")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_spacer(panel_body)
		_label(panel_body, tr("Starter line"), 19, INK, true)
		_label(panel_body, "£16,500", 30, BRAND, true)
		_label(panel_body, tr("Cash after purchase: £%s") % _money(MeatGame.cash - float(MeatGame.config.starter_line_cost)), 13, Color("6b7773"))
		var install := _button(panel_body, tr("Install starter line"), func():
			if MeatGame.purchase_starter_line():
				_toast(tr("Production line installed."), "milestone"), true)
		install.disabled = MeatGame.cash < float(MeatGame.config.starter_line_cost)
		return
	match current_tab:
		"inventory": _inventory_panel()
		"orders": _orders_panel()
		"haccp": _haccp_panel()
		"finance": _finance_panel()
		"machine": _machine_panel()
		_: _production_panel()

func _production_panel() -> void:
	panel_title.text = tr("Production control")
	if not MeatGame.pending_delivery.is_empty() and MeatGame.pending_delivery.has("remaining"):
		_status_badge(tr("DELIVERY EN ROUTE"), GOLD)
		_label(panel_body, tr(str(MeatGame.pending_delivery.supplier_name)), 20, INK, true)
		_label(panel_body, tr("{kg} kg beef • Lot {lot}").format({"kg": MeatGame.pending_delivery.quantity_kg, "lot": MeatGame.pending_delivery.lot_id}), 14, Color("5d6a66"))
		_progress(panel_body, 1.0 - float(MeatGame.pending_delivery.remaining) / float(MeatGame.config.suppliers[MeatGame.pending_delivery.supplier_id].lead_minutes))
		_label(panel_body, tr("Arrival in {time}").format({"time": _duration(float(MeatGame.pending_delivery.remaining))}), 15, TEAL, true)
		_spacer(panel_body)
		_label(panel_body, tr("Use 2× or 4× simulation speed to advance delivery time."), 13, Color("6a7773")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	if not MeatGame.active_batch.is_empty():
		var batch: Dictionary = MeatGame.active_batch
		_status_badge(MeatGame.stage_name(str(batch.stage)).to_upper(), BRAND)
		_label(panel_body, "%s • %s" % [batch.id, tr(str(batch.recipe_name))], 20, INK, true)
		_label(panel_body, tr("Traceability lot: {lot}").format({"lot": batch.supplier_lot}), 13, Color("66736f"))
		_progress(panel_body, MeatGame.stage_progress())
		_label(panel_body, tr("{percent}% • {time} remaining").format({"percent": roundi(MeatGame.stage_progress() * 100.0), "time": _duration(MeatGame.stage_remaining())}), 15, TEAL, true)
		if str(batch.stage) == "drying":
			_label(panel_body, tr("Drying day {day} of 7").format({"day": minf(7.0, float(batch.stage_elapsed) / 1440.0 + 1.0)}), 16, INK, true)
			_label(panel_body, tr("The strips darken and lose moisture gradually. This is a fictional accelerated game clock, not production guidance."), 13, Color("596863")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if bool(batch.get("inspection_required", false)):
			_status_badge(tr("INSPECTION REQUIRED"), GOLD)
			_button(panel_body, tr("Record mid-cycle inspection"), func(): MeatGame.perform_mid_dry_inspection(), true)
		return
	var total_finished := int(MeatGame.inventory.finished_coriander) + int(MeatGame.inventory.finished_chilli) + int(MeatGame.inventory.finished_bbq)
	if total_finished > 0:
		_status_badge(tr("READY TO DISPATCH"), Color("5b9b72"))
		_label(panel_body, tr("Finished products passed the simulated quality gate and are ready for customer orders."), 14, Color("56645f")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for recipe_id in ["coriander", "chilli", "bbq"]:
			var packs := int(MeatGame.inventory["finished_" + recipe_id])
			if packs > 0:
				var recipe: Dictionary = MeatGame.config.recipes[recipe_id]
				var sale := packs * float(recipe.sale_per_pack)
				_button(panel_body, tr("Dispatch {packs} × {name} • £{value}").format({"packs": packs, "name": tr(str(recipe.name)), "value": _money(sale)}), MeatGame.dispatch_order.bind(recipe_id), true)
		return
	if float(MeatGame.inventory.raw_beef_kg) < 10.0:
		_label(panel_body, tr("Procure traceable beef"), 20, INK, true)
		_label(panel_body, tr("Supplier choice changes price, lead time and the starting quality of your batch."), 14, Color("5b6965")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for supplier_id in ["economy", "standard", "premium"]:
			var supplier: Dictionary = MeatGame.config.suppliers[supplier_id]
			var price := float(supplier.price_per_kg) * 20.0
			var supplier_button := _button(panel_body, "%s\n£%.2f • %s" % [tr(str(supplier.name)), price, _duration(float(supplier.lead_minutes))], MeatGame.order_beef.bind(supplier_id, 20.0), supplier_id == "standard")
			supplier_button.disabled = MeatGame.cash < price
	else:
		_label(panel_body, tr("Choose the next recipe"), 20, INK, true)
		_label(panel_body, tr("Each 10 kg batch is prepared, seasoned, marinated for 24 game-hours, hung, dried for seven game-days, sliced and packed."), 14, Color("5c6965")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		for recipe_id in ["coriander", "chilli", "bbq"]:
			var recipe: Dictionary = MeatGame.config.recipes[recipe_id]
			var recipe_button := _button(panel_body, "%s\n%s • %s" % [tr(str(recipe.name)), tr(str(recipe.claim)), tr("Allergens: soy, gluten")], MeatGame.start_batch.bind(recipe_id, 10.0), recipe_id == "coriander")
			recipe_button.tooltip_text = tr("BBQ contains sugar and honey; no sugar-free claim is made.") if recipe_id == "bbq" else tr(str(recipe.claim))

func _inventory_panel() -> void:
	panel_title.text = tr("Inventory & mass balance")
	_status_badge(tr("LIVE STOCK"), TEAL)
	_inventory_row(tr("Raw beef"), "%.2f kg" % float(MeatGame.inventory.raw_beef_kg))
	_inventory_row(tr("Coriander spice"), "%d units" % int(MeatGame.inventory.coriander))
	_inventory_row(tr("Chilli spice"), "%d units" % int(MeatGame.inventory.chilli))
	_inventory_row(tr("BBQ spice"), "%d units" % int(MeatGame.inventory.bbq))
	_inventory_row(tr("Packaging"), "%d packs" % int(MeatGame.inventory.packaging))
	var total := int(MeatGame.inventory.finished_coriander) + int(MeatGame.inventory.finished_chilli) + int(MeatGame.inventory.finished_bbq)
	_inventory_row(tr("Finished goods"), "%d packs" % total)
	_spacer(panel_body)
	_label(panel_body, tr("ILLUSTRATIVE GAME YIELD"), 11, BRAND, true)
	_label(panel_body, tr("10 kg raw beef → 9.4 kg prepared → 4.7 kg dried → 94 × 50 g packs"), 14, INK, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label(panel_body, tr("Yield is configurable fictional balancing and not a production specification."), 12, Color("68736f")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var restock := _button(panel_body, tr("Order 100 packaging units • £24"), MeatGame.buy_packaging)
	restock.disabled = MeatGame.cash < float(MeatGame.config.packaging_restock_cost)

func _orders_panel() -> void:
	panel_title.text = tr("Customer orders")
	_status_badge(tr("LOCAL WHOLESALE"), GOLD)
	_label(panel_body, tr("Current customers accept all completed 50 g packs at the configured game price."), 14, Color("586661")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for recipe_id in ["coriander", "chilli", "bbq"]:
		var recipe: Dictionary = MeatGame.config.recipes[recipe_id]
		_inventory_row(tr(str(recipe.name)), "£%.2f / pack" % float(recipe.sale_per_pack))
	_spacer(panel_body)
	_label(panel_body, tr("Future contracts unlock with reputation. Live MeatCraft shop prices are not used by this fictional economy."), 13, Color("67736f")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _haccp_panel() -> void:
	panel_title.text = tr("Food-safety management")
	_status_badge(tr("SIMPLIFIED EDUCATIONAL GAME SYSTEM"), TEAL)
	_label(panel_body, tr("This is not a legally sufficient HACCP system or real production guidance."), 13, BRAND, true).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_row(tr("Cleanliness"), "%d%%" % roundi(MeatGame.hygiene))
	_inventory_row(tr("Traceability records"), tr("CURRENT"))
	_inventory_row(tr("Zone separation"), tr("PASS"))
	_inventory_row(tr("Dryer condition"), "%d%%" % roundi(MeatGame.machine_condition))
	_spacer(panel_body)
	var clean := _button(panel_body, tr("Complete cleaning round • £45"), MeatGame.clean_factory, true)
	clean.disabled = MeatGame.hygiene >= 99.0 or MeatGame.cash < 45.0
	_label(panel_body, tr("Receiving checks, supplier lot, recipe, machine history and inspections are recorded with each active batch."), 13, Color("65716d")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _finance_panel() -> void:
	panel_title.text = tr("Company finances")
	_inventory_row(tr("Cash balance"), "£%s" % _money(MeatGame.cash))
	_inventory_row(tr("Lifetime sales"), "£%s" % _money(MeatGame.lifetime_revenue))
	_inventory_row(tr("Lifetime expenses"), "£%s" % _money(MeatGame.lifetime_expenses))
	_inventory_row(tr("Operating result"), "£%s" % _money(MeatGame.lifetime_revenue - MeatGame.lifetime_expenses))
	_inventory_row(tr("Batches completed"), str(MeatGame.batches_completed))
	_spacer(panel_body)
	_label(panel_body, tr("Fictional balancing values are stored in config/meatcraft_game.json."), 13, Color("65716d")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _machine_panel() -> void:
	var data: Array = {
		"preparation": [tr("Preparation Table"), tr("Trimming and portioning station"), "94%", "£3,800"],
		"spice_prep": [tr("Spice Station"), tr("Recipe-controlled seasoning preparation"), "10 kg", "£2,100"],
		"marination": [tr("Marination Drums"), tr("Traceable 24-hour accelerated game process"), "20 kg", "£2,900"],
		"dryer": [tr("Drying Chamber DC-01"), tr("Seven-day controlled air-drying simulation"), "30 kg", "£5,200"],
		"slicing": [tr("Precision Slicer SL-01"), tr("Whole-to-sliced finished product conversion"), "12 kg/h", "£1,450"],
		"packaging": [tr("Packaging Line PK-01"), tr("Weighing, sealing and labelled 50 g packs"), "240 packs/h", "£1,050"],
		"dispatch": [tr("Finished Goods & Dispatch"), tr("Protected storage and customer order handoff"), "360 packs", "£600"]
	}.get(selected_machine, [tr("Factory equipment"), "", "", ""])
	panel_title.text = data[0]
	_status_badge(tr("RUNNING") if _machine_is_active(selected_machine) else tr("AVAILABLE"), Color("5b9b72") if _machine_is_active(selected_machine) else TEAL)
	_label(panel_body, data[1], 15, Color("52615d")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inventory_row(tr("Capacity"), data[2])
	_inventory_row(tr("Purchase value"), data[3])
	if selected_machine == "dryer":
		_inventory_row(tr("Condition"), "%d%%" % roundi(MeatGame.machine_condition))
		_inventory_row(tr("Ventilation"), tr("ACTIVE") if _machine_is_active("dryer") else tr("STANDBY"))
		var maintain := _button(panel_body, tr("Preventive maintenance • £280"), MeatGame.maintain_dryer, true)
		maintain.disabled = MeatGame.machine_condition >= 99.0 or MeatGame.cash < float(MeatGame.config.maintenance_cost)
	_spacer(panel_body)
	_button(panel_body, tr("Focus camera"), func(): focus_machine_requested.emit(selected_machine))

func _machine_is_active(id: String) -> bool:
	if MeatGame.active_batch.is_empty():
		return false
	var stage := str(MeatGame.active_batch.stage)
	return id == stage or (id == "dryer" and stage == "drying")

func _inventory_row(title: String, value: String) -> void:
	var row := HBoxContainer.new()
	panel_body.add_child(row)
	var title_label := _label(row, title, 14, Color("586762"))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(row, value, 14, INK, true)

func _status_badge(value: String, colour: Color) -> void:
	var badge := _panel(panel_body, colour, 7)
	var margin := _margin(badge, 8)
	var label := _label(margin, value, 11, Color.WHITE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _progress(parent: Node, value: float) -> void:
	var progress := ProgressBar.new()
	progress.show_percentage = false
	progress.value = value * 100.0
	progress.custom_minimum_size.y = 13
	parent.add_child(progress)

func _spacer(parent: Node, height := 14) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	parent.add_child(spacer)

func _objective_text() -> String:
	if not MeatGame.starter_line_owned:
		return tr("Install the starter production line")
	if not MeatGame.pending_delivery.is_empty() and MeatGame.pending_delivery.has("remaining"):
		return tr("Wait for the traceable beef delivery • try 4× speed")
	if not MeatGame.active_batch.is_empty():
		if bool(MeatGame.active_batch.get("inspection_required", false)):
			return tr("Inspect the drying batch before production can continue")
		return tr("Supervise {batch}: {stage}").format({"batch": MeatGame.active_batch.id, "stage": MeatGame.stage_name(str(MeatGame.active_batch.stage))})
	var finished := int(MeatGame.inventory.finished_coriander) + int(MeatGame.inventory.finished_chilli) + int(MeatGame.inventory.finished_bbq)
	if finished > 0:
		return tr("Dispatch finished packs and earn your first revenue")
	if float(MeatGame.inventory.raw_beef_kg) < 10.0:
		return tr("Choose a supplier and order 20 kg of beef")
	return tr("Choose a recipe and start a 10 kg production batch")

func _show_settings() -> void:
	var shade := ColorRect.new()
	shade.name = "SettingsModal"
	shade.color = Color(0.01, 0.04, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 20
	content.add_child(shade)
	var card := _panel(shade, PAPER)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-260, -240)
	card.size = Vector2(520, 480)
	var margin := _margin(card, 32)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 15)
	margin.add_child(box)
	_label(box, tr("Settings"), 28, INK, true)
	_label(box, tr("Landscape is required on phones. Camera: drag to pan, wheel or pinch to zoom, Q/E to rotate."), 14, Color("5c6a66")).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var master := HSlider.new()
	master.min_value = 0.0
	master.max_value = 1.0
	master.step = 0.05
	master.value = MeatGame.master_volume
	master.value_changed.connect(func(value: float): MeatGame.master_volume = value)
	_label(box, tr("Master volume"), 14, INK, true)
	box.add_child(master)
	var motion := CheckButton.new()
	motion.text = tr("Reduce ambient motion")
	motion.button_pressed = MeatGame.reduced_motion
	motion.toggled.connect(func(value: bool): MeatGame.reduced_motion = value)
	box.add_child(motion)
	var language := _button(box, tr("Language: English / Polski"), _switch_language.bind(shade))
	language.tooltip_text = tr("A complete Polish localisation pass is in progress for the new 3D interface.")
	_spacer(box)
	_button(box, tr("Save and close"), func():
		MeatGame.save_game()
		shade.queue_free(), true)

func _switch_language(shade: Control) -> void:
	MeatGame.language = "pl" if MeatGame.language == "en" else "en"
	TranslationServer.set_locale(MeatGame.language)
	shade.queue_free()
	match current_screen:
		"menu": show_menu()
		"property": show_property_selection()
		"industry": show_industry_selection()
		_: show_factory()

func _toast(message: String, kind: String = "info") -> void:
	if not is_instance_valid(toast_layer):
		return
	var colour := GOLD if kind in ["milestone", "sale"] else BRAND if kind == "warning" else Color("dfe8dc")
	var toast := _panel(toast_layer, colour, 12)
	toast.position = Vector2((size.x - 620) * 0.5, 104)
	toast.size = Vector2(620, 58)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margin := _margin(toast, 13)
	var label := _label(margin, tr(message), 15, INK, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tween := create_tween()
	tween.tween_interval(2.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)

func blocks_world_input() -> bool:
	return current_screen != "factory"

func _money(value: float) -> String:
	var string := "%.2f" % value
	var parts := string.split(".")
	var whole := parts[0]
	var out := ""
	while whole.length() > 3:
		out = "," + whole.right(3) + out
		whole = whole.left(whole.length() - 3)
	return whole + out + "." + parts[1]

func _duration(game_minutes: float) -> String:
	var days := floori(game_minutes / 1440.0)
	var hours := floori(fmod(game_minutes, 1440.0) / 60.0)
	var minutes := floori(fmod(game_minutes, 60.0))
	if days > 0:
		return "%dd %dh" % [days, hours]
	if hours > 0:
		return "%dh %02dm" % [hours, minutes]
	return "%dm" % minutes

func _process(delta: float) -> void:
	_refresh += delta
	if _refresh > 0.25 and current_screen == "factory":
		_refresh = 0.0
		_refresh_ui()
