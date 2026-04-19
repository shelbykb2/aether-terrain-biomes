@tool
extends PanelContainer
class_name AetherTerrainBiomesPanel

signal generate_terrain_requested
signal apply_surface_requested
signal import_all_textures_assign_requested
signal clear_all_requested
signal flatten_safe_zone_requested
signal add_biome_requested
signal remove_biome_requested(index: int)

var _biome_list: ItemList
var _map_size_spin: SpinBox
var _world_size_spin: SpinBox
var _seed_spin: SpinBox
var _procedural_blend_spin: SpinBox
var _painted_blend_spin: SpinBox
var _weight_sharpness_spin: SpinBox
var _spike_threshold_spin: SpinBox
var _spike_softness_spin: SpinBox
var _smoothing_passes_spin: SpinBox
var _status_label: Label
var _biome_preview_rect: TextureRect

var _biome_name_edit: LineEdit
var _texture_index_spin: SpinBox
var _detail_texture_spin: SpinBox
var _cliff_texture_spin: SpinBox
var _base_tex_path_edit: LineEdit
var _detail_tex_path_edit: LineEdit
var _cliff_tex_path_edit: LineEdit
var _texture_strength_spin: SpinBox
var _slope_enabled_check: CheckBox
var _slope_start_spin: SpinBox
var _slope_end_spin: SpinBox
var _height_enabled_check: CheckBox
var _height_start_spin: SpinBox
var _height_end_spin: SpinBox
var _height_mult_spin: SpinBox
var _frequency_spin: SpinBox
var _octaves_spin: SpinBox
var _lacunarity_spin: SpinBox
var _gain_spin: SpinBox

var _spawn_entry_list: ItemList
var _texture_root_edit: LineEdit
var _available_texture_list: ItemList
var _asset_root_edit: LineEdit
var _available_assets_list: ItemList
var _spawn_scene_path_edit: LineEdit
var _spawn_mesh_id_spin: SpinBox
var _spawn_density_spin: SpinBox
var _spawn_min_scale_spin: SpinBox
var _spawn_max_scale_spin: SpinBox
var _available_asset_paths: PackedStringArray = []
var _available_texture_paths: PackedStringArray = []

const ASSET_SCENE_EXTENSIONS := ["tscn", "scn", "glb"]
const GROUND_TEXTURE_EXTENSIONS := ["png", "jpg", "jpeg", "webp", "exr", "ktx", "dds", "tga"]

var _biomes: Array[AetherBiomeResource] = []
var _selected_biome_idx: int = -1
var _suppress_events: bool = false
var _last_dominant_biome_image: Image


