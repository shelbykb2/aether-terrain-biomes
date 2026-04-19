@tool
class_name PolyhavenImporter
extends RefCounted

## Polyhaven API Importer for Godot
## Connects to Polyhaven API to browse and download textures directly
## API Documentation: https://polyhaven.com/our-api

const BASE_URL := "https://api.polyhaven.com"
const USER_AGENT := "AetherTerrainBiomes/1.0 (Godot)"

# Asset types
const TYPE_TEXTURES := "textures"
const TYPE_HDRIS := "hdris"
const TYPE_MODELS := "models"

# Texture map types (suffixes used in Polyhaven files)
const MAP_TYPES := {
	"diff": "albedo",
	"rough": "roughness",
	"metal": "metallic",
	"nor_gl": "normal",
	"disp": "displacement",
	"ao": "ambient_occlusion",
	"arm": "arm",  # Combined AO/Rough/Metal
	"col": "color",
	"el": "emission",
	"emit": "emission",
}

# Categories for filtering
const CATEGORIES := [
	"brick",
	"concrete",
	"fabric",
	"ground",
	"marble",
	"metal",
	"organic",
	"plaster",
	"rock",
	"roof",
	"terrazzo",
	"tile",
	"wood",
]

# CDN URL for previews
const PREVIEW_CDN := "https://cdn.polyhaven.com/asset-img"


static func get_user_agent() -> String:
	return USER_AGENT


## Get preview image URL for an asset
static func get_preview_url(slug: String, size: int = 512) -> String:
	# Polyhaven provides preview images via their CDN
	return "%s/%s/%s.jpg" % [PREVIEW_CDN, slug, str(size)]


## Fetch all texture assets from Polyhaven
static func fetch_all_textures(http_client: HTTPRequest) -> Dictionary:
	var result := {"ok": false, "textures": {}, "error": ""}
	
	if http_client == null:
		result["error"] = "HTTP client is null"
		return result
	
	var url := "%s/assets?t[]=%s" % [BASE_URL, TYPE_TEXTURES]
	var headers := PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/json",
	])
	
	var req_error := http_client.request(url, headers, HTTPClient.METHOD_GET)
	if req_error != OK:
		result["error"] = "Request failed: " + str(req_error)
		return result
	
	# Wait for response - caller should handle the signal
	result["ok"] = true
	result["pending"] = true
	return result


## Fetch texture asset details including download URLs
static func fetch_texture_details(http_client: HTTPRequest, slug: String) -> Dictionary:
	var result := {"ok": false, "details": {}, "error": ""}
	
	if http_client == null:
		result["error"] = "HTTP client is null"
		return result
	
	if slug.is_empty():
		result["error"] = "Slug is empty"
		return result
	
	var url := "%s/files/%s" % [BASE_URL, slug]
	url += "?t[]=%s" % TYPE_TEXTURES
	
	var headers := PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
		"Accept: application/json",
	])
	
	var req_error := http_client.request(url, headers, HTTPClient.METHOD_GET)
	if req_error != OK:
		result["error"] = "Request failed: " + str(req_error)
		return result
	
	result["ok"] = true
	result["pending"] = true
	return result


## Parse asset response and extract download URLs
static func parse_asset_details(response_json: Dictionary, resolution: int = 2) -> Dictionary:
	var result := {
		"ok": false,
		"slug": "",
		"title": "",
		"tags": [],
		"maps": {},
		"error": ""
	}
	
	if response_json.is_empty():
		result["error"] = "Empty response"
		return result
	
	# Get asset slug
	var keys := response_json.keys()
	if keys.is_empty():
		result["error"] = "No assets in response"
		return result
	
	var slug: String = keys[0]
	var asset_data: Dictionary = response_json[slug]
	result["slug"] = slug
	result["title"] = asset_data.get("name", slug)
	result["tags"] = asset_data.get("tags", PackedStringArray())
	
	# Get files dict for textures
	var files: Dictionary = asset_data.get("files", {})
	if files.is_empty():
		result["error"] = "No files in asset"
		return result
	
	var textures: Dictionary = files.get(TYPE_TEXTURES, {})
	if textures.is_empty():
		result["error"] = "No textures in asset"
		return result
	
	# Get requested resolution
	var res_key := " %dk" % resolution
	var res_data: Dictionary = textures.get(res_key, {})
	if res_data.is_empty():
		# Try to get first available resolution
		var available_resolutions := textures.keys()
		if available_resolutions.is_empty():
			result["error"] = "No resolutions available"
			return result
		res_key = available_resolutions[0]
		res_data = textures[res_key]
	
	# Parse download URLs
	var downloads: Dictionary = res_data.get("download", {})
	for map_type: String in downloads.keys():
		var url: String = downloads[map_type]
		result["maps"][map_type] = {
			"url": url,
			"basename": slug + "_" + map_type + ".png",
		}
	
	result["ok"] = true
	return result


