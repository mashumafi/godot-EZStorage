extends Reference


const Settings := preload("settings.gd")


var root : String setget set_root, get_root


func _init():
	root = Settings.get_directory()


func set_root(path: String, copy := false) -> void:
	if copy:
		_copy_to(root, path)
	root = path


func get_root() -> String:
	return root


func _copy_to(src: String, dst: String):
	pass


func _create_section(_section: String):
	pass


func _store(_section: String, _key: String, _value):
	pass


func _fetch(_section: String, _key: String, _default = null):
	return _default


func _purge(_section := "", _key := "") -> bool:
	return false


func _get_sections() -> PoolStringArray:
	return PoolStringArray()


func _get_keys(_section: String) -> PoolStringArray:
	return PoolStringArray()
