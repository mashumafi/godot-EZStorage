extends "storage_provider.gd"

var migration_name := "migration".sha256_text()


func _hash(s: String) -> String:
	if OS.is_debug_build() and Settings.get_debug_filenames():
		return s.http_escape()
	return s.sha256_text()


class Command:
	func execute(_root: String) -> bool:
		return false

	func encode() -> Dictionary:
		return {"command": ""}


class StoreCommand:
	extends Command

	var section: String
	var key: String
	var value: PoolByteArray

	func _init(section: String, key: String, value: PoolByteArray):
		self.section = section
		self.key = key
		self.value = value

	func execute(root: String) -> bool:
		var path := root.plus_file(section)
		var dir := Directory.new()
		var rc := dir.make_dir_recursive(path)
		assert(rc == OK)

		var file := File.new()
		rc = file.open(path.plus_file(key), File.WRITE)
		if rc != OK:
			printerr("Could not create file: ", rc)
			return false

		file.store_buffer(value)
		file.close()
		return true

	func encode() -> Dictionary:
		return {"command": "store", "section": section, "key": key, "value": value}


class PurgeCommand:
	extends Command

	var section: String
	var key: String

	func _init(section: String, key: String):
		self.section = section
		self.key = key

	func execute(root: String) -> bool:
		var path := root
		if not section.empty():
			path = path.plus_file(section)
			if not key.empty():
				path = path.plus_file(key)

		return _directory_remove_recursive(path)

	func encode() -> Dictionary:
		return {"command": "purge", "section": section, "key": key}

	static func _directory_remove_recursive(path: String) -> bool:
		var directory := Directory.new()

		if directory.file_exists(path):
			directory.remove(path)
			return not directory.file_exists(path)

		if directory.dir_exists(path):
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
		else:
			return false

		return true


func decode(buffer: Dictionary) -> Command:
	match buffer["command"]:
		"store":
			return StoreCommand.new(buffer["section"], buffer["key"], buffer["value"])
		"purge":
			return PurgeCommand.new(buffer["section"], buffer["key"])
	return null


func run_migration():
	var dir := Directory.new()
	var migration_path := get_root().plus_file(migration_name)
	if dir.file_exists(migration_path):
		var file := File.new()
		file.open(migration_path, File.READ)
		var command = bytes2var(file.get_buffer(file.get_len())) as Dictionary
		file.close()
		if command:
			decode(command).execute(get_root())

		var rc := dir.remove(migration_path)
		assert(not dir.file_exists(migration_path))


func execute(command: Command) -> bool:
	var dir := Directory.new()
	var rc := dir.make_dir_recursive(get_root())
	assert(rc == OK, "Could not create base directory.")
	var file := File.new()
	var migration_path := get_root().plus_file(migration_name)
	rc = file.open(migration_path, File.WRITE)
	assert(rc == OK, "Could not create migration file.")

	file.store_buffer(var2bytes(command.encode()))
	file.close()

	var result := command.execute(get_root())

	dir.remove(migration_path)
	assert(not dir.file_exists(migration_path))

	return result


func copy_to(_src: String, _dst: String):
	pass


func store(section: String, key: String, value) -> bool:
	run_migration()
	var command := StoreCommand.new(_hash(section), _hash(key), var2bytes(value))
	return execute(command)


func fetch(section: String, key: String, default = null):
	run_migration()
	var directory := Directory.new()
	var path := get_root().plus_file(_hash(section))
	if not directory.dir_exists(path):
		return default

	var file := File.new()
	var res := file.open(path.plus_file(_hash(key)), File.READ)
	if res != OK:
		return default
	var data := file.get_buffer(file.get_len())
	return bytes2var(data)


func purge(section := "", key := "") -> bool:
	run_migration()
	var command := PurgeCommand.new(_hash(section), _hash(key))
	return execute(command)


static func _get_files(path) -> PoolStringArray:
	var files := PoolStringArray()
	var directory := Directory.new()

	if directory.open(path) == OK:
		if directory.list_dir_begin(true) != OK:
			return files
		var file_name := directory.get_next()
		while file_name != "":
			files.append(file_name.get_file().http_unescape())
			file_name = directory.get_next()

	return files


func get_sections() -> PoolStringArray:
	return _get_files(get_root())


func get_keys(section: String) -> PoolStringArray:
	return _get_files(get_root().plus_file(_hash(section)))