func _resolve_nodes() -> bool:
    _biome_list = find_child("BiomeList", true, false) as ItemList
    _map_size_spin = find_child("MapSizeSpin", true, false) as SpinBox
    _world_size_spin = find_child("WorldSizeSpin", true, false) as SpinBox
    _seed_spin = find_child("SeedSpin", true, false) as SpinBox
    _procedural_blend_spin = find_child("ProceduralBlendSpin", true, false) as SpinBox
    _painted_blend_spin = find_child("PaintedBlendSpin", true, false) as SpinBox
    _weight_sharpness_spin = find_child("WeightSharpnessSpin", true, false) as SpinBox
    _spike_threshold_spin = find_child("SpikeThresholdSpin", true, false) as SpinBox
    _spike_softness_spin = find_child("SpikeSoftnessSpin", true, false) as SpinBox
    _smoothing_passes_spin = find_child("SmoothingPassesSpin", true, false) as SpinBox
    _status_label = find_child("StatusLabel", true, false) as Label
    _biome_preview_rect = find_child("BiomePreviewRect", true, false) as TextureRect

    _biome_name_edit = find_child("BiomeNameEdit", true, false) as LineEdit
    _texture_index_spin = find_child("TextureIndexSpin", true, false) as SpinBox
    _detail_texture_spin = find_child("DetailTextureSpin", true, false) as SpinBox
    _cliff_texture_spin = find_child("CliffTextureSpin", true, false) as SpinBox
    _base_tex_path_edit = find_child("BaseTexPathEdit", true, false) as LineEdit
    _detail_tex_path_edit = find_child("DetailTexPathEdit", true, false) as LineEdit
    _cliff_tex_path_edit = find_child("CliffTexPathEdit", true, false) as LineEdit
    _texture_strength_spin = find_child("TextureStrengthSpin", true, false) as SpinBox
    _slope_enabled_check = find_child("SlopeEnabledCheck", true, false) as CheckBox
    _slope_start_spin = find_child("SlopeStartSpin", true, false) as SpinBox
    _slope_end_spin = find_child("SlopeEndSpin", true, false) as SpinBox
    _height_enabled_check = find_child("HeightEnabledCheck", true, false) as CheckBox
    _height_start_spin = find_child("HeightStartSpin", true, false) as SpinBox
    _height_end_spin = find_child("HeightEndSpin", true, false) as SpinBox
    _height_mult_spin = find_child("HeightMultSpin", true, false) as SpinBox
    _frequency_spin = find_child("FrequencySpin", true, false) as SpinBox
    _octaves_spin = find_child("OctavesSpin", true, false) as SpinBox
    _lacunarity_spin = find_child("LacunaritySpin", true, false) as SpinBox
    _gain_spin = find_child("GainSpin", true, false) as SpinBox

    _spawn_entry_list = find_child("SpawnEntryList", true, false) as ItemList
    _texture_root_edit = find_child("TextureRootEdit", true, false) as LineEdit
    _available_texture_list = find_child("AvailableTextureList", true, false) as ItemList
    _asset_root_edit = find_child("AssetRootEdit", true, false) as LineEdit
    _available_assets_list = find_child("AvailableAssetsList", true, false) as ItemList
    _spawn_scene_path_edit = find_child("SpawnScenePathEdit", true, false) as LineEdit
    _spawn_mesh_id_spin = find_child("SpawnMeshIdSpin", true, false) as SpinBox
    _spawn_density_spin = find_child("SpawnDensitySpin", true, false) as SpinBox
    _spawn_min_scale_spin = find_child("SpawnMinScaleSpin", true, false) as SpinBox
    _spawn_max_scale_spin = find_child("SpawnMaxScaleSpin", true, false) as SpinBox

    return _biome_list != null \
        and _map_size_spin != null \
        and _world_size_spin != null \
        and _seed_spin != null \
        and _procedural_blend_spin != null \
        and _painted_blend_spin != null \
        and _weight_sharpness_spin != null \
        and _spike_threshold_spin != null \
        and _spike_softness_spin != null \
        and _smoothing_passes_spin != null \
        and _status_label != null \
        and _biome_preview_rect != null \
        and _biome_name_edit != null \
        and _texture_index_spin != null \
        and _detail_texture_spin != null \
        and _cliff_texture_spin != null \
        and _base_tex_path_edit != null \
        and _detail_tex_path_edit != null \
        and _cliff_tex_path_edit != null \
        and _texture_strength_spin != null \
        and _slope_enabled_check != null \
        and _slope_start_spin != null \
        and _slope_end_spin != null \
        and _height_enabled_check != null \
        and _height_start_spin != null \
        and _height_end_spin != null \
        and _height_mult_spin != null \
        and _frequency_spin != null \
        and _octaves_spin != null \
        and _lacunarity_spin != null \
        and _gain_spin != null \
        and _spawn_entry_list != null \
        and _texture_root_edit != null \
        and _available_texture_list != null \
        and _asset_root_edit != null \
        and _available_assets_list != null \
        and _spawn_scene_path_edit != null \
        and _spawn_mesh_id_spin != null \
        and _spawn_density_spin != null \
        and _spawn_min_scale_spin != null \
        and _spawn_max_scale_spin != null


