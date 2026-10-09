class_name ContractSystem
extends RefCounted
## Customer demand and contract lifecycle. MeatGame owns inventory and cash settlement.

var orders: Array[Dictionary] = []
var completed_orders: Array[Dictionary] = []
var order_sequence := 0
var config: Dictionary = {}

func reset(contract_config: Dictionary, absolute_minute: float) -> void:
	config = contract_config
	orders.clear()
	completed_orders.clear()
	order_sequence = 0
	for template_id in config.templates:
		_create_order(template_id, absolute_minute)

func accept_order(order_id: String) -> bool:
	var order := get_order(order_id)
	if order.is_empty() or str(order.status) != "available":
		return false
	order.status = "accepted"
	return true

func ready_orders(recipe_id: String, available_packs: int, quality: float, absolute_minute: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for order in orders:
		if str(order.recipe_id) == recipe_id and str(order.status) in ["accepted", "in_production", "ready_for_dispatch"]:
			if available_packs >= int(order.quantity) and quality >= float(order.required_quality) and absolute_minute <= float(order.deadline):
				order.status = "ready_for_dispatch"
				result.append(order)
	return result

func complete_order(order_id: String, absolute_minute: float) -> Dictionary:
	var order := get_order(order_id)
	if order.is_empty() or str(order.status) != "ready_for_dispatch":
		return {"ok": false}
	order.status = "completed"
	order.completed_at = absolute_minute
	var reward := int(order.quantity) * float(order.unit_price)
	var result := order.duplicate(true)
	result.reward = reward
	completed_orders.push_front(result)
	return {"ok": true, "reward": reward, "order": order}

func update_deadlines(absolute_minute: float) -> Array[Dictionary]:
	var failed: Array[Dictionary] = []
	for order in orders:
		if str(order.status) in ["accepted", "in_production", "ready_for_dispatch"] and absolute_minute > float(order.deadline):
			order.status = "failed"
			failed.append(order)
	return failed

func get_order(order_id: String) -> Dictionary:
	for order in orders:
		if str(order.order_id) == order_id:
			return order
	return {}

func snapshot() -> Dictionary:
	return {"orders": orders.duplicate(true), "completed_orders": completed_orders.duplicate(true), "order_sequence": order_sequence}

func restore(data: Dictionary, contract_config: Dictionary, absolute_minute: float) -> void:
	config = contract_config
	orders.clear()
	completed_orders.clear()
	for item in data.get("orders", []):
		if item is Dictionary:
			orders.append(item.duplicate(true))
	for item in data.get("completed_orders", []):
		if item is Dictionary:
			completed_orders.append(item.duplicate(true))
	order_sequence = maxi(orders.size(), int(data.get("order_sequence", orders.size())))
	if orders.is_empty():
		reset(contract_config, absolute_minute)

func _create_order(template_id: String, absolute_minute: float) -> void:
	order_sequence += 1
	var template: Dictionary = config.templates[template_id]
	orders.append({
		"order_id": "ORD-%03d" % order_sequence,
		"template_id": template_id,
		"customer": str(template.customer),
		"recipe_id": str(template.recipe_id),
		"quantity": int(template.quantity),
		"unit_price": float(template.unit_price),
		"deadline": absolute_minute + float(template.deadline_minutes),
		"required_quality": float(template.required_quality),
		"penalty": float(template.penalty),
		"status": "available"
	})
