extends Resource

enum StorageProviderType { DIRECTORY, DIRECTORY_V2, FILES, FILE }

const DIRECTORY_NAME := "application/storage/directory"
const DIRECTORY_DEFAULT := "user://data"
const DEBUG_FILENAMES_NAME := "application/storage/debug_filenames"
const DEBUG_FILENAMES_DEFAULT := true
const STORAGE_PROVIDER_NAME := "application/storage/provider"
const STORAGE_PROVIDER_DEFAULT := StorageProviderType.DIRECTORY_V2


static func enum_to_hint(enumeration: Dictionary) -> String:
	return PoolStringArray(enumeration.keys()).join(",")


static func create_project_settings() -> void:
	create_project_setting(
		DIRECTORY_NAME, DIRECTORY_DEFAULT, PROPERTY_HINT_PLACEHOLDER_TEXT, DIRECTORY_DEFAULT
	)
	create_project_setting(DEBUG_FILENAMES_NAME, DEBUG_FILENAMES_DEFAULT)
	create_project_setting(
		STORAGE_PROVIDER_NAME,
		STORAGE_PROVIDER_DEFAULT,
		PROPERTY_HINT_ENUM,
		enum_to_hint(StorageProviderType)
	)


static func clear_project_settings() -> void:
	ProjectSettings.clear(DIRECTORY_NAME)
	ProjectSettings.clear(DEBUG_FILENAMES_NAME)
	ProjectSettings.clear(STORAGE_PROVIDER_NAME)


static func create_project_setting(
	name: String, default, hint: int = PROPERTY_HINT_NONE, hint_string := ""
) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default)

	ProjectSettings.set_initial_value(name, default)
	var info = {
		"name": name,
		"type": typeof(default),
		"hint": hint,
		"hint_string": hint_string,
	}
	ProjectSettings.add_property_info(info)


static func get_setting(name: String, default):
	if ProjectSettings.has_setting(name):
		return ProjectSettings.get_setting(name)
	return default


static func get_directory() -> String:
	return get_setting(DIRECTORY_NAME, DIRECTORY_DEFAULT)


static func get_debug_filenames() -> bool:
	return get_setting(DEBUG_FILENAMES_NAME, DEBUG_FILENAMES_DEFAULT)


static func get_storage_provider() -> int:
	return get_setting(STORAGE_PROVIDER_NAME, STORAGE_PROVIDER_DEFAULT)
