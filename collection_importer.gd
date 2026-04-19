@tool
class_name AetherCollectionImporter
extends RefCounted

# Folder structure constants
const TERRAIN_TEXTURES_DIR := "res://textures/terrain"
const ASSETS_DIR := "res://assets"
const MODELS_SUBDIR := "models"
const SCENERY_SUBDIR := "scenery"

const MODEL_EXTS := ["glb", "gltf", "obj", "fbx"]
const TEXTURE_EXTS := ["png", "jpg", "jpeg", "webp", "exr", "tga"]

const ALBEDO_PATS := ["_albedo", "_diffuse", "_diff", "_basecolor", "_color"]
const NORMAL_PATS := ["_normal", "_norm", "_nor", "_nrm"]
const ROUGH_PATS := ["_roughness", "_rough", "_rgh"]
const DISP_PATS := ["_displacement", "_disp", "_height", "_heightmap"]

# Asset categories
const ASSET_CATEGORIES := {
	"trees": ["tree", "pine", "oak", "palm", "fir", "spruce", "trunk"],
	"rocks": ["rock", "stone", "boulder", "cliff", "pebble"],
	"foliage": ["grass", "plant", "bush", "fern", "flower", "shrub"],
	"logs": ["log", "wood", "stump", "dead"],
	"debris": ["twig", "branch", "stick", "leaves", "moss"],
}

## Import terrain PBR textures
## Returns: {ok, count, error}
static func import_terrain_textures(folder: String) -> Dictionary:
	var result := {"ok": false, "count": 0, "error": ""}
	
	if folder.is_empty():
		result["error"] = "Empty folder"
		return result
	
	var abs_path := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(abs_path):
		result["error"] = "Folder not found: " + abs_path
		return result
	
	# Scan for texture files
	var textures: Array = []
	_scan_textures(folder, textures)
	
	if textures.is_empty():
		result["error"] = "No texture files found (png, jpg, exr)"
		return result
	
	# Create terrain textures folder
	var dest := ProjectSettings.globalize_path(TERRAIN_TEXTURES_DIR)
	DirAccess.make_dir_recursive_absolute(dest)
	
	# Copy textures to terrain folder
	var copied: int = 0
	for i: int in range(textures.size()):
		var tex: Dictionary = textures[i]
		var src: String = tex.get("path", "")
		var name: String = tex.get("name", "")
		var ext: String = tex.get("ext", "png")
		var dst: String = "%s/%s.%s" % [TERRAIN_TEXTURES_DIR, name, ext]
		if not src.is_empty() and _copy_file(src, dst):
			copied += 1
	
	result["ok"] = true
	result["count"] = copied
	return result


## Import 3D asset models
## Returns: {ok, imported, error, categories: {cat: count}}
static func import_asset_models(folder: String, use_subfolders: bool = true) -> Dictionary:
	var result := {"ok": false, "imported": 0, "error": "", "categories": {}}
	
	if folder.is_empty():
		result["error"] = "Empty folder"
		return result
	
	var abs_path := ProjectSettings.globalize_path(folder)
	if not DirAccess.dir_exists_absolute(abs_path):
		result["error"] = "Folder not found"
		return result
	
	var models: Array = []
	_scan_models(folder, models)
	
	if models.is_empty():
		result["error"] = "No model files found (glb, gltf, obj, fbx)"
		return result
	
	# Categorize
	var cats := _categorize_models(models)
	
	# Create folder structure
	var dest_base := ASSETS_DIR
	if use_subfolders:
		for cat: String in cats.keys():
			var cat_folder := "%s/%s/%s" % [dest_base, MODELS_SUBDIR, cat]
			var abs_cat := ProjectSettings.globalize_path(cat_folder)
			DirAccess.make_dir_recursive_absolute(abs_cat)
			result["categories"][cat] = cats[cat].size()
			result["imported"] = result["imported"] + cats[cat].size()
	else:
		# All in one folder
		var dest := ProjectSettings.globalize_path(dest_base + "/" + MODELS_SUBDIR)
		DirAccess.make_dir_recursive_absolute(dest)
		result["categories"]["all"] = models.size()
		result["imported"] = models.size()
	
	result["ok"] = true
	return result


## Get terrain textures folder path
static func get_terrain_folder() -> String:
	return TERRAIN_TEXTURES_DIR


## Get assets folder path
static func get_assets_folder(subfolder: String = "") -> String:
	if subfolder.is_empty():
		return ASSETS_DIR
	return "%s/%s" % [ASSETS_DIR, subfolder]


## Get available asset categories
static func get_asset_categories() -> Array:
	return ASSET_CATEGORIES.keys()


# Private scanning functions
static func _scan_textures(path: String, textures: Array) -> void:
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
			_scan_textures(child, textures)
		else:
			var ext := name.get_extension().to_lower()
			if TEXTURE_EXTS.has(ext):
				textures.append({"path": child, "name": name.get_basename(), "ext": ext})
		name = dir.get_next()
	dir.list_dir_end()


static func _scan_models(path: String, models: Array) -> void:
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
			_scan_models(child, models)
		else:
			var ext := name.get_extension().to_lower()
			if MODEL_EXTS.has(ext):
				models.append({"path": child, "name": name.get_basename()})
		name = dir.get_next()
	dir.list_dir_end()


static func _categorize_models(models: Array) -> Dictionary:
	var cats := {}
	for m: Dictionary in models:
		var name_val: String = String(m.get("name", "")).to_lower()
		var cat := "props"
		for c: String in ASSET_CATEGORIES.keys():
			for kw: String in ASSET_CATEGORIES[c]:
				if name_val.find(kw) >= 0:
					cat = c
					break
			if cat != "props":
				break
		if not cats.has(cat):
			cats[cat] = []
		cats[cat].append(m)
	return cats


static func _copy_file(src: String, dst: String) -> bool:
	var src_f := FileAccess.open(src, FileAccess.READ)
	if src_f == null:
		return false
	var dst_f := FileAccess.open(dst, FileAccess.WRITE)
	if dst_f == null:
		return false
	dst_f.resize(src_f.get_length())
	dst_f.store_buffer(src_f.get_buffer(src_f.get_length()))
	dst_f.close()
	src_f.close()
	return true


static func get_summary(result: Dictionary) -> String:
	if not result.get("ok", false):
		return "Error: " + result.get("error", "Unknown")
	var lines := PackedStringArray()
	if result.has("count"):
		lines.append("Terrain textures: %d" % result["count"])
	if result.has("imported"):
		lines.append("Imported %d models:" % result["imported"])
		for c: String in result.get("categories", {}).keys():
			lines.append("  - %s: %d" % [c, result["categories"][c]])
	return "\n".join(lines)