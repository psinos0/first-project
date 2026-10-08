class_name MeatFactory3D
extends Node3D
## Modular Compatibility-renderer factory. All geometry is original and engine-native.

signal machine_selected(machine_id: String)

const STEEL := Color("78848a")
const DARK_STEEL := Color("303c42")
const LIGHT_STEEL := Color("c5ced0")
const SAFETY := Color("e19b38")
const BRAND := Color("b84932")
const FLOOR := Color("687371")
const CLEAN := Color("d9ddd8")
var machines: Dictionary = {}
var machine_lights: Dictionary = {}
var fans: Array[Node3D] = []
var conveyor_items: Array[Node3D] = []
var meat_strips: Array[MeshInstance3D] = []
var workers: Array[Node3D] = []
var selection_marker: MeshInstance3D
var selected_id := "dryer"
var preview_mode := true
var elapsed := 0.0
var _last_visual_stage := ""

func _ready() -> void:
	_build_factory()
	MeatGame.stage_changed.connect(_on_stage_changed)
	MeatGame.state_changed.connect(_update_state)
	select_machine("dryer")
	_update_state()

func _process(delta: float) -> void:
	elapsed += delta
	var active: bool = not MeatGame.active_batch.is_empty()
	var stage := str(MeatGame.active_batch.get("stage", ""))
	for fan in fans:
		if stage == "drying" and not bool(MeatGame.active_batch.get("inspection_required", false)):
			fan.rotate_object_local(Vector3.FORWARD, delta * 4.5 * MeatGame.time_scale)
	for i in range(conveyor_items.size()):
		var item: Node3D = conveyor_items[i]
		if active and stage in ["slicing", "packaging"]:
			item.position.x = 4.8 + fmod(elapsed * 0.7 + i * 1.3, 4.7)
			item.visible = true
		else:
			item.visible = false
	for i in range(workers.size()):
		var worker: Node3D = workers[i]
		var base_y: float = float(worker.get_meta("base_y", worker.position.y))
		worker.position.y = base_y + (sin(elapsed * 2.0 + i * 1.7) * 0.025 if not MeatGame.reduced_motion else 0.0)
	if stage != _last_visual_stage:
		_last_visual_stage = stage
		_update_state()

