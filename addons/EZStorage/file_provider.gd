extends "storage_provider.gd"

enum CommandType { RESIZE, WRITE_POSITION, WRITE_SHA, WRITE_BUFFER }

const KV_VERSION := 1
const TRANSACTION_VERSION := 1
const SEGMENT_SIZE := 168
const SEGMENT_BUFFER_SIZE := SEGMENT_SIZE - 8
const SECTION_SIZE := 40
const SHA_SIZE := 32
const INT_SIZE := 8
const KV_SIZE := 80
const KV_VALUE_SIZE := 48
const KV_BUFFER_SIZE := KV_VALUE_SIZE - INT_SIZE
const KV_FILE_NAME := "kv"
const TRANSACTION_FILE_NAME := "t"
const SECTION_COUNT := SEGMENT_BUFFER_SIZE / SECTION_SIZE
const KV_COUNT := SEGMENT_BUFFER_SIZE / KV_SIZE

var empty_sha := PoolByteArray()


class KVHeader:
	var version: int
	var section_segment_pos: int
	var empty_segments_pos: int


class Command:
	func execute(_file: File):
		pass

	func encode(_file: File):
		pass

	func decode(_file: File):
		pass


class ResizeCommand:
	extends Command

	var size: int

	func _init(p_size := 0):
		self.size = p_size

	func execute(file: File):
		while file.get_len() < size:
			add_segment(file)

	static func add_segment(file: File) -> int:
		var origin := file.get_position()
		file.seek_end(0)
		var start := file.get_position()
		var zeros := PoolByteArray()
		zeros.resize(SEGMENT_SIZE - file.get_len() % SEGMENT_SIZE)
		zeros.fill(0)
		file.store_buffer(zeros)
		file.seek(origin)
		return start

	func encode(file: File):
		file.store_8(CommandType.RESIZE)
		file.store_64(size)

	func decode(file: File):
		size = file.get_64()


class WriteCommand:
	extends Command

	var position: int

	func _init(p_position := 0):
		self.position = p_position

	func execute(file: File):
		file.seek(position)

	func encode(file: File):
		file.store_64(position)

	func decode(file: File):
		position = file.get_64()


class WritePositionCommand:
	extends WriteCommand

	var value: int

	func _init(p_position := 0, p_value := 0).(p_position):
		self.value = p_value

	func execute(file: File):
		.execute(file)
		file.store_64(value)

	func encode(file: File):
		file.store_8(CommandType.WRITE_POSITION)
		.encode(file)
		file.store_64(value)

	func decode(file: File):
		.decode(file)
		value = file.get_64()


class WriteShaCommand:
	extends WriteCommand

	var sha: PoolByteArray

	func _init(p_position := 0, p_sha := PoolByteArray()).(p_position):
		self.sha = p_sha

	func execute(file: File):
		.execute(file)
		file.store_buffer(sha)

	func encode(file: File):
		file.store_8(CommandType.WRITE_SHA)
		.encode(file)
		file.store_buffer(sha)

	func decode(file: File):
		.decode(file)
		sha = file.get_buffer(SHA_SIZE)


class WriteBufferCommand:
	extends WriteCommand

	var buffer: PoolByteArray

	func _init(p_position := 0, p_buffer := PoolByteArray()).(p_position):
		self.buffer = p_buffer

	func execute(file: File):
		.execute(file)
		file.store_64(buffer.size())
		file.store_buffer(buffer)

	func encode(file: File):
		file.store_8(CommandType.WRITE_BUFFER)
		.encode(file)
		file.store_64(buffer.size())
		file.store_buffer(buffer)

	func decode(file: File):
		.decode(file)
		buffer = file.get_buffer(file.get_64())


func _init():
	empty_sha.resize(32)
	empty_sha.fill(0)


func decode_transaction(transaction_file: File) -> Array:
	var version := transaction_file.get_64()
	var repr := transaction_file.get_64()
	var size := transaction_file.get_64()
	var transaction := []
	for _i in size:
		var command: Command
		match transaction_file.get_8():
			CommandType.RESIZE:
				command = ResizeCommand.new()
			CommandType.WRITE_POSITION:
				command = WritePositionCommand.new()
			CommandType.WRITE_SHA:
				command = WriteShaCommand.new()
			CommandType.WRITE_BUFFER:
				command = WriteBufferCommand.new()
		command.decode(transaction_file)
		transaction.push_back(command)
	return transaction


func encode_transaction(transaction_file: File, transaction: Array):
	transaction_file.store_64(TRANSACTION_VERSION)
	transaction_file.store_64(0)  # hash
	transaction_file.store_64(transaction.size())
	for command in transaction:
		command.encode(transaction_file)
	transaction.clear()
	transaction_file.close()


func copy_to(_src: String, _dst: String):
	pass


func _create_file(path: String):
	var dir := Directory.new()
	dir.make_dir_recursive(root)
	path = root.plus_file(path)
	if not dir.file_exists(path):
		var file := File.new()
		var rc := file.open(path, File.WRITE)
		if rc != OK:
			printerr("Could not create file ", rc, " ", path)


