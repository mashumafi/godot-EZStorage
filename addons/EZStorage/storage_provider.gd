extends Reference

const Settings := preload("settings.gd")

var root: String setget set_root, get_root


func _init():
	root = Settings.get_directory()


func set_root(path: String, copy := false) -> void:
	if copy:
		copy_to(root, path)
	root = path


func get_root() -> String:
	return root


func copy_to(_src: String, _dst: String):
	pass


func store(_section: String, _key: String, _value):
	pass


func fetch(_section: String, _key: String, _default = null):
	return _default


func purge(_skip_sections: PoolStringArray) -> bool:
	return false


func purge_section(_section: String, _skip_keys: PoolStringArray) -> bool:
	return false


func purge_section_key(_section: String, _key: String) -> bool:
	return false