func _build_factory() -> void:
	# Foundation, washable resin zones and open-front shell.
	_box(self, "Foundation", Vector3(0, -0.35, 0), Vector3(24, 0.7, 18), Color("545b5e"), 0.0, 0.92)
	_box(self, "ResinFloor", Vector3(0, 0.02, 0), Vector3(23.4, 0.10, 17.4), FLOOR, 0.0, 0.76)
	_zone(Vector3(-5.8, 0.085, -0.8), Vector3(8.4, 0.02, 13.8), Color("738481"))
	_zone(Vector3(4.5, 0.087, -1.4), Vector3(10.0, 0.022, 12.6), Color("878477"))
	for x in range(-11, 12, 2):
		_box(self, "FloorJoint", Vector3(x, 0.10, 0), Vector3(0.025, 0.012, 17.2), Color("4e5957"))
	for z in range(-8, 9, 2):
		_box(self, "FloorJoint", Vector3(0, 0.10, z), Vector3(23.2, 0.012, 0.025), Color("4e5957"))
	# Walls are kept low/open on the camera side; structural details keep depth readable.
	_box(self, "BackWall", Vector3(0, 3.1, -8.7), Vector3(24, 6.2, 0.35), Color("d6d5ce"))
	_box(self, "LeftWall", Vector3(-11.7, 3.1, 0), Vector3(0.35, 6.2, 18), Color("c8cbc6"))
	_box(self, "RightReturn", Vector3(11.7, 1.5, -5.8), Vector3(0.35, 3.0, 5.8), Color("c8cbc6"))
	for x in [-9.0, -3.0, 3.0, 9.0]:
		_box(self, "Column", Vector3(x, 3.35, -8.35), Vector3(0.42, 6.7, 0.45), DARK_STEEL, 0.55, 0.38)
		_box(self, "RoofBeam", Vector3(x, 6.25, -4.1), Vector3(0.20, 0.20, 8.3), DARK_STEEL, 0.65, 0.32)
	# Roller door, loading stripes and exterior dock.
	_box(self, "RollerDoor", Vector3(-7.9, 2.5, -8.47), Vector3(4.8, 4.7, 0.12), Color("8e999b"), 0.65, 0.28)
	for y in range(5):
		_box(self, "DoorSlat", Vector3(-7.9, 0.58 + y * 0.9, -8.38), Vector3(4.55, 0.055, 0.04), Color("d4d8d5"), 0.35, 0.4)
	_box(self, "DockBumper", Vector3(-7.9, 0.35, -7.8), Vector3(5.4, 0.25, 0.7), Color("31383a"), 0.1, 0.95)
	# Ceiling utilities, ducts, cable trays and warm industrial lighting.
	for z in [-6.8, -4.8, -2.8]:
		_pipe(Vector3(-10.7, 5.55, z), Vector3(10.7, 5.55, z), 0.075, LIGHT_STEEL)
	for x in [-7.0, 0.0, 7.0]:
		_add_light_fixture(Vector3(x, 5.65, -3.7))
		_add_light_fixture(Vector3(x, 5.65, 3.6))
	# Marked hygiene zones and safety walkways.
	_floor_label("RAW / RECEIVING", Vector3(-8.0, 0.13, 6.6), BRAND)
	_floor_label("CONTROLLED PROCESS", Vector3(-1.0, 0.13, 6.6), Color("3e7776"))
	_floor_label("FINISHED PRODUCT", Vector3(7.0, 0.13, 6.6), SAFETY)
	for z in [-7.8, 7.8]:
		_box(self, "SafetyLine", Vector3(0, 0.14, z), Vector3(22.6, 0.025, 0.12), SAFETY)
	# Environment props first, then functional hero equipment.
	_build_receiving()
	_build_prep_station()
	_build_spice_station()
	_build_marination()
	_build_dryer()
	_build_slicer()
	_build_packaging()
	_build_storage()
	_build_workers()
	selection_marker = MeshInstance3D.new()
	selection_marker.name = "SelectionMarker"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.88
	ring.outer_radius = 0.98
	ring.rings = 24
	ring.ring_segments = 8
	selection_marker.mesh = ring
	selection_marker.material_override = _material(Color("f4b447"), 0.1, 0.3, Color("e48e2e"), 1.6)
	selection_marker.rotation_degrees.x = 90
	selection_marker.position.y = 0.14
	add_child(selection_marker)

func _build_receiving() -> void:
	var root := _machine_root("receiving", "Goods Receiving", Vector3(-8.7, 0, 4.9), Vector3(4.5, 2.4, 3.4))
	_box(root, "Pallet", Vector3(0, 0.13, 0), Vector3(2.8, 0.25, 1.8), Color("9c7047"))
	for x in [-0.8, 0.0, 0.8]:
		_box(root, "Crate", Vector3(x, 0.55, 0), Vector3(0.7, 0.7, 1.2), Color("c79559"))
		_box(root, "CrateBand", Vector3(x, 0.58, 0), Vector3(0.73, 0.10, 1.23), DARK_STEEL, 0.55, 0.35)
	_box(root, "ScannerPost", Vector3(1.6, 1.0, -0.8), Vector3(0.18, 2.0, 0.18), DARK_STEEL)
	_box(root, "Scanner", Vector3(1.6, 1.8, -0.8), Vector3(0.65, 0.42, 0.24), LIGHT_STEEL, 0.55, 0.22)
	_light(root, Vector3(1.6, 1.82, -0.66), Color("55d58a"))

func _build_prep_station() -> void:
	var root := _machine_root("preparation", "Preparation Table", Vector3(-6.2, 0, 0.9), Vector3(4.2, 2.7, 3.0))
	for x in [-1.35, 1.35]:
		for z in [-0.75, 0.75]:
			_box(root, "Leg", Vector3(x, 0.65, z), Vector3(0.13, 1.3, 0.13), DARK_STEEL, 0.8, 0.22)
	_box(root, "Worktop", Vector3(0, 1.35, 0), Vector3(3.4, 0.18, 2.0), LIGHT_STEEL, 0.8, 0.18)
	_box(root, "Splashback", Vector3(0, 1.82, -0.92), Vector3(3.4, 0.82, 0.12), STEEL, 0.75, 0.25)
	var board := _box(root, "CuttingBoard", Vector3(-0.6, 1.49, 0.15), Vector3(1.25, 0.07, 0.8), Color("e8d8a9"))
	board.rotation_degrees.y = -5
	for i in range(4):
		var strip := MeshInstance3D.new()
		strip.name = "PreparedStrip"
		strip.mesh = _meat_mesh(i + 14, 0.0)
		strip.material_override = _material(Color("a8493c"), 0.0, 0.72)
		strip.position = Vector3(-0.85 + i * 0.22, 1.56, 0.12)
		strip.scale = Vector3(0.55, 0.36, 0.55)
		root.add_child(strip)
	_box(root, "Knife", Vector3(0.55, 1.57, 0.2), Vector3(0.8, 0.035, 0.13), Color("d9e0df"), 0.85, 0.16)
	_box(root, "KnifeHandle", Vector3(0.98, 1.57, 0.2), Vector3(0.28, 0.09, 0.18), DARK_STEEL)
	_add_machine_panel(root, Vector3(1.55, 1.72, -0.65), "PREP")

