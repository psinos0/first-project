class_name WorkforceSystem
extends RefCounted
## Deterministic workforce, task and payroll model. MeatGame applies all cash/inventory effects.

var employees: Array[Dictionary] = []
var tasks: Array[Dictionary] = []
var payroll_history: Array[Dictionary] = []
var payroll_debt := 0.0
var last_payroll_period := 0
var employee_sequence := 0
var task_sequence := 0
var config: Dictionary = {}
var _worked_this_tick: Dictionary = {}

func reset(workforce_config: Dictionary, absolute_minute: float) -> void:
	config = workforce_config
	employees.clear()
	tasks.clear()
	payroll_history.clear()
	payroll_debt = 0.0
	last_payroll_period = floori(absolute_minute / float(config.pay_period_minutes))
	employee_sequence = 0
	task_sequence = 0
	_worked_this_tick.clear()

func seed_starter_crew() -> void:
	if not employees.is_empty():
		return
	for role_id in config.get("starter_roles", []):
		_create_employee(str(role_id), true)

func hire(role_id: String) -> Dictionary:
	if not config.roles.has(role_id) or employees.size() >= int(config.max_employees):
		return {"ok": false, "reason": "unavailable"}
	var role: Dictionary = config.roles[role_id]
	var employee := _create_employee(role_id, false)
	return {"ok": true, "cost": float(role.hire_cost), "employee": employee}

func dismiss(employee_id: String) -> bool:
	for index in range(employees.size()):
		var employee := employees[index]
		if str(employee.employee_id) != employee_id:
			continue
		if not str(employee.current_task_id).is_empty():
			return false
		employees.remove_at(index)
		return true
	return false

func assign_machine(employee_id: String, machine_id: String) -> bool:
	var employee := get_employee(employee_id)
	if employee.is_empty() or not str(employee.current_task_id).is_empty():
		return false
	employee.assigned_machine_id = machine_id
	return true

func create_task(task_type: String, required_role: String, machine_id: String, batch_id: String,
		duration: float, priority := 50) -> String:
	for existing in tasks:
		if str(existing.task_type) == task_type and str(existing.batch_id) == batch_id and str(existing.machine_id) == machine_id and str(existing.state) in ["waiting", "assigned", "working"]:
			return str(existing.task_id)
	task_sequence += 1
	var task: Dictionary = {
		"task_id": "TASK-%04d" % task_sequence,
		"task_type": task_type,
		"required_role": required_role,
		"machine_id": machine_id,
		"batch_id": batch_id,
		"priority": priority,
		"duration": maxf(1.0, duration),
		"remaining": maxf(1.0, duration),
		"assigned_employee_id": "",
		"state": "waiting",
		"completion_applied": false
	}
	tasks.append(task)
	_assign_task(task)
	return str(task.task_id)

func complete_instant_task(task_type: String, required_role: String, machine_id: String, batch_id: String) -> bool:
	var id := create_task(task_type, required_role, machine_id, batch_id, 1.0, 90)
	var task := get_task(id)
	if task.is_empty() or str(task.assigned_employee_id).is_empty():
		return false
	advance_task(id, 1.0)
	return str(task.state) == "completed"

func advance_task(task_id: String, minutes: float) -> Dictionary:
	var task := get_task(task_id)
	if task.is_empty() or str(task.state) == "completed":
		return {"used": 0.0, "completed": str(task.get("state", "")) == "completed"}
	if str(task.assigned_employee_id).is_empty():
		_assign_task(task)
	if str(task.assigned_employee_id).is_empty():
		task.state = "waiting"
		return {"used": 0.0, "completed": false}
	task.state = "working"
	var used := minf(maxf(0.0, minutes), float(task.remaining))
	task.remaining = maxf(0.0, float(task.remaining) - used)
	var employee := get_employee(str(task.assigned_employee_id))
	if not employee.is_empty():
		_worked_this_tick[employee.employee_id] = float(_worked_this_tick.get(employee.employee_id, 0.0)) + used
		employee.fatigue = minf(100.0, float(employee.fatigue) + used / 60.0 * float(config.fatigue_per_work_hour))
		employee.experience = float(employee.experience) + used / 60.0
		employee.skill_level = minf(5.0, 1.0 + float(employee.experience) / 80.0)
		employee.efficiency = clampf(1.0 + (float(employee.skill_level) - 1.0) * 0.04 - float(employee.fatigue) * 0.003, 0.65, 1.25)
	if float(task.remaining) <= 0.0001:
		task.remaining = 0.0
		task.state = "completed"
		if not employee.is_empty():
			employee.current_task_id = ""
			employee.task_state = "available"
		return {"used": used, "completed": true, "task": task}
	return {"used": used, "completed": false, "task": task}

func begin_tick() -> void:
	_worked_this_tick.clear()

func end_tick(total_minutes: float) -> void:
	for employee in employees:
		var worked := float(_worked_this_tick.get(employee.employee_id, 0.0))
		var recovery_minutes := maxf(0.0, total_minutes - worked)
		employee.fatigue = maxf(0.0, float(employee.fatigue) - recovery_minutes / 60.0 * float(config.recovery_per_idle_hour))
		employee.efficiency = clampf(1.0 + (float(employee.skill_level) - 1.0) * 0.04 - float(employee.fatigue) * 0.003, 0.65, 1.25)

