@tool
extends EditorPlugin

const PANEL_SCENE := preload("res://addons/aether_terrain_biomes/editor_panel.tscn")
const ICON_PATH := "res://addons/aether_terrain_biomes/icons/aether_biome.svg"

var _panel: AetherTerrainBiomesPanel
var _generator := AetherBiomeGenerator.new()
var _painter := AetherBiomePainter.new()
var _biomes: Array[AetherBiomeResource] = []


func _enter_tree() -> void:
    _panel = PANEL_SCENE.instantiate() as AetherTerrainBiomesPanel
    _panel.generate_terrain_requested.connect(_on_generate_requested)
    _panel.apply_surface_requested.connect(_on_apply_surface_requested)
    _panel.clear_all_requested.connect(_on_clear_requested)
    _panel.flatten_safe_zone_requested.connect(_on_flatten_safe_zone_requested)
    _panel.add_biome_requested.connect(_on_add_biome_requested)
    _panel.remove_biome_requested.connect(_on_remove_biome_requested)
    _panel.import_all_textures_assign_requested.connect(_on_import_all_textures_assign_requested)

    add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)
    _create_default_biomes_if_empty()
    _panel.call_deferred("setup_default_values")
    _panel.call_deferred("set_biome_list", _biomes)
    call_deferred("_refresh_preview")
    _panel.call_deferred("set_status", "Plugin loaded. Select world.tscn and generate.")


func _exit_tree() -> void:
    if _panel != null:
        remove_control_from_docks(_panel)
        _panel.queue_free()
        _panel = null


func _get_plugin_name() -> String:
    return "AetherTerrainBiomes"


func _get_plugin_icon() -> Texture2D:
    if ResourceLoader.exists(ICON_PATH):
        return load(ICON_PATH)
    return null


func _create_default_biomes_if_empty() -> void:
    if not _biomes.is_empty():
        return

    _biomes = [
        _build_default_biome("Landing Crater", Color(0.47, 0.8, 0.95), 0, 65.0, 5),
        _build_default_biome("Overgrowth Fringe", Color(0.33, 0.9, 0.48), 1, 115.0, 11),
        _build_default_biome("Rugged Highlands", Color(0.8, 0.6, 0.45), 2, 220.0, 19),
    ]


func _build_default_biome(name: String, color: Color, base_tex: int, height_mult: float, seed_offset: int) -> AetherBiomeResource:
    var biome := AetherBiomeResource.new()
    biome.biome_name = name
    biome.editor_color = color
    biome.base_texture_index = base_tex
    biome.height_multiplier = height_mult
    biome.seed_offset = seed_offset
    biome.locked = name != "Landing Crater"
    biome.unlock_story_flag = StringName("biome_%s_unlocked" % name.to_lower().replace(" ", "_"))
    if name == "Landing Crater":
        biome.frequency = 0.0028
        biome.octaves = 3
        biome.gain = 0.36
        biome.height_multiplier = 52.0
    elif name == "Overgrowth Fringe":
        biome.frequency = 0.0065
        biome.octaves = 5
        biome.gain = 0.54
        biome.height_multiplier = 88.0
    elif name == "Rugged Highlands":
        biome.frequency = 0.0115
        biome.octaves = 6
        biome.gain = 0.62
        biome.height_multiplier = 136.0
    return biome


func _on_add_biome_requested() -> void:
    var index: int = _biomes.size()
    var color := Color.from_hsv(float(index % 12) / 12.0, 0.65, 0.95)
    var biome := _build_default_biome("Biome %d" % (index + 1), color, index % 4, 96.0, index * 13)
    _biomes.append(biome)
    _panel.set_biome_list(_biomes)
    _refresh_preview()
    _panel.set_status("Added biome '%s'. Configure texture/assets and regenerate." % biome.biome_name)