func setup_default_values() -> void:
    if not _resolve_nodes():
        call_deferred("setup_default_values")
        return

    _suppress_events = true
    _map_size_spin.value = 1024
    _world_size_spin.value = 2048.0
    _seed_spin.value = 1337
    _procedural_blend_spin.value = 1.0
    _painted_blend_spin.value = 0.0
    _weight_sharpness_spin.value = 2.4
    _spike_threshold_spin.value = 12.0
    _spike_softness_spin.value = 0.68
    _smoothing_passes_spin.value = 2
    _texture_root_edit.text = "res://textures/terrain"
    _asset_root_edit.text = "res://imported_models"
    _spawn_mesh_id_spin.value = -1
    _spawn_density_spin.value = 0.0015
    _spawn_min_scale_spin.value = 0.85
    _spawn_max_scale_spin.value = 1.35
    _suppress_events = false

    _status_label.text = "Ready"
    _scan_available_textures()
    _scan_available_assets()


func set_biome_list(biomes: Array[AetherBiomeResource]) -> void:
    if not _resolve_nodes():
        call_deferred("set_biome_list", biomes)
        return

    _biomes = biomes
    _biome_list.clear()
    for biome: AetherBiomeResource in _biomes:
        var idx: int = _biome_list.add_item(biome.biome_name)
        _biome_list.set_item_custom_bg_color(idx, biome.editor_color.darkened(0.4))
        _biome_list.set_item_custom_fg_color(idx, Color.WHITE)

    if _biomes.is_empty():
        _selected_biome_idx = -1
        _clear_detail_fields()
        return

    _selected_biome_idx = clampi(_selected_biome_idx, 0, _biomes.size() - 1)
    if _selected_biome_idx < 0:
        _selected_biome_idx = 0
    _biome_list.select(_selected_biome_idx)
    _load_selected_biome_into_controls()
    _refresh_preview_texture()


func get_generation_options() -> Dictionary:
    if not _resolve_nodes():
        return {
            "map_size": 1024,
            "world_size_m": 2048.0,
            "seed": 1337,
            "procedural_blend": 1.0,
            "painted_blend": 0.0,
            "weight_sharpness": 2.4,
            "spike_threshold": 12.0,
            "spike_softness": 0.68,
            "smoothing_passes": 2,
        }

    return {
        "map_size": int(_map_size_spin.value),
        "world_size_m": float(_world_size_spin.value),
        "seed": int(_seed_spin.value),
        "procedural_blend": float(_procedural_blend_spin.value),
        "painted_blend": float(_painted_blend_spin.value),
        "weight_sharpness": float(_weight_sharpness_spin.value),
        "spike_threshold": float(_spike_threshold_spin.value),
        "spike_softness": float(_spike_softness_spin.value),
        "smoothing_passes": int(_smoothing_passes_spin.value),
    }


func set_status(text: String, is_error: bool = false) -> void:
    if not _resolve_nodes():
        call_deferred("set_status", text, is_error)
        return
    _status_label.text = text
    _status_label.modulate = Color(1.0, 0.4, 0.4) if is_error else Color(0.75, 0.95, 0.85)


func _on_biome_list_item_selected(index: int) -> void:
    _selected_biome_idx = index
    _load_selected_biome_into_controls()
    _refresh_preview_texture()


func set_biome_preview(dominant_biome_image: Image, biomes: Array[AetherBiomeResource]) -> void:
    _biomes = biomes
    if dominant_biome_image == null:
        _last_dominant_biome_image = null
        _biome_preview_rect.texture = null
        return

    _last_dominant_biome_image = dominant_biome_image.duplicate()
    _refresh_preview_texture()


