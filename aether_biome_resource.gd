@tool
extends Resource
class_name AetherBiomeResource

## Data-only biome definition for AetherTerrainBiomes.
## Kept modular so gameplay systems can read these values directly.

@export_group("Identity")
@export var biome_name: String = "New Biome"
@export var editor_color: Color = Color(0.5, 0.7, 0.5, 1.0)
@export var locked: bool = false
@export var unlock_story_flag: StringName = &""
@export var unlock_base_upgrade: StringName = &""

@export_group("Noise")
@export_range(0.0001, 1.0, 0.0001) var frequency: float = 0.008
@export_range(1, 12, 1) var octaves: int = 5
@export_range(1.0, 4.0, 0.01) var lacunarity: float = 2.0
@export_range(0.0, 1.0, 0.01) var gain: float = 0.5
@export_range(0.0, 2048.0, 0.1) var height_multiplier: float = 120.0
@export var seed_offset: int = 0

@export_group("Texture Layer Rules")
@export_range(0, 32, 1) var base_texture_index: int = 0
@export_range(-1, 32, 1) var detail_texture_index: int = -1
@export_range(-1, 32, 1) var cliff_texture_index: int = -1
@export var base_texture_path: String = ""
@export var detail_texture_path: String = ""
@export var cliff_texture_path: String = ""
@export var slope_based_blending: bool = true
@export_range(0.0, 90.0, 0.1) var slope_blend_start_degrees: float = 20.0
@export_range(0.0, 90.0, 0.1) var slope_blend_end_degrees: float = 45.0
@export var height_based_blending: bool = true
@export_range(-1024.0, 4096.0, 0.1) var height_blend_start: float = 5.0
@export_range(-1024.0, 4096.0, 0.1) var height_blend_end: float = 120.0
@export_range(0.0, 1.0, 0.01) var texture_blend_strength: float = 1.0

@export_group("Foliage / Asset Spawn Tables")
@export var spawn_entries: Array[Dictionary] = []

@export_group("Biome Gameplay")
@export_range(0.0, 10.0, 0.01) var oxygen_drain_modifier: float = 1.0
@export_range(0.0, 10.0, 0.01) var threat_multiplier: float = 1.0


func to_noise(seed_base: int) -> FastNoiseLite:
    var noise := FastNoiseLite.new()
    noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
    noise.seed = seed_base + seed_offset
    noise.frequency = frequency
    noise.fractal_octaves = octaves
    noise.fractal_lacunarity = lacunarity
    noise.fractal_gain = gain
    return noise


func ensure_default_spawn_schema() -> void:
    ## Ensures each spawn entry has expected keys so generator code can stay branch-light.
    for i: int in range(spawn_entries.size()):
        var entry: Dictionary = spawn_entries[i]
        spawn_entries[i] = {
            "name": entry.get("name", "Spawn Entry"),
            "mesh": entry.get("mesh", null),
            "scene": entry.get("scene", null),
            "terrain_mesh_id": int(entry.get("terrain_mesh_id", -1)),
            "density": float(entry.get("density", 0.0015)),
            "min_scale": float(entry.get("min_scale", 0.85)),
            "max_scale": float(entry.get("max_scale", 1.35)),
            "noise_threshold": float(entry.get("noise_threshold", 0.55)),
            "min_height": float(entry.get("min_height", -10.0)),
            "max_height": float(entry.get("max_height", 2000.0)),
            "min_slope_deg": float(entry.get("min_slope_deg", 0.0)),
            "max_slope_deg": float(entry.get("max_slope_deg", 45.0)),
            "align_to_normal": bool(entry.get("align_to_normal", false)),
            "yaw_random": bool(entry.get("yaw_random", true)),
            "locked_to_biome": bool(entry.get("locked_to_biome", true)),
        }


func is_unlocked(story_flags: Dictionary, base_upgrades: Dictionary) -> bool:
    if not locked:
        return true
    if unlock_story_flag != &"" and bool(story_flags.get(unlock_story_flag, false)):
        return true
    if unlock_base_upgrade != &"" and bool(base_upgrades.get(unlock_base_upgrade, false)):
        return true
    return false
