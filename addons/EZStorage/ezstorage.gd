extends Node

const Settings := preload("settings.gd")
const StorageProvider := preload("storage_provider.gd")
const DirectoryProvider := preload("directory_provider.gd")
const Directory2Provider := preload("directory2_provider.gd")
const FilesProvider := preload("files_provider.gd")
const FileProvider := preload("file_provider.gd")

var provider := get_storage_provider()


static func get_storage_provider() -> StorageProvider:
	match Settings.get_storage_provider():
		Settings.StorageProviderType.DIRECTORY:
			return DirectoryProvider.new()
		Settings.StorageProviderType.DIRECTORY_V2:
			return Directory2Provider.new()
		Settings.StorageProviderType.FILES:
			return FilesProvider.new()
		Settings.StorageProviderType.FILE:
			return FileProvider.new()

	return DirectoryProvider.new()


# set_directory_suffix(suffix: String, copy := false)
# Sets the directory suffix.
# Useful to seperate files between different users.
# @param suffix (String): the suffix appended to the root directory
# @param copy (bool): copies files from the existing storage to the new path
func set_directory_suffix(suffix: String, copy := false):
	provider.set_root(Settings.get_directory().plus_file(suffix), copy)


# store(section: String, key: String, value: Any) -> void:
# Stores `value` into the `key` of `section`.
# @param section (String): The name of the section.
# @param key (String): The name of the key.
# @param value (Any): The value to store.
func store(section: String, key: String, value) -> bool:
	return provider.store(section, key, value)


# fetch(section: String, key: String, default: Any = null) -> Any:
# Fetches values from the `key` of `section`.
# @param section (String): The name of the section.
# @param key (String): The name of the key.
# @param default (Any): The value returned if key/section does not exist.
# @return value (Any): The result or `default` if none found.
func fetch(section: String, key: String, default = null):
	return provider.fetch(section, key, default)


# purge(skip_sections: PoolStringArray = []) -> bool
# Delete all sections except those listed.
# @param skip_sections (PoolStringArray): Sections to skip.
# @return success (bool): The purge succeeded.
func purge(skip_sections: PoolStringArray = []) -> bool:
	return provider.purge(skip_sections)


# purge_section(section: String, skip_keys: PoolStringArray = []) -> bool
# Delete specified `section` from the file system.
# @param section (String): Section to delete.
# @param skip_keys (PoolStringArray): Keys to skip seleting..
# @return success (bool): The purge succeeded.
func purge_section(section: String, skip_keys: PoolStringArray = []) -> bool:
	return provider.purge_section(section, skip_keys)


# purge_section_key(section: String, key: String) -> bool
# Delete specified `section` `key` from the file system.
# @param section (String): Section name the key belongs to.
# @oaram key (String): Key to delete from the section.
# @return success (bool): The purge succeeded.
func purge_section_key(section: String, key: String) -> bool:
	return provider.purge_section_key(section, key)


func validate() -> bool:
	return provider.validate()
