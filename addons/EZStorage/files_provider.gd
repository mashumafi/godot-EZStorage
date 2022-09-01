extends "storage_provider.gd"

const Util := preload("util.gd")
var decoder := {
	"s": StoreCommand,
	"p": PurgeCommand,
}


func read_section(section: String) -> Dictionary:
	var path := root.plus_file(section)
	var directory := Directory.new()
	if directory.file_exists(path):
		var file := File.new()
		file.open(path, File.READ)
		var contents := bytes2var(file.get_buffer(file.get_len())) as Dictionary
		if contents:
			return contents
	return {}


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
	var keys := read_section(Util.hash_filename(section))
	keys[key] = value
	var command := StoreCommand.new(Util.hash_filename(section), keys)
	return Util.execute(get_root(), command)


func fetch(section: String, key: String, default = null):
	Util.run_migration(get_root(), decoder)
	var keys := read_section(section)
	return keys.get(key, default)


func purge(section := "", key := "") -> bool:
	Util.run_migration(get_root(), decoder)
	var command: Util.Command
	if section and key:
		var keys := read_section(Util.hash_filename(section))
		keys.erase(key)
		command = StoreCommand.new(Util.hash_filename(section), keys)
	else:
		command = PurgeCommand.new(Util.hash_filename(section))
	return Util.execute(get_root(), command)


func get_sections() -> PoolStringArray:
	return Util.get_all_in_dir(get_root())


func get_keys(section: String) -> PoolStringArray:
	return PoolStringArray(read_section(section).keys())