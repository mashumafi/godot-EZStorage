extends "storage_provider.gd"

const Util := preload("util.gd")
const REPLICATION := 2


func copy_to(_src: String, _dst: String):
	pass


func store(section: String, key: String, value):
	var directory := Directory.new()
	var path := get_root().plus_file(Util.hash_filename(section)).plus_file(Util.hash_filename(key))
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
	var path := get_root().plus_file(Util.hash_filename(section)).plus_file(Util.hash_filename(key))
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
	var path := get_root()
	if not section.empty():
		path = path.plus_file(Util.hash_filename(section))
		if not key.empty():
			path = path.plus_file(Util.hash_filename(key))

	return Util.directory_remove_recursive(path)


func get_sections() -> PoolStringArray:
	return Util.get_dirs_in_dir(get_root())


func get_keys(section: String) -> PoolStringArray:
	return Util.get_dirs_in_dir(get_root().plus_file(Util.hash_filename(section)))