func _build_spice_station() -> void:
	var root := _machine_root("spice_prep", "Spice Station", Vector3(-6.1, 0, -4.2), Vector3(3.8, 3.2, 2.8))
	_box(root, "Cabinet", Vector3(0, 0.72, 0), Vector3(3.0, 1.35, 1.75), Color("495b5f"), 0.55, 0.35)
	_box(root, "Counter", Vector3(0, 1.45, 0), Vector3(3.15, 0.16, 1.9), LIGHT_STEEL, 0.8, 0.16)
	for i in range(5):
		_cylinder(root, "SpiceJar", Vector3(-1.05 + i * 0.52, 1.78, -0.45), 0.17, 0.55, Color.from_hsv(0.05 + i * 0.07, 0.48, 0.72))
		_cylinder(root, "JarLid", Vector3(-1.05 + i * 0.52, 2.07, -0.45), 0.185, 0.05, DARK_STEEL, 0.75, 0.25)
	_cylinder(root, "MixerBowl", Vector3(0, 1.66, 0.35), 0.55, 0.28, LIGHT_STEEL, 0.85, 0.14)
	_cylinder(root, "MixerHead", Vector3(0, 2.35, 0.35), 0.38, 0.32, Color("d0a04a"), 0.5, 0.3)
	_box(root, "MixerArm", Vector3(0, 2.18, 0.35), Vector3(0.12, 0.7, 0.12), DARK_STEEL, 0.8, 0.2)
	_add_machine_panel(root, Vector3(1.48, 1.9, 0.55), "SPICE")

func _build_marination() -> void:
	var root := _machine_root("marination", "Marination Drums", Vector3(-1.7, 0, -4.5), Vector3(4.5, 3.5, 3.2))
	for x in [-1.0, 1.0]:
		_cylinder(root, "MarinationVat", Vector3(x, 1.12, 0), 0.72, 1.9, STEEL, 0.85, 0.18)
		_cylinder(root, "Lid", Vector3(x, 2.09, 0), 0.76, 0.10, LIGHT_STEEL, 0.9, 0.12)
		_torus(root, Vector3(x, 2.19, 0), 0.18, 0.04, DARK_STEEL)
		_box(root, "VatStand", Vector3(x, 0.18, 0), Vector3(1.65, 0.22, 1.65), DARK_STEEL, 0.7, 0.28)
	_add_machine_panel(root, Vector3(0, 1.65, 1.0), "24H MARINATION")

