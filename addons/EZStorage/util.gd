extends Reference

const Settings := preload("settings.gd")

const MIGRATION_NAME := "migration"


class Command:
	func execute(_root: String) -> bool:
		return false

	func encode() -> Array:
		return [""]


static func hash_filename(s: String) -> String:
	if OS.is_debug_build() and Settings.get_debug_filenames():
		return s.http_escape()
	return s.sha256_text()


static func hash_filenames(s: PoolStringArray) -> PoolStringArray:
	for i in range(s.size()):
		s[i] = hash_filename(s[i])
	return s


static func decode(buffer: Array, decoder: Dictionary) -> Command:
	if buffer.empty():
		return null

	var command_type = decoder.get(buffer[0])
	if not command_type:
		return null

	var args := buffer.slice(1, buffer.size())
	var command = command_type.callv("new", args)
	return command


static func run_migration(root: String, decoder: Dictionary):
	var dir := Directory.new()
	var migration_path := root.plus_file(MIGRATION_NAME)
	if dir.file_exists(migration_path):
		var file := File.new()
		file.open(migration_path, File.READ)
		var command = bytes2var(file.get_buffer(file.get_len())) as Array
		file.close()
		if command:
			decode(command, decoder).execute(root)

		var rc := dir.remove(migration_path)
		assert(not dir.file_exists(migration_path))


static func execute(root: String, command: Command) -> bool:
	var dir := Directory.new()
	var rc := dir.make_dir_recursive(root)
	assert(rc == OK, "Could not create base directory.")
	var file := File.new()
	var migration_path := root.plus_file(MIGRATION_NAME)
	rc = file.open(migration_path, File.WRITE)
	assert(rc == OK, "Could not create migration file.")

	file.store_buffer(var2bytes(command.encode()))
	file.close()

	var result := command.execute(root)

	dir.remove(migration_path)
	assert(not dir.file_exists(migration_path))

	return result


class ObjectPool:
	var cache := []
	var type

	func _init(type, size := 0):
		self.type = type
		for i in size:
			delete(_alloc())

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			for obj in cache:
				obj.free()

	func _alloc() -> Object:
		return self.type.new()

	func alloc() -> Object:
		if cache.empty():
			return _alloc()

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
	var links_pool : ObjectPool

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
		links_pool = ObjectPool.new(Link, size)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			if head:
				head.free()

	func get(key):
		var link: Link = lookup.get(key)
		if link:
			if link != head:
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

	func has(key) -> bool:
		return lookup.has(key)

	func insert(key, data):
		assert(not lookup.has(key), "The key already exists.")
		var link: Link = links_pool.alloc()
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

		_delete(link)

	func erase(key):
		var current := _remove(key)
		if current:
			_delete(current)

	func _delete(link: Link):
		lookup.erase(link.key)
		link.next = null
		links_pool.delete(link)


static func directory_remove_recursive(path: String) -> bool:
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
					if not directory_remove_recursive(path.plus_file(file_name)):
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


static func get_all_in_dir(path) -> PoolStringArray:
	var files := PoolStringArray()
	var directory := Directory.new()

	if directory.open(path) == OK:
		if directory.list_dir_begin(true) != OK:
			return files
		var file_name := directory.get_next()
		while file_name != "":
			files.append(file_name.get_file())
			file_name = directory.get_next()

	return files


static func get_dirs_in_dir(path) -> PoolStringArray:
	var files := PoolStringArray()
	var directory := Directory.new()

	if directory.open(path) == OK:
		if directory.list_dir_begin(true) != OK:
			return files
		var file_name := directory.get_next()
		while file_name != "":
			if directory.current_is_dir():
				files.append(file_name.get_file())
			file_name = directory.get_next()

	return files
