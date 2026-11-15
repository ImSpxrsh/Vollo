class_name ReplayStore
extends RefCounted

const DIR := "user://replays"
const KEEP := 15
const VERSION := 1

static var pending: Dictionary = {}

static func save(data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var path := "%s/%s_%d.replay" % [DIR, stamp, Time.get_ticks_msec() % 1000]
	data.version = VERSION
	data.saved_at = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_DEFLATE)
	if f == null:
		return ""
	f.store_var(data)
	f.close()
	_trim()
	return path

static func load_replay(path: String) -> Dictionary:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_DEFLATE)
	if f == null:
		return {}
	var data: Variant = f.get_var()
	f.close()
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != VERSION:
		return {}
	data.path = path
	return data

static func list() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".replay"):
			out.append("%s/%s" % [DIR, file])
	out.sort()
	out.reverse()
	return out

static func remove(path: String) -> void:
	DirAccess.remove_absolute(path)

static func _trim() -> void:
	var files := list()
	for i in range(KEEP, files.size()):
		remove(files[i])
