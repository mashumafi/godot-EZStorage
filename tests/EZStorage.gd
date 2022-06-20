extends Node

const Settings := preload("res://addons/EZStorage/settings.gd")

class SectionKeys:
	var section : String
	var keys : PoolStringArray

	func _init(p_section: String, p_keys: PoolStringArray):
		section = p_section
		keys = p_keys

func sk(section: String, keys: PoolStringArray) -> SectionKeys:
	return SectionKeys.new(section, keys)


func _ready():
	EZStorage.purge()
	test_storage()
	test_cache()
	get_tree().quit()

func list_dir(path: String) -> PoolStringArray:
	var ls := PoolStringArray([path])
	var directory := Directory.new()

	if directory.open(path) == OK:
		if directory.list_dir_begin(true) != OK:
			return ls
		var file_name := directory.get_next()
		while file_name != "":
			if directory.current_is_dir():
				ls.append_array(list_dir(path.plus_file(file_name)))
			else:
				ls.append(path.plus_file(file_name))
			file_name = directory.get_next()
	else:
		return ls

	return ls

func list_storage_dir() -> PoolStringArray:
	return list_dir(Settings.get_directory())

func map_to_storage(section_keys: Array) -> PoolStringArray:
	var root := Settings.get_directory()
	var results := PoolStringArray([root])
	for section_key in section_keys:
		results.append(root.plus_file(section_key.section))
		for key in section_key.keys:
			results.append(root.plus_file(section_key.section).plus_file(key))
			results.append(root.plus_file(section_key.section).plus_file(key).plus_file("0"))
			results.append(root.plus_file(section_key.section).plus_file(key).plus_file("1"))
	return results

func assert_eq(left, right):
	assert(left == right)

func test_storage() -> void:
	assert_eq(list_storage_dir(), map_to_storage([]))

	assert_eq(EZStorage.fetch("hello", "world"), null)
	assert_eq(list_storage_dir(), map_to_storage([]))

	assert_eq(EZStorage.fetch("hello", "world", "demo"), "demo")
	assert_eq(list_storage_dir(), map_to_storage([]))

	EZStorage.store("hello", "world", "test")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["world"])]))

	assert_eq(EZStorage.fetch("hello", "world"), "test")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["world"])]))

	assert_eq(EZStorage.fetch("hello", "world", "demo"), "test")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["world"])]))

	EZStorage.store("game", "over", 3)
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["over"]), sk("hello", ["world"])]))

	assert_eq(EZStorage.fetch("game", "over"), 3)
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["over"]), sk("hello", ["world"])]))

	assert_eq(EZStorage.fetch("game", "over", -1), 3)
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["over"]), sk("hello", ["world"])]))

	EZStorage.store("game", "pi", 3.14)
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["over", "pi"]), sk("hello", ["world"])]))

	EZStorage.store("game", "highscore", 101)
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["highscore", "over", "pi"]), sk("hello", ["world"])]))

	assert(EZStorage.purge("game", "over"))
	assert_eq(list_storage_dir(), map_to_storage([sk("game", ["highscore", "pi"]), sk("hello", ["world"])]))

	assert(EZStorage.purge("game"))
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["world"])]))

	assert(EZStorage.purge())
	assert_eq(list_storage_dir(), map_to_storage([]))

class CacheListener:
	var changes := []
	func _changed(key, section):
		changes.append([section, key])

func test_cache() -> void:
	assert_eq(list_storage_dir(), map_to_storage([]))

	var hello_section := EZCache.get_section("hello")
	var listener := CacheListener.new()
	assert_eq(hello_section.connect("changed", listener, "_changed", [hello_section]), OK)
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	assert_eq(hello_section.fetch("world"), null)
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	assert_eq(hello_section.fetch("world", "test"), "test")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	assert_eq(hello_section.fetch("world", "demo", true), "demo")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	assert_eq(hello_section.fetch("world", "test"), "demo")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	assert_eq(hello_section.fetch("world"), "demo")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", [])]))
	assert_eq(listener.changes, [])

	hello_section.store("new_key", "new_value")
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["new_key"])]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
	])

	EZStorage.store("hello", "purge", true)
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["new_key", "purge"])]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
	])

	EZStorage.store("purge", "example", true)
	assert_eq(list_storage_dir(), map_to_storage([sk("purge", ["example"]), sk("hello", ["new_key", "purge"])]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
	])

	assert(hello_section.purge(["new_key"]))
	assert_eq(list_storage_dir(), map_to_storage([sk("purge", ["example"]), sk("hello", ["new_key"])]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
	])

	assert(EZCache.purge(["hello"]))
	assert_eq(list_storage_dir(), map_to_storage([sk("hello", ["new_key"])]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
	])

	assert(EZCache.purge())
	assert_eq(list_storage_dir(), map_to_storage([]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
		[hello_section, "new_key"],
	])

	assert(EZStorage.purge())
	assert_eq(list_storage_dir(), map_to_storage([]))
	assert_eq(listener.changes, [
		[hello_section, "new_key"],
		[hello_section, "new_key"],
	])