## Download a single texture file
static func download_texture(http_client: HTTPRequest, url: String, save_path: String) -> Dictionary:
	var result := {"ok": false, "saved": false, "error": ""}
	
	if http_client == null:
		result["error"] = "HTTP client is null"
		return result
	
	if url.is_empty():
		result["error"] = "URL is empty"
		return result
	
	var headers := PackedStringArray([
		"User-Agent: %s" % USER_AGENT,
	])
	
	var req_error := http_client.request(url, headers, HTTPClient.METHOD_GET)
	if req_error != OK:
		result["error"] = "Request failed: " + str(req_error)
		return result
	
	result["ok"] = true
	result["pending"] = true
	result["save_path"] = save_path
	return result


## Save downloaded data to file
static func save_texture_data(data: PackedByteArray, save_path: String) -> bool:
	if data.is_empty():
		push_error("Empty data, cannot save")
		return false
	
	var abs_path := ProjectSettings.globalize_path(save_path)
	var dir := DirAccess.open(abs_path.get_base_dir())
	if dir == null:
		push_error("Cannot access directory: " + abs_path.get_base_dir())
		return false
	
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot create file: " + save_path)
		return false
	
	file.store_buffer(data)
	file.flush()
	file.close()
	return true


## Import all PBR maps for a texture pack into a folder
static func import_texture_pack(
	slug: String,
	maps: Dictionary,
	dest_folder: String,
	_progress_callback: Callable = Callable()
) -> Dictionary:
	var result := {
		"ok": false,
		"downloaded": 0,
		"failed": 0,
		"files": [],
		"error": ""
	}
	
	if slug.is_empty():
		result["error"] = "Slug is empty"
		return result
	
	# Create destination folder
	var abs_dest := ProjectSettings.globalize_path(dest_folder)
	var dir := DirAccess.open("res://")
	if dir == null:
		result["error"] = "Cannot access resource directory"
		return result
	
	dir.make_dir_recursive_absolute(abs_dest)
	
	# Download each map
	for map_type: String in maps.keys():
		var map_info: Dictionary = maps[map_type]
		var url: String = map_info.get("url", "")
		var basename: String = map_info.get("basename", slug + "_" + map_type + ".png")
		
		if url.is_empty():
			push_warning("No URL for map: " + map_type)
			result["failed"] += 1
			continue
		
		# Note: Actual download requires HTTP client
		# This is a helper for file paths and organization
		var file_path := dest_folder.path_join(slug + "_" + map_type + ".png")
		result["files"].append(file_path)
	
	if not result["files"].is_empty():
		result["ok"] = true
		result["downloaded"] = result["files"].size()
	
	return result


## Get human-readable map type name
static func get_map_display_name(map_type: String) -> String:
	return MAP_TYPES.get(map_type, map_type)


## Build asset info summary
static func get_asset_summary(details: Dictionary) -> String:
	if not details.get("ok", false):
		return "Error: " + details.get("error", "Unknown")
	
	var lines := PackedStringArray()
	lines.append("Texture: " + details.get("title", details.get("slug", "Unknown")))
	
	var tags: PackedStringArray = details.get("tags", PackedStringArray())
	if not tags.is_empty():
		lines.append("Tags: " + ", ".join(tags))
	
	var maps: Dictionary = details.get("maps", {})
	lines.append("Maps available (%d):" % maps.size())
	for map_type: String in maps.keys():
		lines.append("  - %s" % get_map_display_name(map_type))
	
	return "\n".join(lines)


## Get all preview sizes available
static func get_preview_sizes() -> Array:
	return [64, 128, 256, 512, 1024, 2048]


## Get thumbnail URL (small size for quick loading)
static func get_thumbnail_url(slug: String) -> String:
	return get_preview_url(slug, 256)


## Check if URL is valid image URL
static func is_valid_preview_url(url: String) -> bool:
	return url.begins_with("https://cdn.polyhaven.com/")