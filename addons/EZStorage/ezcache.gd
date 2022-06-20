extends Node

var _sections := {}


class SectionCache:
	signal changed(key)

	var _section: String
	var _keys := {}

	func _init(p_section: String):
		self._section = p_section
		EZStorage.create_section(p_section)

	func store(key: String, value):
		if _keys.has(key) and _keys[key] == value:
			return

		EZStorage.store(_section, key, value)
		_keys[key] = value
		emit_signal("changed", key)

	func fetch(key: String, default = null, cache_default := false):
		if _keys.has(key):
			return _keys[key]

		var result = EZStorage.fetch(_section, key, default)
		if result != default or cache_default:
			_keys[key] = result
		return result

	func purge(skip_keys: PoolStringArray = [], scan_files := true) -> bool:
		var all_success := true
		var keys: PoolStringArray
		if scan_files:
			keys = EZStorage.get_keys(_section)
		else:
			keys = _keys.keys()
		for key in keys:
			if not key in skip_keys:
				var success := EZStorage.purge(_section, key)
				all_success = all_success && success
				if success and _keys.erase(key):
					emit_signal("changed", key)
		return all_success


func get_section(section: String) -> SectionCache:
	if _sections.has(section):
		return _sections[section]

	var cache := SectionCache.new(section)
	_sections[section] = cache
	return cache


func purge(skip_sections: PoolStringArray = [], scan_files := true) -> void:
	var sections: PoolStringArray
	if scan_files:
		sections = EZStorage.get_sections()
	else:
		sections = _sections.keys()

	for section in sections:
		if not section in skip_sections:
			if _sections.has(section):
				_sections[section].purge([], scan_files)
				_sections.erase(section)
			else:
				EZStorage.purge(section)