func _on_remove_biome_requested(index: int) -> void:
    if index < 0 or index >= _biomes.size():
        return
    if _biomes.size() <= 1:
        _panel.set_status("At least one biome is required.", true)
        return

    var removed_name: String = _biomes[index].biome_name
    _biomes.remove_at(index)
    _panel.set_biome_list(_biomes)
    _refresh_preview()
    _panel.set_status("Removed biome '%s'." % removed_name)


func _on_generate_requested() -> void:
    var terrain: Node = _find_terrain_node()
    if terrain == null:
        _panel.set_status("No Terrain3D node found in edited scene.", true)
        return

    var texture_sync: Dictionary = _sync_biome_textures_to_terrain_assets(terrain)
    if not bool(texture_sync.get("ok", false)):
        _panel.set_status(String(texture_sync.get("error", "Unable to import biome textures.")), true)
        return

    var options: Dictionary = _panel.get_generation_options()
    _painter.ensure_masks(_biomes, int(options["map_size"]))
    options["painted_masks"] = _painter.get_masks()
    options["safe_zone_marker"] = _find_safe_zone_marker()
    options["safe_zone_radius"] = 92.0

    var result: Dictionary = _generator.generate_terrain(terrain, _biomes, options)
    if bool(result.get("ok", false)):
        _panel.set_biome_preview(result.get("dominant_biome_image", null), _biomes)
        _panel.set_status("Generation complete. Heightmap + biome passes applied.")
    else:
        _panel.set_status(String(result.get("error", "Unknown generation error.")), true)


func _on_apply_surface_requested() -> void:
    var terrain: Node = _find_terrain_node()
    if terrain == null:
        _panel.set_status("No Terrain3D node found in edited scene.", true)
        return

    var texture_sync: Dictionary = _sync_biome_textures_to_terrain_assets(terrain)
    if not bool(texture_sync.get("ok", false)):
        _panel.set_status(String(texture_sync.get("error", "Unable to import biome textures.")), true)
        return

    var options: Dictionary = _panel.get_generation_options()
    _painter.ensure_masks(_biomes, int(options["map_size"]))
    options["painted_masks"] = _painter.get_masks()

    var result: Dictionary = _generator.apply_surface_only(terrain, _biomes, options)
    if bool(result.get("ok", false)):
        _panel.set_biome_preview(result.get("dominant_biome_image", null), _biomes)
        _panel.set_status("Applied biome materials/assets without regenerating terrain height.")
    else:
        _panel.set_status(String(result.get("error", "Unknown surface apply error.")), true)


func _on_clear_requested() -> void:
    var map_size: int = int(_panel.get_generation_options().get("map_size", 1024))
    _painter.clear_masks(_biomes, map_size)
    _panel.set_status("Biome masks cleared. Regenerate when ready.")
    _refresh_preview()


func _on_flatten_safe_zone_requested() -> void:
    var terrain: Node = _find_terrain_node()
    if terrain == null:
        _panel.set_status("No Terrain3D node found in edited scene.", true)
        return

    var marker: Marker3D = _find_safe_zone_marker()
    if marker == null:
        _panel.set_status("Missing Marker3D named 'ShipSafeZoneMarker'.", true)
        return

    var opts: Dictionary = _panel.get_generation_options()
    var result: Dictionary = _generator.flatten_safe_zone_around_marker(
        terrain,
        marker,
        92.0,
        int(opts.get("map_size", 1024)),
        float(opts.get("world_size_m", 2048.0))
    )

    if bool(result.get("ok", false)):
        _panel.set_status("Safe zone flatten pass applied.")
    else:
        _panel.set_status(String(result.get("error", "Unable to flatten safe zone.")), true)


func _find_terrain_node() -> Node:
    var root: Node = get_editor_interface().get_edited_scene_root()
    if root == null:
        return null
    return _find_terrain_recursive(root)


func _find_terrain_recursive(node: Node) -> Node:
    if node == null:
        return null

    if node.get_class() == "Terrain3D":
        return node
    if String(node.name).to_lower() == "terrain3d":
        return node

    for child: Node in node.get_children():
        var found: Node = _find_terrain_recursive(child)
        if found != null:
            return found
    return null


