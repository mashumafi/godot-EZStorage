extends Reference


func create_section(section: String):
	pass


func store(section: String, key: String, value):
	pass


func fetch(section: String, key: String, default = null):
	return default


func purge(section := "", key := "") -> bool:
	return false


func get_sections() -> PoolStringArray:
	return PoolStringArray()


func get_keys(section: String) -> PoolStringArray:
	return PoolStringArray()