func _build_dryer() -> void:
	var root := _machine_root("dryer", "Drying Chamber DC-01", Vector3(2.4, 0, -2.2), Vector3(5.3, 5.5, 5.0))
	# Insulated shell is built from panels so the loaded interior remains genuinely visible.
	_box(root, "CabinetBack", Vector3(0, 2.4, -1.68), Vector3(4.6, 4.8, 0.18), Color("404c51"), 0.72, 0.25)
	_box(root, "CabinetLeft", Vector3(-2.21, 2.4, 0), Vector3(0.22, 4.8, 3.5), Color("404c51"), 0.72, 0.25)
	_box(root, "CabinetRight", Vector3(2.21, 2.4, 0), Vector3(0.22, 4.8, 3.5), Color("404c51"), 0.72, 0.25)
	_box(root, "CabinetTop", Vector3(0, 4.7, 0), Vector3(4.6, 0.22, 3.5), Color("404c51"), 0.72, 0.25)
	_box(root, "CabinetFloor", Vector3(0, 0.18, 0), Vector3(4.6, 0.22, 3.5), Color("404c51"), 0.72, 0.25)
	_box(root, "ChamberBack", Vector3(0, 2.38, -1.56), Vector3(3.9, 4.05, 0.08), Color("151d20"), 0.2, 0.85)
	for x in [-2.24, 2.24]:
		_box(root, "Door", Vector3(x + (-0.5 if x < 0 else 0.5), 2.35, 2.25), Vector3(1.9, 4.25, 0.16), STEEL, 0.78, 0.19)
		_box(root, "DoorGlass", Vector3(x + (-0.5 if x < 0 else 0.5), 2.58, 2.33), Vector3(1.3, 2.7, 0.04), Color(0.12, 0.21, 0.22, 0.72), 0.35, 0.12, true)
		_box(root, "Handle", Vector3(x + (-1.23 if x < 0 else 1.23), 2.4, 2.48), Vector3(0.09, 1.2, 0.10), Color("d6a24d"), 0.75, 0.16)
	# Internal rails, hooks and individually varied meat pieces.
	for row in range(3):
		var z := 0.6 + row * 0.48
		_pipe(root.to_global(Vector3(-1.6, 4.0, z)), root.to_global(Vector3(1.6, 4.0, z)), 0.045, LIGHT_STEEL, root)
		for i in range(7):
			var x := -1.45 + i * 0.48
			var hook := Node3D.new()
			hook.name = "Hook"
			hook.position = Vector3(x, 3.77, z)
			root.add_child(hook)
			_torus(hook, Vector3.ZERO, 0.10, 0.025, LIGHT_STEEL, Vector3(90, 0, 0), 0.56)
			var meat := MeshInstance3D.new()
			meat.name = "BiltongStrip"
			meat.mesh = _meat_mesh(row * 10 + i, 0.45)
			meat.material_override = _material(Color("78362c"), 0.0, 0.9)
			meat.position = Vector3(0, -0.58 - fmod(i * 0.17, 0.25), 0)
			meat.scale = Vector3(0.45, 0.55 + fmod(i * 0.13, 0.14), 0.45)
			hook.add_child(meat)
			meat_strips.append(meat)
	# Two fan housings, blades, displays, grille, warning and feet.
	for x in [-1.05, 1.05]:
		_cylinder(root, "FanHousing", Vector3(x, 4.45, -1.78), 0.58, 0.16, DARK_STEEL, 0.6, 0.3, Vector3(90, 0, 0))
		var fan := Node3D.new()
		fan.name = "VentilationFan"
		fan.position = Vector3(x, 4.45, -1.9)
		root.add_child(fan)
		for blade in range(5):
			var blade_mesh := _box(fan, "Blade", Vector3(0.28, 0, 0), Vector3(0.48, 0.13, 0.05), LIGHT_STEEL, 0.7, 0.2)
			blade_mesh.rotation_degrees.z = blade * 72.0
		fans.append(fan)
	_add_machine_panel(root, Vector3(0, 3.9, -1.86), "DC-01  7 DAY")
	for x in [-1.7, 1.7]:
		for z in [-1.25, 1.25]:
			_cylinder(root, "Foot", Vector3(x, 0.16, z), 0.11, 0.32, DARK_STEEL, 0.7, 0.25)
	machine_lights.dryer = _light(root, Vector3(1.65, 3.85, -1.86), Color("5ddb87"))

func _build_slicer() -> void:
	var root := _machine_root("slicing", "Precision Slicer SL-01", Vector3(6.8, 0, 0.5), Vector3(4.2, 3.5, 3.0))
	_box(root, "Base", Vector3(0, 0.72, 0), Vector3(3.25, 1.35, 2.1), DARK_STEEL, 0.6, 0.32)
	_box(root, "SteelTop", Vector3(0, 1.45, 0), Vector3(3.4, 0.16, 2.2), LIGHT_STEEL, 0.85, 0.15)
	_box(root, "BladeGuard", Vector3(0.45, 2.15, 0), Vector3(0.35, 1.45, 1.8), Color("718387"), 0.65, 0.25)
	_cylinder(root, "Blade", Vector3(0.27, 2.12, 0), 0.70, 0.08, Color("d9dfde"), 0.9, 0.1, Vector3(90, 0, 0))
	_box(root, "FeedTray", Vector3(-0.9, 1.67, 0), Vector3(1.25, 0.10, 1.4), STEEL, 0.8, 0.2)
	_box(root, "OutputTray", Vector3(1.15, 1.67, 0), Vector3(1.0, 0.10, 1.4), STEEL, 0.8, 0.2)
	_add_machine_panel(root, Vector3(-1.45, 2.15, 1.02), "SLICE")