func _find_safe_zone_marker() -> Marker3D:
    var root: Node = get_editor_interface().get_edited_scene_root()
    if root == null:
        return null
    return _find_marker_recursive(root)


func _find_marker_recursive(node: Node) -> Marker3D:
    if node is Marker3D and node.name == "ShipSafeZoneMarker":
        return node
    for child: Node in node.get_children():
        var found: Marker3D = _find_marker_recursive(child)
        if found != null:
            return found
    return null


func _refresh_preview() -> void:
    var options: Dictionary = _panel.get_generation_options()
    _painter.ensure_masks(_biomes, int(options["map_size"]))
    options["painted_masks"] = _painter.get_masks()
    var preview: Dictionary = _generator.build_biome_preview(_biomes, options)
    if bool(preview.get("ok", false)):
        _panel.set_biome_preview(preview.get("dominant_biome_image", null), _biomes)


func _sync_biome_textures_to_terrain_assets(terrain: Node) -> Dictionary:
    var assets: Object = _get_terrain_assets(terrain)
    if assets == null:
        return {"ok": false, "error": "Terrain3D assets not found on terrain node."}
    if not assets.has_method("set_texture"):
        return {"ok": false, "error": "Terrain3D assets do not expose set_texture."}

    for biome: AetherBiomeResource in _biomes:
        biome.base_texture_index = _resolve_texture_slot(assets, biome.base_texture_path, biome.base_texture_index)
        biome.detail_texture_index = _resolve_texture_slot(assets, biome.detail_texture_path, biome.detail_texture_index)
        biome.cliff_texture_index = _resolve_texture_slot(assets, biome.cliff_texture_path, biome.cliff_texture_index)

    return {"ok": true}


func _get_terrain_assets(terrain: Node) -> Object:
    if terrain.has_method("get_assets"):
        return terrain.call("get_assets")
    return terrain.get("assets")


func _resolve_texture_slot(assets: Object, texture_path: String, preferred_slot: int) -> int:
    var path: String = texture_path.strip_edges()
    if path.is_empty():
        return preferred_slot
    if not ResourceLoader.exists(path):
        return preferred_slot

    var texture: Resource = load(path)
    if not (texture is Texture2D):
        return preferred_slot

    var max_slots: int = 32
    var count: int = max_slots
    if assets.has_method("get_texture_count"):
        count = maxi(max_slots, int(assets.call("get_texture_count")))

    if preferred_slot >= 0:
        assets.call("set_texture", preferred_slot, texture)
        return preferred_slot

    var first_empty: int = -1
    if assets.has_method("get_texture"):
        for i: int in range(count):
            var existing: Variant = assets.call("get_texture", i)
            if existing == null and first_empty < 0:
                first_empty = i
            elif existing is Resource and String(existing.resource_path) == path:
                return i

    var slot: int = first_empty if first_empty >= 0 else count
    assets.call("set_texture", slot, texture)
    return slot


func _on_import_all_textures_assign_requested() -> void:
    var terrain: Node = _find_terrain_node()
    if terrain == null:
        _panel.set_status("No Terrain3D node found in edited scene.", true)
        return

    var texture_root: String = _panel.get_texture_root_path()
    var result: Dictionary = _import_and_assign_textures_to_biomes(terrain, texture_root)
    if bool(result.get("ok", false)):
        _panel.set_status("Imported %d PBR texture sets and assigned to %d biomes." % [result.get("texture_count", 0), result.get("biome_count", 0)])
    else:
        _panel.set_status(String(result.get("error", "Import failed.")), true)