func _get_file(path: String) -> File:
	_create_file(path)

	var file := File.new()
	path = root.plus_file(path)
	var rc := file.open(path, File.READ_WRITE)
	if rc != OK:
		printerr("Could not open file ", rc, " ", path)
	return file


func _create_transaction(kv_file: File, transaction: Array):
	if transaction.empty():
		return

	var transaction_file := _get_file(TRANSACTION_FILE_NAME)
	encode_transaction(transaction_file, transaction)
	_run_transaction(kv_file)


func _run_transaction(kv_file: File):
	var dir := Directory.new()
	if dir.file_exists(root.plus_file(TRANSACTION_FILE_NAME)):
		var file := _get_file(TRANSACTION_FILE_NAME)
		var transaction = decode_transaction(file)
		for command in transaction:
			var cmd := command as Command
			cmd.execute(kv_file)
		dir.remove(root.plus_file(TRANSACTION_FILE_NAME))


func _get_header(kv_file: File) -> KVHeader:
	var header := KVHeader.new()

	if kv_file.get_len() < SEGMENT_SIZE:
		ResizeCommand.add_segment(kv_file)

	header.version = kv_file.get_64()
	header.section_segment_pos = kv_file.get_64()
	header.empty_segments_pos = kv_file.get_64()

	if header.version == 0:
		header.version = KV_VERSION
		header.section_segment_pos = SEGMENT_SIZE
		header.empty_segments_pos = SEGMENT_SIZE * 2
		var transaction := []
		transaction.append(ResizeCommand.new(SEGMENT_SIZE * 3))
		transaction.append(WritePositionCommand.new(0, header.version))
		transaction.append(WritePositionCommand.new(INT_SIZE * 1, header.section_segment_pos))
		transaction.append(WritePositionCommand.new(INT_SIZE * 2, header.empty_segments_pos))
		_create_transaction(kv_file, transaction)

	return header


class Segment:
	var kv_file: File
	var position: int
	var next_position: int

	func _init(p_kv_file: File, p_segment_position: int):
		self.kv_file = p_kv_file
		self.position = p_segment_position
		kv_file.seek(position)
		self.next_position = kv_file.get_64()


class SectionSegment:
	extends Segment

	func _init(p_kv_file: File, p_segment_position: int).(p_kv_file, p_segment_position):
		pass

	func set_next_position(next_position: int) -> WritePositionCommand:
		return WritePositionCommand.new(position, next_position)

	func set_key(index: int, sha_buffer: PoolByteArray) -> WriteShaCommand:
		return WriteShaCommand.new(get_key_position(index), sha_buffer)

	func get_key(index: int) -> PoolByteArray:
		seek_to_key(index)
		return kv_file.get_buffer(SHA_SIZE)

	func seek_to_key(index: int):
		kv_file.seek(get_key_position(index))

	func get_key_position(index: int) -> int:
		return position + INT_SIZE + index * SECTION_SIZE

	func set_value(index: int, position: int) -> WritePositionCommand:
		return WritePositionCommand.new(get_value_position(index), position)

	func get_value(index: int) -> int:
		seek_to_value(index)
		return kv_file.get_64()

	func seek_to_value(index: int):
		kv_file.seek(get_value_position(index))

	func get_value_position(index: int) -> int:
		return position + INT_SIZE + index * SECTION_SIZE + SHA_SIZE

	func next() -> SectionSegment:
		if not has_next():
			return null
		return SectionSegment.new(kv_file, next_position)

	func has_next() -> bool:
		return next_position != 0


class KVSegment:
	extends Segment

	func _init(p_kv_file: File, p_segment_position: int).(p_kv_file, p_segment_position):
		pass

	func set_next_position(next_position: int) -> WritePositionCommand:
		return WritePositionCommand.new(position, next_position)

	func set_key(index: int, sha_buffer: PoolByteArray) -> WriteShaCommand:
		return WriteShaCommand.new(get_key_position(index), sha_buffer)

	func get_key(index: int) -> PoolByteArray:
		seek_to_key(index)
		return kv_file.get_buffer(SHA_SIZE)

	func seek_to_key(index: int):
		kv_file.seek(get_key_position(index))

	func get_key_position(index: int) -> int:
		return position + INT_SIZE + index * KV_SIZE

	func set_value(index: int, buffer: PoolByteArray) -> WriteBufferCommand:
		return WriteBufferCommand.new(get_value_position(index), buffer)

	func seek_to_value(index: int):
		kv_file.seek(get_value_position(index))

	func get_value_position(index: int) -> int:
		return position + INT_SIZE + index * KV_SIZE + SHA_SIZE

	func next() -> KVSegment:
		if not has_next():
			return null
		return KVSegment.new(kv_file, next_position)

	func has_next() -> bool:
		return next_position != 0