func _refresh_preview_texture() -> void:
    if _biome_preview_rect == null:
        return
    if _last_dominant_biome_image == null:
        _biome_preview_rect.texture = null
        return

    var src: Image = _last_dominant_biome_image
    var preview := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
    for y: int in range(src.get_height()):
        for x: int in range(src.get_width()):
            var biome_idx: int = int(round(src.get_pixel(x, y).r * 255.0))
            var color := Color(0.15, 0.15, 0.15, 1.0)
            if biome_idx >= 0 and biome_idx < _biomes.size():
                color = _biomes[biome_idx].editor_color
                if _selected_biome_idx >= 0:
                    color = color if biome_idx == _selected_biome_idx else color.darkened(0.45)
            preview.set_pixel(x, y, color)

    var tex := ImageTexture.create_from_image(preview)
    _biome_preview_rect.texture = tex


func _load_selected_biome_into_controls() -> void:
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        _clear_detail_fields()
        return

    _suppress_events = true
    _biome_name_edit.text = biome.biome_name
    _texture_index_spin.value = biome.base_texture_index
    _detail_texture_spin.value = biome.detail_texture_index
    _cliff_texture_spin.value = biome.cliff_texture_index
    _base_tex_path_edit.text = biome.base_texture_path
    _detail_tex_path_edit.text = biome.detail_texture_path
    _cliff_tex_path_edit.text = biome.cliff_texture_path
    _texture_strength_spin.value = biome.texture_blend_strength
    _slope_enabled_check.button_pressed = biome.slope_based_blending
    _slope_start_spin.value = biome.slope_blend_start_degrees
    _slope_end_spin.value = biome.slope_blend_end_degrees
    _height_enabled_check.button_pressed = biome.height_based_blending
    _height_start_spin.value = biome.height_blend_start
    _height_end_spin.value = biome.height_blend_end
    _height_mult_spin.value = biome.height_multiplier
    _frequency_spin.value = biome.frequency
    _octaves_spin.value = biome.octaves
    _lacunarity_spin.value = biome.lacunarity
    _gain_spin.value = biome.gain
    _suppress_events = false

    _refresh_spawn_entries()


func _clear_detail_fields() -> void:
    _suppress_events = true
    _biome_name_edit.text = ""
    _texture_index_spin.value = 0
    _detail_texture_spin.value = -1
    _cliff_texture_spin.value = -1
    _base_tex_path_edit.text = ""
    _detail_tex_path_edit.text = ""
    _cliff_tex_path_edit.text = ""
    _texture_strength_spin.value = 1.0
    _slope_enabled_check.button_pressed = true
    _slope_start_spin.value = 20.0
    _slope_end_spin.value = 45.0
    _height_enabled_check.button_pressed = true
    _height_start_spin.value = 5.0
    _height_end_spin.value = 120.0
    _height_mult_spin.value = 120.0
    _frequency_spin.value = 0.008
    _octaves_spin.value = 5
    _lacunarity_spin.value = 2.0
    _gain_spin.value = 0.5
    _spawn_entry_list.clear()
    _spawn_scene_path_edit.text = ""
    _spawn_mesh_id_spin.value = -1
    _spawn_density_spin.value = 0.0015
    _spawn_min_scale_spin.value = 0.85
    _spawn_max_scale_spin.value = 1.35
    _suppress_events = false


func _get_selected_biome() -> AetherBiomeResource:
    if _selected_biome_idx < 0 or _selected_biome_idx >= _biomes.size():
        return null
    return _biomes[_selected_biome_idx]


func _refresh_biome_list_names() -> void:
    if _selected_biome_idx < 0:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        return
    _biome_list.set_item_text(_selected_biome_idx, biome.biome_name)


func _on_biome_name_edit_text_changed(new_text: String) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        return
    biome.biome_name = new_text.strip_edges()
    _refresh_biome_list_names()


func _on_texture_index_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.base_texture_index = int(value)


func _on_scan_textures_button_pressed() -> void:
    _scan_available_textures()


