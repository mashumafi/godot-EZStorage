extends Reference


func create_section(_section: String):
	pass


func store(_section: String, _key: String, _value):
	pass


func fetch(_section: String, _key: String, _default = null):
	return _default


func purge(_section := "", _key := "") -> bool:
	return false


func get_sections() -> PoolStringArray:
	return PoolStringArray()


func get_keys(_section: String) -> PoolStringArray:
	return PoolStringArray()
