tool
extends EditorPlugin

const Settings := preload("settings.gd")


func _enter_tree():
	Settings.create_project_settings()
	add_autoload_singleton("EZStorage", "res://addons/EZStorage/ezstorage.gd")
	add_autoload_singleton("EZCache", "res://addons/EZStorage/ezcache.gd")


func _exit_tree():
	remove_autoload_singleton("EZCache")
	remove_autoload_singleton("EZStorage")
	Settings.clear_project_settings()
