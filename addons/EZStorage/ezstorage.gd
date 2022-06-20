extends Node

const Settings := preload("settings.gd")

var provider := FileProvider.new()


class FileProvider:
	const REPLICATION := 2

	var root: String

	func _init() -> void:
		root = Settings.get_directory()

	func _hash(s: String) -> String:
		if OS.is_debug_build() and Settings.get_debug_filenames():
			return s.http_escape()
		return s.sha256_text()

	func create_section(section: String):
		var directory := Directory.new()
		var path := root.plus_file(_hash(section))
		var res := directory.make_dir_recursive(path)
		if res != OK:
			printerr("Could not create dir")

	func store(section: String, key: String, value):
		var directory := Directory.new()
		var path := root.plus_file(_hash(section)).plus_file(_hash(key))
		var res := directory.make_dir_recursive(path)
		if res != OK:
			printerr("Could not create dir")
			return

		var data := var2str(value)
		var sha := data.sha256_buffer()
		for i in range(REPLICATION):
			var file := File.new()
			if file.open(path.plus_file(String(i)), File.WRITE) != OK:
				printerr("Could not create file")
				continue
			file.store_buffer(sha)
			file.store_string(data)
			file.close()

	func fetch(section: String, key: String, default = null):
		var directory := Directory.new()
		var path := root.plus_file(_hash(section)).plus_file(_hash(key))
		if not directory.dir_exists(path):
			return default

		for i in range(REPLICATION):
			var file := File.new()
			var res := file.open(path.plus_file(String(i)), File.READ)
			if res != OK:
				continue
			var sha := file.get_buffer(32)
			var data := file.get_line()
			if data.sha256_buffer() == sha:
				return str2var(data)

		return default

	func purge(section := "", key := "") -> bool:
		var path := Settings.get_directory()
		if not section.empty():
			path = path.plus_file(_hash(section))
			if not key.empty():
				path = path.plus_file(_hash(key))

		return _directory_remove_recursive(path)

	static func _directory_remove_recursive(path: String) -> bool:
		var directory := Directory.new()

		if directory.open(path) == OK:
			if directory.list_dir_begin(true) != OK:
				return false
			var file_name := directory.get_next()
			while file_name != "":
				if directory.current_is_dir():
					if not _directory_remove_recursive(path.plus_file(file_name)):
						return false
				else:
					if directory.remove(file_name) != OK:
						return false
				file_name = directory.get_next()

			if directory.remove(path) != OK:
				return false
		else:
			return false

		return true

	static func _get_files(path) -> PoolStringArray:
		var files := PoolStringArray()
		var directory := Directory.new()

		if directory.open(path) == OK:
			if directory.list_dir_begin(true) != OK:
				return files
			var file_name := directory.get_next()
			while file_name != "":
				if directory.current_is_dir():
					files.append(file_name.get_file().http_unescape())
				file_name = directory.get_next()

		return files

	func get_sections() -> PoolStringArray:
		return _get_files(root)

	func get_keys(section: String) -> PoolStringArray:
		return _get_files(root.plus_file(_hash(section)))


# create_section(section: String) -> void
# Creates a directory for storing sections
# @param section (String): the name of the section
func create_section(section: String) -> void:
	provider.create_section(section)


# store(section: String, key: String, value: Any) -> void:
# Stores `value` into the `key` of `section`
# @param section (String): the name of the section
# @param key (String): the name of the key
# @param value (Any): the value to store
func store(section: String, key: String, value) -> void:
	provider.store(section, key, value)


func fetch(section: String, key: String, default = null):
	return provider.fetch(section, key, default)


# purge(section: String = "", key: String = "") -> bool
# Delete specified `section` and/or `key` from the file system
# @param section (String): optional section name, delete all sections if missing
# @oaram key (String): optional key name, delete all keys if missing
# @return success (bool): the purge succeeded
func purge(section := "", key := "") -> bool:
	return provider.purge(section, key)


# get_sections() -> PoolStringArray
# Get all sections available
# @return sections (String): all sections available
func get_sections() -> PoolStringArray:
	return provider.get_sections()


# get_keys(section: String) -> PoolStringArray
# Get all keys for the named `section`
# @param section (String): the name of the section
# @return keys (String): all keys in the section
func get_keys(section: String) -> PoolStringArray:
	return provider.get_keys(section)
