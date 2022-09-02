extends Node

const Util := preload("util.gd")

var _sections := {}


class SectionCache:
	signal changed(key)

	var _section: String
	var _keys := {}

	func _init(p_section: String):
		self._section = p_section

	# store(key: String, value: Any) -> void:
	# Stores `value` into the `key`
	# @param key (String): The name of the key.
	# @param value (Any): The value to store.
	func store(key: String, value):
		if _keys.has(key) and _keys[key] == value:
			return

		EZStorage.store(_section, key, value)
		_keys[key] = value
		emit_signal("changed", key)

	# fetch(key: String, default: Any = null, cache_default: bool = false) -> Any:
	# Fetches values from the `key` of `section`.
	# @param key (String): The name of the key.
	# @param default (Any): The value returned if key/section does not exist.
	# @param cache_default (bool): Forces the `default` to be cached in memory
	#                              to skip the file system in future calls.
	#                              This does not modify the file system.
	# @return value (Any): The result or `default` if none found.
	func fetch(key: String, default = null, cache_default := false):
		if _keys.has(key):
			return _keys[key]

		var result = EZStorage.fetch(_section, key, default)
		if result != default or cache_default:
			_keys[key] = result
		return result

	# purge_key(key: String) -> bool
	# Removes a key from the cache and file system.
	# @param key (String): The keys to delete.
	# @return all_success (bool): All purging was a success.
	func purge_key(key: String) -> bool:
		var success := EZStorage.purge_section_key(_section, key)
		if _keys.erase(key) and success:
			emit_signal("changed", key)
		return success

	# purge(skip_keys: PoolStringArray = []) -> bool
	# Remove keys from the cache and file system.
	# @param skip_keys (PoolStringArray): The keys to keep.
	# @return all_success (bool): All purging was a success.
	func purge(skip_keys: PoolStringArray = []) -> bool:
		for key in _keys.keys():
			if not key in skip_keys:
				var success = EZStorage.purge_section_key(_section, key)
				if _keys.erase(key) and success:
					emit_signal("changed", key)
		return EZStorage.purge_section(_section, skip_keys)


# get_section(section: String) -> SectionCache
# Get a section from the cache.
# @param section (String): The name of the section to fetch.
# @return cache (SectionCache): A new or existing cache for that section.
func get_section(section: String) -> SectionCache:
	if _sections.has(section):
		return _sections[section]

	var cache := SectionCache.new(section)
	_sections[section] = cache
	return cache


# purge(skip_sections: PoolStringArray = []) -> bool
# Remove sections from the cache and file system.
# @param skip_sections (PoolStringArray): The sections to prevent deletion.
# @return all_success (bool): All purging was a success.
func purge(skip_sections: PoolStringArray = []) -> bool:
	for section in _sections.keys():
		if not section in skip_sections:
			_sections[section].purge()
			_sections.erase(section)
	return EZStorage.purge(skip_sections)
