extends Node
## Composition root for the true-3D MeatCraft game.

var factory: MeatFactory3D
var camera_rig: FactoryCamera
var ui: Control

func _ready() -> void:
	_build_world()
	factory = MeatFactory3D.new()
	factory.name = "MeatCraftFactory"
	$World.add_child(factory)
	camera_rig = FactoryCamera.new()
	camera_rig.name = "FactoryCameraRig"
	$World.add_child(camera_rig)
	camera_rig.world_tapped.connect(_on_world_tapped)
	factory.machine_selected.connect(_on_machine_selected)
	ui = preload("res://scripts/meatcraft/meatcraft_ui.gd").new()
	ui.name = "MeatCraftUI"
	$Interface.add_child(ui)
	ui.focus_machine_requested.connect(_focus_machine)
	ui.screen_changed.connect(_on_screen_changed)
	ui.machine_selected("dryer")
	_on_screen_changed(ui.current_screen)
	if "--smoke-factory" in OS.get_cmdline_user_args():
		if not MeatGame.save_exists:
			MeatGame.new_company()
			MeatGame.acquire_small_hall()
			MeatGame.select_meatcraft()
			MeatGame.purchase_starter_line()
		ui.show_factory()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _build_world() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("b8c6c2")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("dce4df")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.78
	environment.glow_enabled = false
	environment.fog_enabled = true
	environment.fog_light_color = Color("cfd8d4")
	environment.fog_light_energy = 0.35
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.55
	$World/WorldEnvironment.environment = environment
	var sun := DirectionalLight3D.new()
	sun.name = "FactorySun"
	sun.rotation_degrees = Vector3(-54, -32, 0)
	sun.light_color = Color("ffdfb4")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	$World.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"
	fill.rotation_degrees = Vector3(-34, 145, 0)
	fill.light_color = Color("b9d9df")
	fill.light_energy = 0.25
	fill.shadow_enabled = false
	$World.add_child(fill)

func _on_world_tapped(screen_position: Vector2) -> void:
	if ui.blocks_world_input():
		return
	var id := factory.pick_from_screen(camera_rig.camera, screen_position)
	if not id.is_empty():
		ui.machine_selected(id)

func _on_machine_selected(id: String) -> void:
	if is_instance_valid(ui):
		ui.machine_selected(id)

func _focus_machine(id: String) -> void:
	if not factory.machines.has(id):
		return
	factory.select_machine(id)
	camera_rig.focus(factory.machines[id].global_position, 14.5 if id == "dryer" else 13.0)

func _on_screen_changed(screen: String) -> void:
	if screen == "menu":
		camera_rig.overview()
		factory.visible = true
		factory.set_preview_mode(true)
	elif screen in ["property", "industry"]:
		camera_rig.overview()
		factory.visible = true
		factory.set_preview_mode(false)
	else:
		factory.visible = true
		factory.set_preview_mode(false)
		camera_rig.overview()

func _capture() -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture")
	if index >= 0 and index + 1 < args.size():
		get_viewport().get_texture().get_image().save_png(args[index + 1])
	get_tree().quit()
