extends "storage_provider.gd"

const REPLICATION := 2


func _hash(s: String) -> String:
	if OS.is_debug_build() and Settings.get_debug_filenames():
		return s.http_escape()
	return s.sha256_text()


func create_section(section: String):
	var directory := Directory.new()
	var path := get_root().plus_file(_hash(section))
	var res := directory.make_dir_recursive(path)
	if res != OK:
		printerr("Could not create dir")


func store(section: String, key: String, value):
	var directory := Directory.new()
	var path := get_root().plus_file(_hash(section)).plus_file(_hash(key))
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
	var path := get_root().plus_file(_hash(section)).plus_file(_hash(key))
	if not directory.dir_exists(path):
		return default

	for i in range(REPLICATION):
		var file := File.new()
		var res := file.open(path.plus_file(String(i)), File.READ)
		if res != OK:
			continue
		var sha := file.get_buffer(32)
		var data := file.get_buffer(file.get_len() - 32).get_string_from_utf8()
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
	return _get_files(get_root())


func get_keys(section: String) -> PoolStringArray:
	return _get_files(get_root().plus_file(_hash(section)))