func _import_and_assign_textures_to_biomes(terrain: Node, texture_root: String) -> Dictionary:
    var assets: Object = _get_terrain_assets(terrain)
    if assets == null:
        return {"ok": false, "error": "Terrain3D assets not found."}
    if not assets.has_method("set_texture"):
        return {"ok": false, "error": "Terrain3D assets do not support set_texture."}

    # Scan for PBR texture sets
    var pbr_sets: Array[Dictionary] = _scan_pbr_texture_sets(texture_root)
    if pbr_sets.is_empty():
        # Create default placeholder textures if none found
        return _create_default_placeholder_textures(assets, _biomes)

    # Pack textures and assign to biomes
    var slot: int = 0
    var packed_paths: Array[String] = []

    for i: int in range(_biomes.size()):
        var biome: AetherBiomeResource = _biomes[i]
        var set_idx: int = i % pbr_sets.size()
        var pbr_set: Dictionary = pbr_sets[set_idx]

        # Pack: Albedo(RGB) + Height(A)
        var packed_albedo_path: String = ""
        if pbr_set.has("albedo"):
            var height_path: String = pbr_set.get("displacement", "")
            packed_albedo_path = _pack_textures_pair(pbr_set["albedo"], height_path, texture_root, "packed_%s_albedo_height" % pbr_set.get("_base", "tex_%d" % set_idx))
            if not packed_albedo_path.is_empty():
                packed_paths.append(packed_albedo_path)
                biome.base_texture_path = packed_albedo_path
                biome.base_texture_index = slot
                assets.call("set_texture", slot, load(packed_albedo_path))
                slot += 1
        else:
            biome.base_texture_index = -1

        # Pack: Normal(RGB) + Roughness(A) for detail
        var packed_detail_path: String = ""
        if pbr_set.has("normal"):
            var rough_path: String = pbr_set.get("roughness", "")
            packed_detail_path = _pack_textures_pair(pbr_set["normal"], rough_path, texture_root, "packed_%s_normal_rough" % pbr_set.get("_base", "tex_%d" % set_idx))
            if not packed_detail_path.is_empty():
                packed_paths.append(packed_detail_path)
                biome.detail_texture_path = packed_detail_path
                biome.detail_texture_index = slot
                assets.call("set_texture", slot, load(packed_detail_path))
                slot += 1
        else:
            # Fallback: use albedo for detail
            if pbr_set.has("albedo"):
                biome.detail_texture_path = pbr_set["albedo"]
                biome.detail_texture_index = slot
                assets.call("set_texture", slot, load(pbr_set["albedo"]))
                slot += 1
            else:
                biome.detail_texture_index = -1

        # Cliff texture - copy of detail or base
        var cliff_idx: int = (i + 2) % pbr_sets.size()
        var cliff_set: Dictionary = pbr_sets[cliff_idx]
        if cliff_set.has("normal"):
            biome.cliff_texture_path = biome.detail_texture_path
            biome.cliff_texture_index = biome.detail_texture_index
        elif pbr_set.has("albedo"):
            biome.cliff_texture_path = pbr_set["albedo"]
            biome.cliff_texture_index = slot - 1 if slot > 0 else -1
        else:
            biome.cliff_texture_index = -1

        # Apply default slope/height blending rules
        _apply_default_blending_rules(biome, i)

    return {"ok": true, "texture_count": packed_paths.size(), "biome_count": _biomes.size()}


func _pack_textures_pair(rgb_path: String, a_path: String, output_folder: String, base_name: String) -> String:
    # Load RGB texture
    var rgb_res: Resource = null
    if not rgb_path.is_empty() and ResourceLoader.exists(rgb_path):
        rgb_res = ResourceLoader.load(rgb_path, "Image", ResourceLoader.CACHE_MODE_IGNORE)
    var rgb_img: Image = rgb_res as Image
    if rgb_img == null:
        return ""

    var a_img: Image = null
    if not a_path.is_empty() and ResourceLoader.exists(a_path):
        var a_res: Resource = ResourceLoader.load(a_path, "Image", ResourceLoader.CACHE_MODE_IGNORE)
        a_img = a_res as Image

    # Create packed image: RGB + A
    var packed: Image = _create_packed_image(rgb_img, a_img)
    if packed == null:
        return ""

    # Ensure output folder exists
    var abs_folder: String = ProjectSettings.globalize_path(output_folder)
    if not DirAccess.dir_exists_absolute(abs_folder):
        DirAccess.make_dir_recursive_absolute(abs_folder)

    # Save packed texture
    var output_path: String = "%s/%s.png" % [output_folder.trim_suffix("/"), base_name]
    var save_err: Error = packed.save_png(output_path)
    if save_err != OK:
        return ""

    # Trigger rescan
    call_deferred("_rescan_textures_folder", output_folder)
    return output_path


