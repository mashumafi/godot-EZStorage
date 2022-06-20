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


	# purge(skip_keys: PoolStringArray = []) -> bool
	# Remove keys from the cache and file system
	# @param skip_keys (PoolStringArray): the keys to prevent deletion
	# @return all_success (bool): all purging was a success
	func purge(skip_keys: PoolStringArray = []) -> bool:
		var all_success := true
		for key in EZStorage.get_keys(_section):
			if not key in skip_keys:
				var success := EZStorage.purge(_section, key)
				all_success = all_success && success
				if success and _keys.erase(key):
					emit_signal("changed", key)
		return all_success


# get_section(section: String) -> SectionCache
# Get a section from the cache
# @param section (String): name of the section to fetch
# @return cache (SectionCache): a new or existing cache for that section
func get_section(section: String) -> SectionCache:
	if _sections.has(section):
		return _sections[section]

	var cache := SectionCache.new(section)
	_sections[section] = cache
	return cache


# purge(skip_sections: PoolStringArray = []) -> bool
# Remove sections from the cache and file system
# @param skip_sections (PoolStringArray): the sections to prevent deletion
# @return all_success (bool): all purging was a success
func purge(skip_sections: PoolStringArray = []) -> bool:
	var all_success := true
	for section in EZStorage.get_sections():
		if not section in skip_sections:
			if _sections.has(section):
				all_success = _sections[section].purge() && all_success
				all_success = EZStorage.purge(section) && all_success
				all_success = _sections.erase(section) && all_success
			else:
				all_success = EZStorage.purge(section) && all_success
	return all_success