func _scan_available_textures() -> void:
    if not _resolve_nodes():
        return

    var root_path: String = _texture_root_edit.text.strip_edges()
    if root_path.is_empty():
        root_path = "res://"
        _texture_root_edit.text = root_path
    elif not root_path.begins_with("res://"):
        root_path = "res://%s" % root_path.trim_prefix("/")
        _texture_root_edit.text = root_path

    _available_texture_paths.clear()
    _available_texture_list.clear()

    var global_root: String = ProjectSettings.globalize_path(root_path)
    if not DirAccess.dir_exists_absolute(global_root):
        DirAccess.make_dir_recursive_absolute(global_root)

    _collect_texture_assets_recursive(root_path)
    _available_texture_paths.sort()
    for tex_path: String in _available_texture_paths:
        _available_texture_list.add_item(tex_path)

    set_status("Found %d textures under %s." % [_available_texture_paths.size(), root_path])


func _collect_texture_assets_recursive(folder_path: String) -> void:
    var dir: DirAccess = DirAccess.open(folder_path)
    if dir == null:
        return

    dir.list_dir_begin()
    var name: String = dir.get_next()
    while not name.is_empty():
        if name.begins_with("."):
            name = dir.get_next()
            continue

        var child_path: String = "%s/%s" % [folder_path.trim_suffix("/"), name]
        if dir.current_is_dir():
            _collect_texture_assets_recursive(child_path)
        else:
            var ext: String = name.get_extension().to_lower()
            if GROUND_TEXTURE_EXTENSIONS.has(ext) and ResourceLoader.exists(child_path, "Texture2D"):
                _available_texture_paths.append(child_path)

        name = dir.get_next()
    dir.list_dir_end()


func _on_assign_base_texture_button_pressed() -> void:
    _assign_selected_texture_to_slot("base")


func _on_assign_detail_texture_button_pressed() -> void:
    _assign_selected_texture_to_slot("detail")


func _on_assign_cliff_texture_button_pressed() -> void:
    _assign_selected_texture_to_slot("cliff")


func _on_import_all_textures_assign_button_pressed() -> void:
    emit_signal("import_all_textures_assign_requested")


func _assign_selected_texture_to_slot(slot: String) -> void:
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        set_status("Select a biome first.", true)
        return

    var selected: PackedInt32Array = _available_texture_list.get_selected_items()
    if selected.is_empty():
        set_status("Select a texture from the texture list first.", true)
        return

    var idx: int = selected[0]
    if idx < 0 or idx >= _available_texture_paths.size():
        return

    var path: String = _available_texture_paths[idx]
    match slot:
        "base":
            biome.base_texture_path = path
            _base_tex_path_edit.text = path
        "detail":
            biome.detail_texture_path = path
            _detail_tex_path_edit.text = path
        "cliff":
            biome.cliff_texture_path = path
            _cliff_tex_path_edit.text = path

    set_status("Assigned %s texture for '%s'. Generate to import/apply." % [slot, biome.biome_name])


func _on_detail_texture_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.detail_texture_index = int(value)


func _on_cliff_texture_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.cliff_texture_index = int(value)


func _on_texture_strength_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.texture_blend_strength = value


func _on_slope_enabled_check_toggled(toggled_on: bool) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.slope_based_blending = toggled_on


func _on_slope_start_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.slope_blend_start_degrees = value


func _on_slope_end_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.slope_blend_end_degrees = value


func _on_height_enabled_check_toggled(toggled_on: bool) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.height_based_blending = toggled_on


func _on_height_start_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.height_blend_start = value


func _on_height_end_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.height_blend_end = value


func _on_imported_root_button_pressed() -> void:
    _switch_asset_root("res://imported_models", false)


func _on_props_root_button_pressed() -> void:
    _switch_asset_root("res://props", true)


func _on_foliage_root_button_pressed() -> void:
    _switch_asset_root("res://props/foliage", true)


func _on_rocks_root_button_pressed() -> void:
    _switch_asset_root("res://props/rocks", true)


func _switch_asset_root(root_path: String, create_if_missing: bool) -> void:
    _asset_root_edit.text = root_path
    if create_if_missing:
        _ensure_directory_exists(root_path)
    _scan_available_assets()