class EmptySegments:
	extends Segment

	var size : int

	func _init(p_kv_file: File, p_segment_position: int).(p_kv_file, p_segment_position):
		size = kv_file.get_64()

	func alloc(segments: int, transaction: Array) -> PoolIntArray:
		transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE * segments))
		var positions := PoolIntArray()
		for position in segments:
			positions.push_back(kv_file.get_len() + SEGMENT_SIZE * position)
		return positions

	func delete():
		pass

	func next() -> EmptySegments:
		if not has_next():
			return null
		return EmptySegments.new(kv_file, next_position)

	func has_next() -> bool:
		return next_position != 0


func store(section: String, key: String, value):
	_run_transaction(_get_file(KV_FILE_NAME))

	var kv_file := _get_file(KV_FILE_NAME)
	var header := _get_header(kv_file)
	var section_segment := SectionSegment.new(kv_file, header.section_segment_pos)
	var empty_segments := EmptySegments.new(kv_file, header.empty_segments_pos)

	var section_sha := section.sha256_buffer()
	var section_idx := section.hash() % SECTION_COUNT
	var transaction := []

	var key_segment_pos := 0
	while section_segment:
		var current_sha := section_segment.get_key(section_idx)
		if current_sha == section_sha:
			key_segment_pos = section_segment.get_value(section_idx)
			break

		if current_sha == empty_sha:
			transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE))
			key_segment_pos = kv_file.get_len()
			transaction.append(section_segment.set_key(section_idx, section_sha))
			transaction.append(section_segment.set_value(section_idx, key_segment_pos))
			break

		if not section_segment.has_next():
			var segment_positions := empty_segments.alloc(2, transaction)
			transaction.append(section_segment.set_next_position(segment_positions[0]))
			var new_section_segment = SectionSegment.new(kv_file, segment_positions[0])
			transaction.append(new_section_segment.set_key(section_idx, section_sha))
			key_segment_pos = segment_positions[1]
			transaction.append(new_section_segment.set_value(section_idx, key_segment_pos))
			break

		section_segment = section_segment.next()

	_create_transaction(kv_file, transaction)

	var key_sha := key.sha256_buffer()
	var key_idx := key.hash() % KV_COUNT
	var buffer := var2bytes(value)

	var key_segment := KVSegment.new(kv_file, key_segment_pos)
	while key_segment:
		var current_sha := key_segment.get_key(key_idx)
		if current_sha == key_sha:
			transaction.append(key_segment.set_value(key_idx, buffer))
			break

		if current_sha == empty_sha:
			if buffer.size() > KV_BUFFER_SIZE:
				transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE))
			transaction.append(key_segment.set_key(key_idx, key_sha))
			transaction.append(key_segment.set_value(key_idx, buffer))
			break

		if key_segment.has_next():
			key_segment = key_segment.next()
		else:
			var segment_positions := empty_segments.alloc(1, transaction)
			transaction.append(key_segment.set_next_position(segment_positions[0]))
			var new_key_segment := KVSegment.new(kv_file, segment_positions[0])
			transaction.append(new_key_segment.set_key(key_idx, key_sha))
			transaction.append(new_key_segment.set_value(key_idx, buffer))
			break

	_create_transaction(kv_file, transaction)


func fetch(section: String, key: String, default = null):
	_run_transaction(_get_file(KV_FILE_NAME))

	var kv_file := _get_file(KV_FILE_NAME)
	var header := _get_header(kv_file)

	var section_segment := SectionSegment.new(kv_file, header.section_segment_pos)
	var section_sha := section.sha256_buffer()
	var section_idx := section.hash() % SECTION_COUNT
	var key_segment_pos := 0
	while section_segment:
		var current_sha := section_segment.get_key(section_idx)
		if current_sha == section_sha:
			key_segment_pos = kv_file.get_64()
			break

		section_segment = section_segment.next()

	if key_segment_pos == 0:
		return default

	var key_segment := KVSegment.new(kv_file, key_segment_pos)
	var key_sha := key.sha256_buffer()
	var key_idx := key.hash() % KV_COUNT
	while key_segment:
		var current_sha := key_segment.get_key(key_idx)
		if current_sha == key_sha:
			var size := kv_file.get_64()
			var buffer := kv_file.get_buffer(size)
			return bytes2var(buffer, false)

		key_segment = key_segment.next()

	return default


func purge(section := "", key := "") -> bool:
	_run_transaction(_get_file(KV_FILE_NAME))

	if section.empty():
		var dir := Directory.new()
		var rc := dir.remove(root.plus_file(KV_FILE_NAME))
		if rc != OK:
			printerr("Could not purge: ", rc)
		return true

	if key.empty():
		# Only section is defined
		return true

	# Both are defined
	return true


func get_sections() -> PoolStringArray:
	_run_transaction(_get_file(KV_FILE_NAME))

	return PoolStringArray()


func get_keys(_section: String) -> PoolStringArray:
	_run_transaction(_get_file(KV_FILE_NAME))

	return PoolStringArray()
