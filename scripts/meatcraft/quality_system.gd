class_name QualitySystem
extends RefCounted
## Fictional HACCP-inspired incidents, holds, corrective actions and bounded traceability.

var incidents: Array[Dictionary] = []
var batch_history: Array[Dictionary] = []
var inspection_history: Array[Dictionary] = []
var held_batches: Dictionary = {}
var incident_sequence := 0
var config: Dictionary = {}

func reset(quality_config: Dictionary) -> void:
	config = quality_config
	incidents.clear()
	batch_history.clear()
	inspection_history.clear()
	held_batches.clear()
	incident_sequence = 0

func trigger_incident(incident_type: String, batch_id: String, machine_id: String, day: int, minute: float) -> Dictionary:
	if not config.incidents.has(incident_type):
		return {}
	incident_sequence += 1
	var definition: Dictionary = config.incidents[incident_type]
	var incident := {
		"incident_id": "QI-%03d" % incident_sequence,
		"type": incident_type,
		"severity": str(definition.severity),
		"related_equipment": machine_id,
		"related_batch": batch_id,
		"day": day,
		"minute": minute,
		"description": str(definition.description),
		"status": "open",
		"required_action": str(definition.action),
		"responsible_worker": "",
		"resolution_result": "",
		"task_id": ""
	}
	incidents.push_front(incident)
	if incidents.size() > 40:
		incidents.resize(40)
	if bool(definition.hold_batch) and not batch_id.is_empty():
		held_batches[batch_id] = true
	return incident

func begin_corrective_action(incident_id: String, worker_id: String, task_id: String) -> bool:
	var incident := get_incident(incident_id)
	if incident.is_empty() or str(incident.status) not in ["open", "under_investigation"]:
		return false
	incident.status = "corrective_action_assigned"
	incident.responsible_worker = worker_id
	incident.task_id = task_id
	return true

func complete_corrective_action(incident_id: String, action: String) -> Dictionary:
	var incident := get_incident(incident_id)
	if incident.is_empty() or str(incident.status) != "corrective_action_assigned":
		return {"ok": false}
	var required := str(incident.required_action)
	if required == "reject" and action != "reject":
		return {"ok": false, "reason": "rejection_required"}
	if action not in [required, "reject"]:
		return {"ok": false, "reason": "wrong_action"}
	incident.status = "resolved"
	incident.resolution_result = action
	var batch_id := str(incident.related_batch)
	if not batch_id.is_empty():
		held_batches.erase(batch_id)
	return {"ok": true, "batch_id": batch_id, "rejected": action == "reject"}

func record_inspection(batch_id: String, employee_id: String, result: String, day: int, minute: float) -> void:
	inspection_history.push_front({
		"batch_id": batch_id, "employee_id": employee_id, "result": result,
		"day": day, "minute": minute
	})
	if inspection_history.size() > 40:
		inspection_history.resize(40)

func record_completed_batch(record: Dictionary) -> void:
	batch_history.push_front(record.duplicate(true))
	if batch_history.size() > 50:
		batch_history.resize(50)

func mark_dispatched(batch_id: String, order_id: String, day: int, minute: float) -> void:
	for record in batch_history:
		if str(record.get("batch_id", "")) == batch_id:
			record.dispatch_order_id = order_id
			record.dispatch_day = day
			record.dispatch_minute = minute
			record.quality_status = "dispatched"

func is_batch_held(batch_id: String) -> bool:
	return bool(held_batches.get(batch_id, false))

func has_held_finished_recipe(recipe_id: String) -> bool:
	for record in batch_history:
		if str(record.get("recipe_id", "")) == recipe_id and is_batch_held(str(record.get("batch_id", ""))) and int(record.get("remaining_packs", 0)) > 0:
			return true
	return false

func consume_finished(recipe_id: String, amount: int, order_id: String, day: int, minute: float) -> Array[String]:
	var remaining := amount
	var used_batches: Array[String] = []
	for record in batch_history:
		if remaining <= 0:
			break
		if str(record.get("recipe_id", "")) != recipe_id or is_batch_held(str(record.get("batch_id", ""))):
			continue
		var available := int(record.get("remaining_packs", 0))
		var used := mini(available, remaining)
		if used <= 0:
			continue
		record.remaining_packs = available - used
		remaining -= used
		used_batches.append(str(record.batch_id))
		if int(record.remaining_packs) == 0:
			mark_dispatched(str(record.batch_id), order_id, day, minute)
	return used_batches

func get_incident(incident_id: String) -> Dictionary:
	for incident in incidents:
		if str(incident.incident_id) == incident_id:
			return incident
	return {}

func open_incidents() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for incident in incidents:
		if str(incident.status) not in ["resolved", "closed", "rejected"]:
			result.append(incident)
	return result

func snapshot() -> Dictionary:
	return {
		"incidents": incidents.duplicate(true), "batch_history": batch_history.duplicate(true),
		"inspection_history": inspection_history.duplicate(true), "held_batches": held_batches.duplicate(true),
		"incident_sequence": incident_sequence
	}

func restore(data: Dictionary, quality_config: Dictionary) -> void:
	reset(quality_config)
	for item in data.get("incidents", []):
		if item is Dictionary:
			incidents.append(item.duplicate(true))
	for item in data.get("batch_history", []):
		if item is Dictionary:
			batch_history.append(item.duplicate(true))
	for item in data.get("inspection_history", []):
		if item is Dictionary:
			inspection_history.append(item.duplicate(true))
	held_batches = data.get("held_batches", {}).duplicate(true)
	incident_sequence = maxi(incidents.size(), int(data.get("incident_sequence", incidents.size())))
