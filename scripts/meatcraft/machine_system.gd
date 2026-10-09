class_name MachineSystem
extends RefCounted
## Individual equipment state, deterministic wear, faults, parts and repair history.

var records: Dictionary = {}
var spare_parts: Dictionary = {}
var repair_history: Array[Dictionary] = []
var config: Dictionary = {}
var fault_sequence := 0

func reset(machine_config: Dictionary) -> void:
	config = machine_config
	records.clear()
	spare_parts = config.starting_parts.duplicate(true)
	repair_history.clear()
	fault_sequence = 0
	for machine_id in config.records:
		var definition: Dictionary = config.records[machine_id]
		records[machine_id] = {
			"machine_id": machine_id,
			"machine_type": str(definition.type),
			"display_name": str(definition.name),
			"condition": 100.0,
			"wear": 0.0,
			"operating_status": "idle",
			"running_hours": 0.0,
			"maintenance_interval": float(definition.maintenance_interval),
			"last_service_hours": 0.0,
			"fault_state": {},
			"required_spare_part": "",
			"assigned_operator": "",
			"installed_upgrade_level": 1,
			"repair_task_id": ""
		}

func machine_for_stage(stage: String) -> String:
	return str(config.stage_machine.get(stage, ""))

func can_operate(machine_id: String) -> bool:
	if machine_id.is_empty() or not records.has(machine_id):
		return true
	return str(records[machine_id].operating_status) not in ["broken", "waiting_for_technician", "under_repair"]

func advance_operation(machine_id: String, minutes: float) -> void:
	if machine_id.is_empty() or not records.has(machine_id) or not can_operate(machine_id):
		return
	var record: Dictionary = records[machine_id]
	var hours := maxf(0.0, minutes) / 60.0
	record.operating_status = "processing"
	record.running_hours = float(record.running_hours) + hours
	record.wear = minf(100.0, float(record.wear) + hours * float(config.wear_per_hour))
	record.condition = maxf(0.0, 100.0 - float(record.wear))
	if float(record.condition) < float(config.service_warning_condition):
		record.operating_status = "maintenance_recommended"
	# Automatic failures are bounded and deterministic. Explicit test faults remain injectable.
	if float(record.condition) <= float(config.automatic_fault_condition) and str(record.operating_status) != "broken":
		var threshold := int(float(record.running_hours) / 12.0)
		if threshold > int(record.get("last_fault_threshold", -1)):
			record.last_fault_threshold = threshold
			trigger_fault(machine_id, "wear_fault")

func mark_idle(machine_id: String) -> void:
	if records.has(machine_id) and can_operate(machine_id):
		records[machine_id].operating_status = "idle"

func trigger_fault(machine_id: String, fault_type: String = "test_fault") -> bool:
	if not records.has(machine_id):
		return false
	var record: Dictionary = records[machine_id]
	if not Dictionary(record.fault_state).is_empty():
		return false
	fault_sequence += 1
	var definition: Dictionary = config.faults.get(fault_type, config.faults.test_fault)
	record.fault_state = {
		"fault_id": "FAULT-%03d" % fault_sequence,
		"type": fault_type,
		"description": str(definition.description),
		"severity": str(definition.severity),
		"repair_cost": float(definition.repair_cost),
		"part": str(definition.part)
	}
	record.required_spare_part = str(definition.part)
	record.operating_status = "broken"
	record.condition = minf(float(record.condition), 45.0)
	return true

func repair_requirements(machine_id: String) -> Dictionary:
	if not records.has(machine_id):
		return {}
	var record: Dictionary = records[machine_id]
	if Dictionary(record.fault_state).is_empty():
		return {}
	return {
		"cost": float(record.fault_state.repair_cost),
		"part": str(record.required_spare_part),
		"duration": float(config.repair_duration),
		"part_available": int(spare_parts.get(str(record.required_spare_part), 0)) > 0
	}

func begin_repair(machine_id: String, task_id: String) -> bool:
	var requirements := repair_requirements(machine_id)
	if requirements.is_empty() or not bool(requirements.part_available):
		return false
	spare_parts[requirements.part] = int(spare_parts[requirements.part]) - 1
	records[machine_id].operating_status = "under_repair"
	records[machine_id].repair_task_id = task_id
	return true

func complete_repair(machine_id: String, day: int, minute: float) -> bool:
	if not records.has(machine_id) or str(records[machine_id].operating_status) != "under_repair":
		return false
	var record: Dictionary = records[machine_id]
	var old_fault: Dictionary = Dictionary(record.fault_state).duplicate(true)
	record.fault_state = {}
	record.required_spare_part = ""
	record.repair_task_id = ""
	record.wear = maxf(0.0, float(record.wear) - 45.0)
	record.condition = 100.0 - float(record.wear)
	record.operating_status = "idle"
	repair_history.push_front({"machine_id": machine_id, "fault": old_fault, "day": day, "minute": minute, "result": "repaired"})
	if repair_history.size() > 40:
		repair_history.resize(40)
	return true

func preventive_service(machine_id: String) -> bool:
	if not records.has(machine_id) or not can_operate(machine_id):
		return false
	var record: Dictionary = records[machine_id]
	if float(record.condition) >= 99.0:
		return false
	record.wear = maxf(0.0, float(record.wear) - 35.0)
	record.condition = 100.0 - float(record.wear)
	record.last_service_hours = float(record.running_hours)
	record.operating_status = "idle"
	return true

func restock_parts() -> void:
	for part in config.restock_bundle:
		spare_parts[part] = int(spare_parts.get(part, 0)) + int(config.restock_bundle[part])

func status(machine_id: String) -> String:
	return str(records.get(machine_id, {}).get("operating_status", "unavailable"))

func condition(machine_id: String) -> float:
	return float(records.get(machine_id, {}).get("condition", 0.0))

func snapshot() -> Dictionary:
	return {
		"records": records.duplicate(true), "spare_parts": spare_parts.duplicate(true),
		"repair_history": repair_history.duplicate(true), "fault_sequence": fault_sequence
	}

func restore(data: Dictionary, machine_config: Dictionary) -> void:
	reset(machine_config)
	for machine_id in data.get("records", {}):
		if records.has(machine_id) and data.records[machine_id] is Dictionary:
			var source: Dictionary = data.records[machine_id]
			var record: Dictionary = records[machine_id]
			for key in source:
				record[key] = source[key]
			record.condition = clampf(float(record.condition), 0.0, 100.0)
			record.wear = clampf(float(record.wear), 0.0, 100.0)
	spare_parts = data.get("spare_parts", config.starting_parts).duplicate(true)
	repair_history.clear()
	for item in data.get("repair_history", []):
		if item is Dictionary:
			repair_history.append(item.duplicate(true))
	fault_sequence = maxi(0, int(data.get("fault_sequence", 0)))
