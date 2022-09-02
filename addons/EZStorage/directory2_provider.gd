extends "storage_provider.gd"

const Util := preload("util.gd")
var decoder := {
	"s": StoreCommand,
	"p": PurgeCommand,
}


class StoreCommand:
	extends Util.Command

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
		return true

	func encode() -> Array:
		return ["s", section, key, value]


class PurgeCommand:
	extends Util.Command

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

		return Util.directory_remove_recursive(path)

	func encode() -> Array:
		return ["p", section, key]


func copy_to(_src: String, _dst: String):
	pass


func store(section: String, key: String, value) -> bool:
	Util.run_migration(get_root(), decoder)
	var command := StoreCommand.new(
		Util.hash_filename(section), Util.hash_filename(key), var2bytes(value)
	)
	return Util.execute(get_root(), command)


func fetch(section: String, key: String, default = null):
	Util.run_migration(get_root(), decoder)
	var directory := Directory.new()
	var path := get_root().plus_file(Util.hash_filename(section))
	if not directory.dir_exists(path):
		return default

	var file := File.new()
	var res := file.open(path.plus_file(Util.hash_filename(key)), File.READ)
	if res != OK:
		return default
	var data := file.get_buffer(file.get_len())
	return bytes2var(data)


func purge(skip_sections: PoolStringArray) -> bool:
	Util.run_migration(get_root(), decoder)
	var path := get_root()
	skip_sections = Util.hash_filenames(skip_sections)
	var all_success := true
	var dirs := Util.get_all_in_dir(path)
	for dir in dirs:
		if skip_sections.has(dir):
			continue
		var command := PurgeCommand.new(dir, "")
		all_success = Util.execute(get_root(), command) and all_success
	return all_success


func purge_section(section: String, skip_keys: PoolStringArray) -> bool:
	Util.run_migration(get_root(), decoder)
	var path := get_root().plus_file(Util.hash_filename(section))
	skip_keys = Util.hash_filenames(skip_keys)
	var all_success := true
	var dirs := Util.get_all_in_dir(path)
	for dir in dirs:
		if skip_keys.has(dir):
			continue
		var command := PurgeCommand.new(Util.hash_filename(section), dir)
		all_success = Util.execute(get_root(), command) and all_success
	var dir := Directory.new()
	dir.remove(get_root().plus_file(Util.hash_filename(section)))
	return all_success


func purge_section_key(section: String, key: String) -> bool:
	Util.run_migration(get_root(), decoder)
	var command := PurgeCommand.new(Util.hash_filename(section), Util.hash_filename(key))
	return Util.execute(get_root(), command)