func process_payroll(absolute_minute: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var current_period := floori(absolute_minute / float(config.pay_period_minutes))
	while last_payroll_period < current_period:
		last_payroll_period += 1
		var due := payroll_debt
		for employee in employees:
			if str(employee.employment_status) == "employed":
				due += float(employee.wage_rate)
				employee.last_payroll_period = last_payroll_period
		var event := {"period": last_payroll_period, "due": snappedf(due, 0.01), "employee_count": employees.size()}
		payroll_history.push_front(event)
		if payroll_history.size() > 30:
			payroll_history.resize(30)
		events.append(event)
	return events

func settle_payroll(event: Dictionary, paid: float) -> void:
	payroll_debt = maxf(0.0, float(event.due) - paid)
	if payroll_debt > 0.0:
		for employee in employees:
			employee.morale = maxf(20.0, float(employee.morale) - 8.0)

func has_available_role(role_id: String) -> bool:
	for employee in employees:
		if str(employee.role_id) == role_id and str(employee.current_task_id).is_empty() and str(employee.employment_status) == "employed":
			return true
	return false

func get_employee(employee_id: String) -> Dictionary:
	for employee in employees:
		if str(employee.employee_id) == employee_id:
			return employee
	return {}

func get_task(task_id: String) -> Dictionary:
	for task in tasks:
		if str(task.task_id) == task_id:
			return task
	return {}

func active_tasks() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for task in tasks:
		if str(task.state) in ["waiting", "assigned", "working", "blocked"]:
			result.append(task)
	return result

func snapshot() -> Dictionary:
	return {
		"employees": employees.duplicate(true), "tasks": tasks.duplicate(true),
		"payroll_history": payroll_history.duplicate(true), "payroll_debt": payroll_debt,
		"last_payroll_period": last_payroll_period, "employee_sequence": employee_sequence,
		"task_sequence": task_sequence
	}

func restore(data: Dictionary, workforce_config: Dictionary, absolute_minute: float) -> void:
	reset(workforce_config, absolute_minute)
	var seen: Dictionary = {}
	for item in data.get("employees", []):
		if item is Dictionary:
			var employee: Dictionary = item.duplicate(true)
			var id := str(employee.get("employee_id", ""))
			var role := str(employee.get("role_id", ""))
			if id.is_empty() or seen.has(id) or not config.roles.has(role):
				continue
			seen[id] = true
			employee.fatigue = clampf(float(employee.get("fatigue", 0.0)), 0.0, 100.0)
			employee.morale = clampf(float(employee.get("morale", 85.0)), 0.0, 100.0)
			employee.current_task_id = str(employee.get("current_task_id", ""))
			employees.append(employee)
	for item in data.get("tasks", []):
		if item is Dictionary and str(item.get("state", "")) in ["waiting", "assigned", "working", "blocked", "completed"]:
			tasks.append(item.duplicate(true))
	for item in data.get("payroll_history", []):
		if item is Dictionary:
			payroll_history.append(item.duplicate(true))
	payroll_debt = maxf(0.0, float(data.get("payroll_debt", 0.0)))
	last_payroll_period = maxi(0, int(data.get("last_payroll_period", last_payroll_period)))
	employee_sequence = maxi(employees.size(), int(data.get("employee_sequence", employees.size())))
	task_sequence = maxi(tasks.size(), int(data.get("task_sequence", tasks.size())))

func _create_employee(role_id: String, starter: bool) -> Dictionary:
	employee_sequence += 1
	var role: Dictionary = config.roles[role_id]
	var names: Array = config.names
	var employee := {
		"employee_id": "EMP-%03d" % employee_sequence,
		"display_name": str(names[(employee_sequence - 1) % names.size()]),
		"role_id": role_id,
		"skill_level": 1.0,
		"experience": 0.0,
		"efficiency": 1.0,
		"fatigue": 0.0,
		"morale": 90.0 if starter else 82.0,
		"employment_status": "employed",
		"assigned_machine_id": "",
		"current_task_id": "",
		"task_state": "available",
		"shift_start": int(role.get("shift_start", 0)),
		"shift_end": int(role.get("shift_end", 1440)),
		"wage_rate": float(role.daily_wage),
		"last_payroll_period": last_payroll_period,
		"training_status": "trained" if starter else "orientation"
	}
	employees.append(employee)
	return employee

func _assign_task(task: Dictionary) -> void:
	var candidates: Array[Dictionary] = []
	for employee in employees:
		if str(employee.role_id) == str(task.required_role) and str(employee.employment_status) == "employed" and str(employee.current_task_id).is_empty():
			candidates.append(employee)
	if candidates.is_empty():
		task.state = "waiting"
		return
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.efficiency) > float(b.efficiency))
	var selected: Dictionary = candidates[0]
	task.assigned_employee_id = selected.employee_id
	task.state = "assigned"
	selected.current_task_id = task.task_id
	selected.task_state = task.task_type
