extends "storage_provider.gd"

const Util := preload("util.gd")

var decoder := {
	"s": StoreCommand,
	"p": PurgeCommand,
}
var cache := Util.Cache.new(30)


func read_section(section: String) -> Dictionary:
	section = Util.hash_filename(section)
	var cached_section = cache.get(section)
	if cached_section != null:
		return cached_section

	var path := root.plus_file(section)
	var directory := Directory.new()
	if directory.file_exists(path):
		var file := File.new()
		file.open(path, File.READ)
		var contents := bytes2var(file.get_buffer(file.get_len())) as Dictionary
		if contents:
			cache.insert(section, contents)
			return contents

	# Cache that this file did not exist
	var keys := {}
	cache.insert(section, keys)
	return keys


class StoreCommand:
	extends Util.Command

	var section: String
	var keys: Dictionary

	func _init(section: String, keys: Dictionary):
		self.section = section
		self.keys = keys

	func execute(root: String) -> bool:
		var path := root.plus_file(section)
		var dir := Directory.new()
		var rc := dir.make_dir_recursive(root)
		assert(rc == OK)

		var file := File.new()
		rc = file.open(path, File.WRITE)
		if rc != OK:
			printerr("Could not create file: ", rc)
			return false

		file.store_buffer(var2bytes(keys))
		return true

	func encode() -> Array:
		return ["s", section, keys]


class PurgeCommand:
	extends Util.Command

	var section: String

	func _init(section: String):
		self.section = section

	func execute(root: String) -> bool:
		var directory := Directory.new()
		var path := root.plus_file(section)
		Util.directory_remove_recursive(path)
		return not directory.file_exists(path)

	func encode() -> Array:
		return ["p", section]


func copy_to(_src: String, _dst: String):
	pass


func store(section: String, key: String, value) -> bool:
	Util.run_migration(get_root(), decoder)
	var keys := read_section(section)
	keys[key] = value
	var command := StoreCommand.new(Util.hash_filename(section), keys)
	return Util.execute(get_root(), command)


func fetch(section: String, key: String, default = null):
	Util.run_migration(get_root(), decoder)
	var keys := read_section(section)
	return keys.get(key, default)


func purge(skip_sections: PoolStringArray) -> bool:
	var path := get_root()
	skip_sections = Util.hash_filenames(skip_sections)
	var all_success := true
	var dirs := Util.get_all_in_dir(path)
	for dir in dirs:
		if skip_sections.has(dir):
			continue
		var keys := read_section(dir)
		keys.clear()
		var command := PurgeCommand.new(dir)
		all_success = Util.execute(get_root(), command) and all_success
	return all_success


func purge_section(section: String, skip_keys: PoolStringArray) -> bool:
	var keys := read_section(section)
	for key in keys.keys():
		if key in skip_keys:
			continue
		keys.erase(key)
	var command: Util.Command
	section = Util.hash_filename(section)
	if keys.empty():
		command = PurgeCommand.new(section)
	else:
		command = StoreCommand.new(section, keys)
	return Util.execute(get_root(), command)


func purge_section_key(section: String, key: String) -> bool:
	Util.run_migration(get_root(), decoder)
	var keys := read_section(section)
	if not keys.has(key):
		return false
	keys.erase(key)
	var command := StoreCommand.new(Util.hash_filename(section), keys)
	return Util.execute(get_root(), command)
