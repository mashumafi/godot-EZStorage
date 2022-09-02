extends "storage_provider.gd"

const Util := preload("util.gd")

var decoder := {
	"s": StoreCommand,
	"p": PurgeCommand,
}
var cache := Cache.new(30)


class ObjectFactory:
	var cache := []
	var type

	func _init(type):
		self.type = type

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			for obj in cache:
				obj.free()

	func alloc() -> Object:
		if cache.empty():
			return self.type.call("new")

		return cache.pop_back()

	func has(inst: Object) -> bool:
		for obj in cache:
			if obj == inst:
				return true
		return false

	func delete(obj: Object):
		assert(not has(obj), "Already deleted the obj")
		cache.push_back(obj)


class Cache:
	extends Reference

	var head: Link
	var tail: Link
	var lookup: Dictionary
	var size: int
	var links := ObjectFactory.new(Link)

	class Link:
		extends Object

		var next: Link
		var prev: Link
		var key
		var data

		func _notification(what: int) -> void:
			if what == NOTIFICATION_PREDELETE:
				if next:
					next.free()

	func _init(size: int):
		self.size = size

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if head:
				head.free()

	func get(key):
		var link: Link = lookup.get(key)
		if link:
			if link != head and lookup.size() > 1:
				_remove(key)
				_insert(link)

			return link.data

	func _insert(link: Link):
		if head == null:
			tail = link
		else:
			head.prev = link

		link.next = head
		head = link

	func insert(key, data):
		assert(not lookup.has(key), "The key already exists.")
		var link: Link = links.alloc()
		link.key = key
		link.data = data
		lookup[key] = link
		_insert(link)
		if lookup.size() > size:
			_delete_last()

	func _remove(key) -> Link:
		var current: Link = lookup.get(key)
		if not current:
			return null

		if current == head:
			head = head.next
		else:
			current.prev.next = current.next

		if current == tail:
			tail = current.prev
		else:
			current.next.prev = current.prev

		return current

	func _delete_last():
		var link := tail

		if head.next == null:
			head = null
		else:
			tail.prev.next = null

		tail = tail.prev

		lookup.erase(link.key)
		link.next = null
		links.delete(link)

	func erase(key):
		var current := _remove(key)
		if current:
			lookup.erase(key)
			current.next = null
			links.delete(current)


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
		cache.erase(dir)
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
		cache.erase(section)
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