func _create_packed_image(rgb_image: Image, a_image: Image) -> Image:
    if rgb_image == null:
        return null

    var width: int = rgb_image.get_width()
    var height: int = rgb_image.get_height()

    # Resize alpha to match RGB if needed
    var final_a: Image = a_image
    if a_image != null:
        if a_image.get_width() != width or a_image.get_height() != height:
            final_a = Image.create(width, height, false, a_image.get_format())
            for y in range(height):
                for x in range(width):
                    var src_x: int = int(float(x) * float(a_image.get_width()) / float(width))
                    var src_y: int = int(float(y) * float(a_image.get_height()) / float(height))
                    final_a.set_pixel(x, y, a_image.get_pixel(src_x, src_y))
        else:
            final_a = a_image

    # Create output: RGBA
    var output: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
    for y in range(height):
        for x in range(width):
            var rgb_col: Color = rgb_image.get_pixel(x, y)
            var a_val: float = 1.0
            if final_a != null:
                a_val = final_a.get_pixel(x, y).a
            output.set_pixel(x, y, Color(rgb_col.r, rgb_col.g, rgb_col.b, a_val))

    return output


func _rescan_textures_folder(folder_path: String) -> void:
    # Rescan the textures folder so Godot picks up new packed files
    if get_editor_interface() != null:
        var fs: EditorFileSystem = get_editor_interface().get_resource_filesystem()
        if fs != null:
            fs.scan()


func _scan_pbr_texture_sets(root_path: String) -> Array[Dictionary]:
    var sets: Array[Dictionary] = []

    # PBR naming patterns (order matters - first match wins)
    var albedo_patterns: Array[String] = ["_albedo", "_diff", "_diffuse", "_basecolor", "_color", "_base_color"]
    var normal_patterns: Array[String] = ["_normal", "_norm", "_nor", "_nrm"]
    var roughness_patterns: Array[String] = ["_roughness", "_rough", "_rgh"]
    var displacement_patterns: Array[String] = ["_displacement", "_disp", "_height", "_heightmap"]

    var texture_files: PackedStringArray = _collect_texture_files(root_path)
    if texture_files.is_empty():
        return sets

    # Group by base name
    var base_names: Dictionary = {}  # basename -> {albedo: path, normal: path, ...}

    for tex_path: String in texture_files:
        var file_name: String = tex_path.get_file()
        var base: String = file_name.get_basename()

        # Find which pattern this file matches
        var matched_key: String = ""
        var suffix: String = ""

        for pattern: String in albedo_patterns:
            if file_name.find(pattern) >= 0:
                matched_key = "albedo"
                suffix = pattern
                break
        if matched_key.is_empty():
            for pattern: String in normal_patterns:
                if file_name.find(pattern) >= 0:
                    matched_key = "normal"
                    suffix = pattern
                    break
        if matched_key.is_empty():
            for pattern: String in roughness_patterns:
                if file_name.find(pattern) >= 0:
                    matched_key = "roughness"
                    suffix = pattern
                    break
        if matched_key.is_empty():
            for pattern: String in displacement_patterns:
                if file_name.find(pattern) >= 0:
                    matched_key = "displacement"
                    suffix = pattern
                    break

        if matched_key.is_empty():
            # No pattern - assume it's an albedo
            matched_key = "albedo"
            suffix = ""

        # Get the base name (without the specific suffix)
        var base_name: String = base.substr(0, base.length() - suffix.length()) if suffix.is_empty() else base.replace(suffix, "")

        if not base_names.has(base_name):
            base_names[base_name] = {"_base": base_name}
        base_names[base_name][matched_key] = tex_path
        base_names[base_name]["_path"] = tex_path.get_base_dir()

    # Convert to array, prioritising sets with albedo
    for key: String in base_names.keys():
        var set_data: Dictionary = base_names[key]
        if set_data.has("albedo"):
            sets.append(set_data)

    return sets