func _build_packaging() -> void:
	var root := _machine_root("packaging", "Packaging Line PK-01", Vector3(6.8, 0, 4.4), Vector3(6.0, 3.3, 3.0))
	_box(root, "Conveyor", Vector3(0, 1.02, 0), Vector3(5.0, 0.35, 1.15), DARK_STEEL, 0.55, 0.42)
	for x in range(-2, 3):
		_cylinder(root, "Roller", Vector3(x, 1.22, 0), 0.16, 1.22, STEEL, 0.75, 0.24, Vector3(90, 0, 0))
	_box(root, "SealerLeft", Vector3(-0.45, 1.85, 0), Vector3(0.30, 1.35, 1.7), STEEL, 0.7, 0.23)
	_box(root, "SealerRight", Vector3(0.45, 1.85, 0), Vector3(0.30, 1.35, 1.7), STEEL, 0.7, 0.23)
	_box(root, "SealerTop", Vector3(0, 2.48, 0), Vector3(1.25, 0.25, 1.7), Color("cf9b39"), 0.45, 0.3)
	_add_machine_panel(root, Vector3(-1.7, 2.0, 0.9), "PACK 50g")
	for i in range(4):
		var packet := _box(root, "BiltongPack", Vector3(1.0 + i * 0.62, 1.38, 0), Vector3(0.42, 0.08, 0.70), Color("ece7d8"), 0.05, 0.65)
		_box(packet, "BrandBand", Vector3(0, 0.05, 0), Vector3(0.30, 0.02, 0.50), BRAND)
		conveyor_items.append(packet)

func _build_storage() -> void:
	var root := _machine_root("dispatch", "Finished Goods & Dispatch", Vector3(9.3, 0, -5.5), Vector3(4.2, 4.2, 4.8))
	for y in [0.4, 1.7, 3.0]:
		_box(root, "Shelf", Vector3(0, y, 0), Vector3(3.1, 0.13, 3.4), Color("cb8a36"), 0.55, 0.32)
	for x in [-1.42, 1.42]:
		for z in [-1.5, 1.5]:
			_box(root, "ShelfPost", Vector3(x, 1.75, z), Vector3(0.13, 3.5, 0.13), DARK_STEEL, 0.68, 0.25)
	for level in range(3):
		for i in range(3):
			_box(root, "DispatchBox", Vector3(-0.82 + i * 0.82, 0.76 + level * 1.3, 0.35), Vector3(0.65, 0.58, 0.95), Color("b9864f"))
	_box(root, "DispatchTable", Vector3(0, 0.75, 3.0), Vector3(3.4, 1.4, 1.35), LIGHT_STEEL, 0.8, 0.2)
	_floor_label("DISPATCH", Vector3(0, 1.5, 3.65), BRAND, root)

func _build_workers() -> void:
	workers.append(_worker(Vector3(-5.7, 0, 2.6), Color("50a7bb"), "Alex"))
	workers.append(_worker(Vector3(4.8, 0, -0.8), Color("4b94b8"), "Sam"))
	workers.append(_worker(Vector3(8.2, 0, 5.8), Color("e09838"), "Maya"))