func _ensure_directory_exists(res_path: String) -> void:
    var absolute: String = ProjectSettings.globalize_path(res_path)
    DirAccess.make_dir_recursive_absolute(absolute)


func _on_height_mult_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.height_multiplier = value


func _on_frequency_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.frequency = value


func _on_octaves_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.octaves = int(value)


func _on_lacunarity_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.lacunarity = value


func _on_gain_spin_value_changed(value: float) -> void:
    if _suppress_events:
        return
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome != null:
        biome.gain = value


func _on_scan_assets_button_pressed() -> void:
    _scan_available_assets()


func _scan_available_assets() -> void:
    if not _resolve_nodes():
        return

    var root_path: String = _asset_root_edit.text.strip_edges()
    if root_path.is_empty():
        root_path = "res://"
        _asset_root_edit.text = root_path
    elif not root_path.begins_with("res://"):
        root_path = "res://%s" % root_path.trim_prefix("/")
        _asset_root_edit.text = root_path

    _available_asset_paths.clear()
    _available_assets_list.clear()

    var global_root: String = ProjectSettings.globalize_path(root_path)
    if not DirAccess.dir_exists_absolute(global_root):
        set_status("Asset root not found: %s" % root_path, true)
        return

    _collect_scene_assets_recursive(root_path)
    _available_asset_paths.sort()

    for asset_path: String in _available_asset_paths:
        _available_assets_list.add_item(asset_path)

    set_status("Found %d loadable asset scenes under %s." % [_available_asset_paths.size(), root_path])


func _collect_scene_assets_recursive(folder_path: String) -> void:
    var dir: DirAccess = DirAccess.open(folder_path)
    if dir == null:
        return

    dir.list_dir_begin()
    var name: String = dir.get_next()
    while not name.is_empty():
        if name.begins_with("."):
            name = dir.get_next()
            continue

        var child_path: String = "%s/%s" % [folder_path.trim_suffix("/"), name]
        if dir.current_is_dir():
            _collect_scene_assets_recursive(child_path)
        else:
            var ext: String = name.get_extension().to_lower()
            if ASSET_SCENE_EXTENSIONS.has(ext) and ResourceLoader.exists(child_path, "PackedScene"):
                _available_asset_paths.append(child_path)

        name = dir.get_next()
    dir.list_dir_end()


func _on_available_assets_list_item_selected(index: int) -> void:
    _set_spawn_scene_from_asset_index(index)


func _on_apply_selected_asset_button_pressed() -> void:
    var selected_items: PackedInt32Array = _available_assets_list.get_selected_items()
    if selected_items.is_empty():
        set_status("Select an asset from the list first.", true)
        return
    _set_spawn_scene_from_asset_index(selected_items[0])


func _set_spawn_scene_from_asset_index(index: int) -> void:
    if index < 0 or index >= _available_asset_paths.size():
        return

    var scene_path: String = _available_asset_paths[index]
    _spawn_scene_path_edit.text = scene_path
    set_status("Selected asset: %s" % scene_path)


func _refresh_spawn_entries() -> void:
    _spawn_entry_list.clear()
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        return
    biome.ensure_default_spawn_schema()
    for entry: Dictionary in biome.spawn_entries:
        _spawn_entry_list.add_item(_spawn_entry_label(entry))


func _spawn_entry_label(entry: Dictionary) -> String:
    var name: String = String(entry.get("name", "Spawn"))
    var mesh_id: int = int(entry.get("terrain_mesh_id", -1))
    var density: float = float(entry.get("density", 0.0))
    return "%s | mesh_id=%d | density=%.4f" % [name, mesh_id, density]


