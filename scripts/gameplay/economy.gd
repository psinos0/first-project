class_name WorkshopEconomy
extends RefCounted
## Pure, configurable economy calculations. No UI, timers, files or SDKs.

var config: Dictionary

func _init(data: Dictionary) -> void:
	config = data

func duration(index: int, levels: Array[int]) -> float:
	var base := float(config.stages[index].seconds)
	return base * pow(float(config.speed_factor), levels[index] - 1) if index < 3 else base

func units(levels: Array[int]) -> int:
	return int(config.base_units) + (levels[0] - 1) * int(config.capacity_per_level)

func revenue(levels: Array[int]) -> int:
	return int(config.base_revenue) + (levels[0] - 1) * int(config.revenue_per_capacity_level) + (levels[2] - 1) * int(config.revenue_per_packaging_level)

func upgrade_cost(index: int, levels: Array[int]) -> int:
	return roundi(float(config.stages[index].upgrade_cost) * pow(float(config.upgrade_cost_factor), levels[index] - 1))

func rank_index(earned: int) -> int:
	var rank := 0
	for i in range(config.ranks.size()):
		if earned >= int(config.ranks[i].earned):
			rank = i
	return rank