func _worker(at: Vector3, cap_colour: Color, worker_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Worker_" + worker_name
	root.position = at
	root.set_meta("base_y", at.y)
	add_child(root)
	_cylinder(root, "Boots", Vector3(0, 0.16, 0), 0.25, 0.30, DARK_STEEL)
	_cylinder(root, "Legs", Vector3(0, 0.65, 0), 0.25, 0.78, Color("344a59"))
	var torso := _cylinder(root, "Coat", Vector3(0, 1.42, 0), 0.39, 0.92, Color("ecf0e9"), 0.0, 0.82)
	torso.scale = Vector3(1.0, 1.0, 0.72)
	_cylinder(root, "Head", Vector3(0, 2.15, 0), 0.28, 0.42, Color("c98e69"))
	_cylinder(root, "HairNet", Vector3(0, 2.38, 0), 0.31, 0.16, cap_colour, 0.05, 0.78)
	for side in [-1.0, 1.0]:
		var arm := _cylinder(root, "Arm", Vector3(side * 0.43, 1.5, 0.05), 0.105, 0.78, Color("ecf0e9"), 0.0, 0.82)
		arm.rotation_degrees.z = side * 9.0
	return root

func _machine_root(id: String, display_name: String, at: Vector3, hitbox: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = display_name.replace(" ", "")
	root.position = at
	root.set_meta("machine_id", id)
	root.set_meta("display_name", display_name)
	add_child(root)
	var body := StaticBody3D.new()
	body.name = "SelectionCollider"
	body.collision_layer = 2
	body.collision_mask = 0
	body.set_meta("machine_id", id)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = hitbox
	shape.shape = box_shape
	shape.position.y = hitbox.y * 0.5
	body.add_child(shape)
	root.add_child(body)
	machines[id] = root
	return root

func select_machine(id: String) -> void:
	if not machines.has(id):
		return
	selected_id = id
	selection_marker.global_position = machines[id].global_position + Vector3(0, 0.12, 0)
	selection_marker.scale = Vector3.ONE * (1.25 if id == "dryer" else 0.95)
	machine_selected.emit(id)

func set_preview_mode(enabled: bool) -> void:
	preview_mode = enabled
	_update_state()

func pick_from_screen(camera: Camera3D, screen_position: Vector2) -> String:
	var origin := camera.project_ray_origin(screen_position)
	var end := origin + camera.project_ray_normal(screen_position) * 100.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return ""
	var collider: Object = hit.collider
	if collider.has_meta("machine_id"):
		var id := str(collider.get_meta("machine_id"))
		select_machine(id)
		return id
	return ""

func _update_state() -> void:
	var stage := str(MeatGame.active_batch.get("stage", ""))
	var show_line: bool = preview_mode or MeatGame.starter_line_owned
	for id in machines:
		var root: Node3D = machines[id]
		root.visible = show_line
	selection_marker.visible = show_line
	for id in machine_lights:
		var light: MeshInstance3D = machine_lights[id]
		var active: bool = str(id) == stage or (str(id) == "dryer" and stage == "drying")
		light.material_override = _material(Color("61e58b") if active else Color("68736c"), 0.1, 0.28, Color("42d779") if active else Color.BLACK, 2.2 if active else 0.0)
	var show_meat: bool = stage in ["hanging", "drying", "slicing", "packaging"]
	var dry_progress: float = MeatGame.stage_progress() if stage == "drying" else (1.0 if stage in ["slicing", "packaging"] else 0.0)
	for i in range(meat_strips.size()):
		var meat: MeshInstance3D = meat_strips[i]
		meat.visible = show_meat
		var wet := Color("a64b3b")
		var dry := Color("4b211b")
		meat.material_override = _material(wet.lerp(dry, dry_progress), 0.0, 0.82 + dry_progress * 0.14)

func _on_stage_changed(_stage: String) -> void:
	_update_state()

func _zone(position: Vector3, size: Vector3, colour: Color) -> void:
	_box(self, "HygieneZone", position, size, colour, 0.0, 0.9)

func _add_light_fixture(at: Vector3) -> void:
	_box(self, "LightBody", at, Vector3(2.7, 0.14, 0.42), DARK_STEEL, 0.5, 0.25)
	_box(self, "LightPanel", at - Vector3(0, 0.09, 0), Vector3(2.42, 0.04, 0.26), Color("fff2cf"), 0.0, 0.2, false, Color("ffe3a0"), 2.4)
	var light := OmniLight3D.new()
	light.position = at - Vector3(0, 0.32, 0)
	light.light_color = Color("ffe7bd")
	light.light_energy = 0.65
	light.omni_range = 7.5
	light.shadow_enabled = false
	add_child(light)

func _add_machine_panel(parent: Node3D, at: Vector3, label_text: String) -> void:
	_box(parent, "ControlPanel", at, Vector3(0.95, 0.62, 0.14), Color("27353a"), 0.55, 0.27)
	_box(parent, "Display", at + Vector3(0, 0.08, -0.08), Vector3(0.62, 0.24, 0.035), Color("5da9a1"), 0.05, 0.22, false, Color("4fb8ae"), 0.9)
	_light(parent, at + Vector3(0.34, -0.17, -0.09), Color("e9a83e"))
	var label := Label3D.new()
	label.text = label_text
	label.font = load("res://assets/Heading.ttf")
	label.font_size = 26
	label.modulate = Color("e6f4e8")
	label.outline_size = 2
	label.pixel_size = 0.0037
	label.position = at + Vector3(0, 0.08, -0.105)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)

func _floor_label(text: String, at: Vector3, colour: Color, parent: Node3D = self) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = load("res://assets/Heading.ttf")
	label.font_size = 32
	label.modulate = colour
	label.pixel_size = 0.008
	label.position = at
	label.rotation_degrees = Vector3(-90, 0, 0)
	parent.add_child(label)

func _light(parent: Node3D, at: Vector3, colour: Color) -> MeshInstance3D:
	return _cylinder(parent, "Indicator", at, 0.075, 0.045, colour, 0.1, 0.25, Vector3(90, 0, 0), colour, 1.8)

func _box(parent: Node3D, node_name: String, at: Vector3, size: Vector3, colour: Color,
		metallic := 0.0, roughness := 0.7, transparent := false,
		emission := Color.BLACK, emission_energy := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _material(colour, metallic, roughness, emission, emission_energy, transparent)
	parent.add_child(node)
	return node

func _cylinder(parent: Node3D, node_name: String, at: Vector3, radius: float, height: float,
		colour: Color, metallic := 0.0, roughness := 0.7, rotation := Vector3.ZERO,
		emission := Color.BLACK, emission_energy := 0.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(colour, metallic, roughness, emission, emission_energy)
	parent.add_child(node)
	return node

func _torus(parent: Node3D, at: Vector3, radius: float, thickness: float, colour: Color,
		rotation := Vector3.ZERO, arc := 360.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius
	mesh.rings = 16
	mesh.ring_segments = 8
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation
	node.material_override = _material(colour, 0.75, 0.2)
	parent.add_child(node)
	return node

func _pipe(from: Vector3, to: Vector3, radius: float, colour: Color, parent: Node3D = self) -> MeshInstance3D:
	var midpoint := (from + to) * 0.5
	if parent != self:
		midpoint = parent.to_local(midpoint)
	var length := from.distance_to(to)
	var node := _cylinder(parent, "UtilityPipe", midpoint, radius, length, colour, 0.8, 0.18)
	var direction := to - from
	node.quaternion = Quaternion(Vector3.UP, direction.normalized())
	return node

func _material(colour: Color, metallic := 0.0, roughness := 0.7,
		emission := Color.BLACK, emission_energy := 0.0, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	if transparent or colour.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material

func _meat_mesh(seed: int, dryness: float) -> ArrayMesh:
	# Tapered, twisted strip with an irregular silhouette; deterministic per hook.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 7
	var vertices: Array[Vector3] = []
	for ring in range(rings):
		var t := float(ring) / float(rings - 1)
		var width := (0.23 - t * 0.07) * (0.9 + sin(seed * 2.1 + ring) * 0.09)
		var depth := (0.085 - t * 0.02) * (1.0 - dryness * 0.18)
		var xoff := sin(t * 4.8 + seed) * 0.06
		var zoff := sin(t * 7.0 + seed * 0.7) * 0.035
		var y := -t * (1.25 + fmod(seed * 0.11, 0.24))
		vertices.append(Vector3(xoff - width, y, zoff - depth))
		vertices.append(Vector3(xoff + width, y, zoff - depth))
		vertices.append(Vector3(xoff + width, y, zoff + depth))
		vertices.append(Vector3(xoff - width, y, zoff + depth))
	for ring in range(rings - 1):
		for side in range(4):
			var a := ring * 4 + side
			var b := ring * 4 + (side + 1) % 4
			var c := (ring + 1) * 4 + (side + 1) % 4
			var d := (ring + 1) * 4 + side
			for index in [a, b, c, a, c, d]:
				surface.set_uv(Vector2(float(side) / 4.0, float(ring) / rings))
				surface.add_vertex(vertices[index])
	for index in [0, 2, 1, 0, 3, 2]:
		surface.add_vertex(vertices[index])
	var end := (rings - 1) * 4
	for index in [end, end + 1, end + 2, end, end + 2, end + 3]:
		surface.add_vertex(vertices[index])
	surface.generate_normals()
	return surface.commit()
