extends "storage_provider.gd"

enum CommandType { RESIZE, WRITE_POSITION, WRITE_SHA, WRITE_BUFFER }

const KV_VERSION := 1
const TRANSACTION_VERSION := 1
const EMPTY_SHA := PoolByteArray(
	[
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
		0,
	]
)
const SEGMENT_SIZE := 408
const SEGMENT_BUFFER_SIZE := SEGMENT_SIZE - 8
const SECTION_SIZE := 40
const SHA_SIZE := 32
const INT_SIZE := 8
const KEY_SIZE := 80
const KEY_BUFFER_SIZE := 48
const KV_FILE_NAME := "kv"
const TRANSACTION_FILE_NAME := "t"


class KVHeader:
	var version: int
	var section_segment_pos: int
	var empty_segments_pos: int


func _init():
	_run_transaction(_get_file(KV_FILE_NAME))


class Command:
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


func store(section: String, key: String, value):
	var kv_file := _get_file(KV_FILE_NAME)
	var header := _get_header(kv_file)
	var section_segment_pos := header.section_segment_pos

	var section_sha := section.sha256_buffer()
	var section_idx := section.hash() % 10
	var transaction := []

	var key_segment_pos := 0
	while section_segment_pos != 0:
		kv_file.seek(section_segment_pos)
		var next_section_segment_pos := kv_file.get_64()
		kv_file.seek(section_segment_pos + INT_SIZE + section_idx * SECTION_SIZE)
		var current_sha := kv_file.get_buffer(SHA_SIZE)

		var section_name_pos := section_segment_pos + INT_SIZE + section_idx * SECTION_SIZE
		if current_sha == section_sha:
			kv_file.seek(section_name_pos + SHA_SIZE)
			key_segment_pos = kv_file.get_64()
			break

		if current_sha == EMPTY_SHA:
			transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE))
			key_segment_pos = kv_file.get_len()
			transaction.append(WriteShaCommand.new(section_name_pos, section_sha))
			transaction.append(
				WritePositionCommand.new(section_name_pos + SHA_SIZE, key_segment_pos)
			)
			break

		if next_section_segment_pos == 0:
			transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE * 2))
			transaction.append(WritePositionCommand.new(section_segment_pos, kv_file.get_len()))
			section_segment_pos = kv_file.get_len()
			transaction.append(
				WriteShaCommand.new(
					section_segment_pos + INT_SIZE + section_idx * SECTION_SIZE, section_sha
				)
			)
			key_segment_pos = section_segment_pos + SEGMENT_SIZE
			transaction.append(
				WritePositionCommand.new(
					section_segment_pos + INT_SIZE + section_idx * SECTION_SIZE + SHA_SIZE,
					key_segment_pos
				)
			)
			break

		section_segment_pos = next_section_segment_pos

	_create_transaction(kv_file, transaction)

	var key_sha := key.sha256_buffer()
	var key_idx := key.hash() % 5
	var buffer := var2bytes(value)

	while key_segment_pos != 0:
		kv_file.seek(key_segment_pos)
		var next_key_segment_pos := kv_file.get_64()
		kv_file.seek(key_segment_pos + INT_SIZE + key_idx * KEY_SIZE)
		var current_sha := kv_file.get_buffer(SHA_SIZE)

		var key_name_pos := key_segment_pos + INT_SIZE + key_idx * KEY_SIZE
		if current_sha == key_sha:
			transaction.append(WriteBufferCommand.new(key_name_pos + SHA_SIZE, buffer))
			break

		if current_sha == EMPTY_SHA:
			if false:  # IF buffer too big
				transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE))
			transaction.append(WriteShaCommand.new(key_name_pos, key_sha))
			transaction.append(WriteBufferCommand.new(key_name_pos + SHA_SIZE, buffer))
			break

		if next_key_segment_pos != 0:
			key_segment_pos = next_key_segment_pos
		else:
			transaction.append(ResizeCommand.new(kv_file.get_len() + SEGMENT_SIZE * 2))
			transaction.append(WritePositionCommand.new(key_segment_pos, kv_file.get_len()))
			key_name_pos = kv_file.get_len() + INT_SIZE + key_idx * KEY_SIZE
			transaction.append(WriteShaCommand.new(key_name_pos, key_sha))
			transaction.append(WriteBufferCommand.new(key_name_pos + SHA_SIZE, buffer))
			break

	_create_transaction(kv_file, transaction)


func fetch(section: String, key: String, default = null):
	var kv_file := _get_file(KV_FILE_NAME)
	var header := _get_header(kv_file)

	var section_segment_pos := header.section_segment_pos
	var section_sha := section.sha256_buffer()
	var section_idx := section.hash() % 10
	var key_segment_pos := 0
	while section_segment_pos != 0:
		kv_file.seek(section_segment_pos)
		var next_section_segment_pos := kv_file.get_64()
		kv_file.seek(section_segment_pos + INT_SIZE + section_idx * SECTION_SIZE)
		var current_sha := kv_file.get_buffer(SHA_SIZE)

		if current_sha == section_sha:
			key_segment_pos = kv_file.get_64()
			break

		section_segment_pos = next_section_segment_pos

	if key_segment_pos == 0:
		return default

	var key_sha := key.sha256_buffer()
	var key_idx := key.hash() % 5
	while key_segment_pos != 0:
		kv_file.seek(key_segment_pos)
		var next_key_segment_pos := kv_file.get_64()
		kv_file.seek(key_segment_pos + INT_SIZE + key_idx * KEY_SIZE)
		var current_sha := kv_file.get_buffer(SHA_SIZE)

		if current_sha == key_sha:
			var size := kv_file.get_64()
			var buffer := kv_file.get_buffer(size)
			return bytes2var(buffer)

		key_segment_pos = next_key_segment_pos

	return default


func purge(section := "", key := "") -> bool:
	if section.empty() and key.empty():
		var dir := Directory.new()
		var rc := dir.remove(root.plus_file(KV_FILE_NAME))
		if rc != OK:
			printerr("Could not purge.")
		return true

	if key.empty():
		return true

	return true


func get_sections() -> PoolStringArray:
	return PoolStringArray()


func get_keys(_section: String) -> PoolStringArray:
	return PoolStringArray()
