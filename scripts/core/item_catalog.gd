class_name ItemCatalog
extends Resource
## Lista ordenada de tipos de objeto de una sala. El orden define el orden
## de las filas de estantería (de arriba abajo).

@export var items: Array[ItemData] = []


func find_by_key(sort_key: StringName) -> ItemData:
	for data in items:
		if data.sort_key == sort_key:
			return data
	return null