func _collect_texture_files(root_path: String) -> PackedStringArray:
    var files: PackedStringArray = []
    const TEXTURE_EXTS: Array[String] = ["png", "jpg", "jpeg", "webp", "exr", "ktx", "dds", "tga"]

    var dir: DirAccess = DirAccess.open(root_path)
    if dir == null:
        # Try creating directory
        if not root_path.begins_with("res://"):
            return files
        var absolute: String = ProjectSettings.globalize_path(root_path)
        DirAccess.make_dir_recursive_absolute(absolute)
        dir = DirAccess.open(root_path)
        if dir == null:
            return files

    _collect_textures_recursive(dir, root_path, TEXTURE_EXTS, files)
    return files


func _collect_textures_recursive(dir: DirAccess, folder: String, extensions: Array[String], output: PackedStringArray) -> void:
    dir.list_dir_begin()
    var name: String = dir.get_next()
    while not name.is_empty():
        if name.begins_with("."):
            name = dir.get_next()
            continue

        var path: String = "%s/%s" % [folder.trim_suffix("/"), name]
        if dir.current_is_dir():
            var subdir: DirAccess = DirAccess.open(path)
            if subdir != null:
                _collect_textures_recursive(subdir, path, extensions, output)
        else:
            var ext: String = name.get_extension().to_lower()
            if extensions.has(ext) and ResourceLoader.exists(path):
                output.append(path)

        name = dir.get_next()
    dir.list_dir_end()


func _create_default_placeholder_textures(assets: Object, biomes: Array[AetherBiomeResource]) -> Dictionary:
    # No textures found - use default Terrain3D coloring
    for biome: AetherBiomeResource in biomes:
        biome.base_texture_index = -1
        biome.detail_texture_index = -1
        biome.cliff_texture_index = -1
        _apply_default_blending_rules(biome, biomes.find(biome))

    return {"ok": true, "texture_count": 0, "biome_count": biomes.size()}


func _apply_default_blending_rules(biome: AetherBiomeResource, biome_index: int) -> void:
    # Default rules per biome:
    # - Landing Crater (idx 0): flat areas, low height
    # - Overgrowth Fringe (idx 1): medium slopes, low-mid height
    # - Rugged Highlands (idx 2): steep slopes, high height

    match biome_index:
        0:  # Landing Crater
            biome.slope_based_blending = true
            biome.slope_blend_start_degrees = 15.0
            biome.slope_blend_end_degrees = 35.0
            biome.height_based_blending = true
            biome.height_blend_start = 0.0
            biome.height_blend_end = 45.0
            biome.texture_blend_strength = 0.85
        1:  # Overgrowth Fringe
            biome.slope_based_blending = true
            biome.slope_blend_start_degrees = 25.0
            biome.slope_blend_end_degrees = 50.0
            biome.height_based_blending = true
            biome.height_blend_start = 20.0
            biome.height_blend_end = 90.0
            biome.texture_blend_strength = 0.75
        2:  # Rugged Highlands
            biome.slope_based_blending = true
            biome.slope_blend_start_degrees = 35.0
            biome.slope_blend_end_degrees = 65.0
            biome.height_based_blending = true
            biome.height_blend_start = 60.0
            biome.height_blend_end = 180.0
            biome.texture_blend_strength = 0.65
        _:  # Other biomes
            biome.slope_based_blending = true
            biome.slope_blend_start_degrees = 20.0
            biome.slope_blend_end_degrees = 45.0
            biome.height_based_blending = true
            biome.height_blend_start = 10.0
            biome.height_blend_end = 100.0
            biome.texture_blend_strength = 0.7
