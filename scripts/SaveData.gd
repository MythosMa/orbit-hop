class_name SaveData
extends RefCounted

## Local persistence. On web, user:// maps to IndexedDB so progress survives reloads.

const SAVE_PATH := "user://orbithop.cfg"


static func best() -> int:
	return _read("best")


static func total_plays() -> int:
	return _read("plays")


static func _read(key: String) -> int:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return 0
	return int(c.get_value("score", key, 0))


static func record_run(score: int, new_best: bool) -> void:
	var c := ConfigFile.new()
	c.load(SAVE_PATH)
	var b := int(c.get_value("score", "best", 0))
	var plays := int(c.get_value("score", "plays", 0))
	c.set_value("score", "plays", plays + 1)
	if new_best or score > b:
		c.set_value("score", "best", maxi(b, score))
	c.save(SAVE_PATH)