func _on_spawn_entry_list_item_selected(index: int) -> void:
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        return
    if index < 0 or index >= biome.spawn_entries.size():
        return

    var entry: Dictionary = biome.spawn_entries[index]
    var scene_res: Variant = entry.get("scene", null)
    var scene_path: String = ""
    if scene_res is Resource:
        scene_path = String(scene_res.resource_path)

    _suppress_events = true
    _spawn_scene_path_edit.text = scene_path
    _spawn_mesh_id_spin.value = int(entry.get("terrain_mesh_id", -1))
    _spawn_density_spin.value = float(entry.get("density", 0.0015))
    _spawn_min_scale_spin.value = float(entry.get("min_scale", 0.85))
    _spawn_max_scale_spin.value = float(entry.get("max_scale", 1.35))
    _suppress_events = false


func _on_add_update_spawn_button_pressed() -> void:
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        set_status("Select a biome before editing asset entries.", true)
        return

    var entry: Dictionary = _build_spawn_entry_from_controls()
    var selected: int = _spawn_entry_list.get_selected_items()[0] if _spawn_entry_list.get_selected_items().size() > 0 else -1
    if selected >= 0 and selected < biome.spawn_entries.size():
        biome.spawn_entries[selected] = entry
    else:
        biome.spawn_entries.append(entry)

    _refresh_spawn_entries()
    set_status("Asset entry saved for biome '%s'." % biome.biome_name)


func _build_spawn_entry_from_controls() -> Dictionary:
    var scene_path: String = _spawn_scene_path_edit.text.strip_edges()
    var scene_res: PackedScene = null
    if not scene_path.is_empty() and ResourceLoader.exists(scene_path, "PackedScene"):
        scene_res = load(scene_path) as PackedScene

    return {
        "name": _entry_name_from_scene_path(scene_path),
        "mesh": null,
        "scene": scene_res,
        "terrain_mesh_id": int(_spawn_mesh_id_spin.value),
        "density": float(_spawn_density_spin.value),
        "min_scale": float(_spawn_min_scale_spin.value),
        "max_scale": float(_spawn_max_scale_spin.value),
        "noise_threshold": 0.55,
        "min_height": -10.0,
        "max_height": 2000.0,
        "min_slope_deg": 0.0,
        "max_slope_deg": 45.0,
        "align_to_normal": false,
        "yaw_random": true,
        "locked_to_biome": true,
    }


func _entry_name_from_scene_path(scene_path: String) -> String:
    if scene_path.is_empty():
        return "Spawn Entry"
    var name_with_ext: String = scene_path.get_file()
    return name_with_ext.get_basename()


func _on_remove_spawn_button_pressed() -> void:
    var biome: AetherBiomeResource = _get_selected_biome()
    if biome == null:
        return

    var selected: int = _spawn_entry_list.get_selected_items()[0] if _spawn_entry_list.get_selected_items().size() > 0 else -1
    if selected < 0 or selected >= biome.spawn_entries.size():
        return

    biome.spawn_entries.remove_at(selected)
    _refresh_spawn_entries()
    set_status("Removed asset entry from biome '%s'." % biome.biome_name)


func _on_add_biome_button_pressed() -> void:
    emit_signal("add_biome_requested")


func _on_remove_biome_button_pressed() -> void:
    emit_signal("remove_biome_requested", _selected_biome_idx)


func _on_generate_button_pressed() -> void:
    emit_signal("generate_terrain_requested")


func _on_apply_surface_button_pressed() -> void:
    emit_signal("apply_surface_requested")


func get_texture_root_path() -> String:
    if not _resolve_nodes():
        return "res://textures/terrain"
    var root_path: String = _texture_root_edit.text.strip_edges()
    if root_path.is_empty():
        return "res://textures/terrain"
    if not root_path.begins_with("res://"):
        root_path = "res://%s" % root_path.trim_prefix("/")
    return root_path


func _on_clear_button_pressed() -> void:
    emit_signal("clear_all_requested")


func _on_flatten_button_pressed() -> void:
    emit_signal("flatten_safe_zone_requested")


func _noop(_value: Variant = null) -> void:
    pass
