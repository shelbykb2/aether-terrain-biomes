@tool
class_name AetherCollectionImporter
extends RefCounted

const MODEL_EXTS := ["glb", "gltf", "obj", "fbx"]
const TEXTURE_EXTS := ["png", "jpg", "jpeg", "webp", "exr", "tga"]

const ALBEDO_PATS := ["_albedo", "_diffuse", "_diff", "_basecolor", "_color"]
const NORMAL_PATS := ["_normal", "_norm", "_nor", "_nrm"]
const ROUGH_PATS := ["_roughness", "_rough", "_rgh"]
const DISP_PATS := ["_displacement", "_disp", "_height", "_heightmap"]

const CATEGORIES := {
	"trees": ["tree", "pine", "oak", "palm", "fir", "spruce"],
	"rocks": ["rock", "stone", "boulder", "cliff"],
	"foliage": ["grass", "plant", "bush", "fern", "flower"],
	"logs": ["log", "wood", "stump"],
	"ground": ["ground", "dirt", "soil"],
}

static func import_collection(folder: String, dest: String = "res://assets") -> Dictionary:
	var result := {"ok": false, "imported": 0, "error": "", "cats": {}}
	
	if folder.is_empty():
		result["error"] = "Empty folder"
		return result
	
	var abs_path := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(abs_path):
		result["error"] = "Folder not found"
		return result
	
	var models: Array = []
	_scan_folder(folder, models)
	
	if models.is_empty():
		result["error"] = "No models found"
		return result
	
	# Categorize
	var cats := _categorize(models)
	
	# Create folders and import
	for cat: String in cats.keys():
		var cat_folder := "%s/%s" % [dest, cat]
		var abs_cat := ProjectSettings.globalize_path(cat_folder)
		DirAccess.make_dir_recursive_absolute(abs_cat)
		result["cats"][cat] = cats[cat].size()
		result["imported"] = result["imported"] + cats[cat].size()
	
	result["ok"] = true
	return result

static func _scan_folder(path: String, models: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child := "%s/%s" % [path.trim_suffix("/"), name]
		if dir.current_is_dir():
			_scan_folder(child, models)
		else:
			var ext := name.get_extension().to_lower()
			if MODEL_EXTS.has(ext):
				models.append({"path": child, "name": name.get_basename()})
		name = dir.get_next()
	dir.list_dir_end()

static func _categorize(models: Array) -> Dictionary:
	var cats := {}
	for m: Dictionary in models:
		var name_val: String = String(m.get("name", ""))
		var n := name_val.to_lower()
		var cat := "props"
		for c: String in CATEGORIES.keys():
			for kw: String in CATEGORIES[c]:
				if n.find(kw) >= 0:
					cat = c
					break
			if cat != "props":
				break
		if not cats.has(cat):
			cats[cat] = []
		cats[cat].append(m)
	return cats

static func get_summary(result: Dictionary) -> String:
	if not result.get("ok", false):
		return "Error: " + result.get("error", "Unknown")
	var lines := PackedStringArray()
	lines.append("Imported %d models:" % result.get("imported", 0))
	for c: String in result.get("cats", {}).keys():
		lines.append("  - %s: %d" % [c, result["cats"][c]])
	return "\n".join(lines)