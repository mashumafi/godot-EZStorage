extends Node

const Settings := preload("settings.gd")
const StorageProvider := preload("storage_provider.gd")
const DirectoryProvider := preload("directory_provider.gd")

var provider := get_storage_provider()


static func get_storage_provider() -> StorageProvider:
	match Settings.get_storage_provider():
		Settings.StorageProviderType.DIRECTORY:
			return DirectoryProvider.new()

	return DirectoryProvider.new()


# set_directory_suffix(suffix: String, copy := false)
# Sets the directory suffix.
# Useful to seperate files between different users.
# @param suffix (String): the suffix appended to the root directory
# @param copy (bool): copies files from the existing storage to the new path
func set_directory_suffix(suffix: String, copy := false):
	provider.set_root_directory(Settings.get_directory().plus_file(suffix), copy)


# create_section(section: String) -> void
# Creates a directory for storing sections
# @param section (String): the name of the section
func create_section(section: String) -> void:
	provider.create_section(section)


# store(section: String, key: String, value: Any) -> void:
# Stores `value` into the `key` of `section`.
# @param section (String): The name of the section.
# @param key (String): The name of the key.
# @param value (Any): The value to store.
func store(section: String, key: String, value) -> void:
	provider.store(section, key, value)


# fetch(section: String, key: String, default: Any = null) -> Any:
# Fetches values from the `key` of `section`.
# @param section (String): The name of the section.
# @param key (String): The name of the key.
# @param default (Any): The value returned if key/section does not exist.
# @return value (Any): The result or `default` if none found.
func fetch(section: String, key: String, default = null):
	return provider.fetch(section, key, default)


# purge(section: String = "", key: String = "") -> bool
# Delete specified `section` and/or `key` from the file system.
# @param section (String): Optional section name, delete all sections if missing.
# @oaram key (String): Optional key name, delete all keys if missing.
# @return success (bool): The purge succeeded
func purge(section := "", key := "") -> bool:
	return provider.purge(section, key)


# get_sections() -> PoolStringArray
# Get all sections available.
# @return sections (String): All sections available.
func get_sections() -> PoolStringArray:
	return provider.get_sections()


# get_keys(section: String) -> PoolStringArray
# Get all keys for the named `section`.
# @param section (String): The name of the section.
# @return keys (String): All keys in the section.
func get_keys(section: String) -> PoolStringArray:
	return provider.get_keys(section)
