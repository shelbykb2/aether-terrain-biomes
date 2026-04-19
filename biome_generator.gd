@tool
extends RefCounted
class_name AetherBiomeGenerator

const DEFAULT_MAP_SIZE: int = 1024
const DEFAULT_WORLD_SIZE_METERS: float = 2048.0
const UPDATE_MAPS_ALL: int = 3
const MAX_SPAWN_BUDGET_PER_ENTRY: int = 6000
const TEXTURE_TARGET_RESOLUTION: int = 512


func generate_terrain(terrain: Node, biomes: Array[AetherBiomeResource], options: Dictionary = {}) -> Dictionary:
    if terrain == null:
        return {"ok": false, "error": "Terrain node is null."}
    if biomes.is_empty():
        return {"ok": false, "error": "At least one biome is required."}

    var map_size: int = int(options.get("map_size", DEFAULT_MAP_SIZE))
    var world_size_m: float = float(options.get("world_size_m", DEFAULT_WORLD_SIZE_METERS))
    var world_seed: int = int(options.get("seed", 1337))
    var procedural_blend: float = clampf(float(options.get("procedural_blend", 1.0)), 0.0, 1.0)
    var painted_blend: float = clampf(float(options.get("painted_blend", 0.0)), 0.0, 1.0)
    var weight_sharpness: float = clampf(float(options.get("weight_sharpness", 2.4)), 1.0, 6.0)
    var spike_threshold: float = maxf(0.0, float(options.get("spike_threshold", 12.0)))
    var spike_softness: float = clampf(float(options.get("spike_softness", 0.68)), 0.0, 1.0)
    var smoothing_passes: int = clampi(int(options.get("smoothing_passes", 2)), 0, 8)
    var painted_masks: Dictionary = options.get("painted_masks", {})
    var flatten_marker: Marker3D = options.get("safe_zone_marker", null)
    var flatten_radius: float = float(options.get("safe_zone_radius", 85.0))
    var apply_textures: bool = bool(options.get("apply_textures", true))
    var spawn_assets: bool = bool(options.get("spawn_assets", true))

    for biome: AetherBiomeResource in biomes:
        biome.ensure_default_spawn_schema()

    var generated: Dictionary = _build_blended_maps(
        biomes,
        map_size,
        world_size_m,
        world_seed,
        procedural_blend,
        painted_blend,
        painted_masks,
        weight_sharpness
    )

    var height_image: Image = generated["height_image"]
    var dominant_biome_image: Image = generated["dominant_biome_image"]

    if flatten_marker != null:
        _flatten_safe_zone(height_image, terrain, flatten_marker.global_position, flatten_radius, world_size_m)

    _apply_height_safety(height_image, spike_threshold, spike_softness, smoothing_passes)

    var apply_height_result: Dictionary = _apply_height_image(terrain, height_image)
    if not bool(apply_height_result.get("ok", false)):
        return apply_height_result

    if apply_textures:
        _apply_texture_rules(terrain, dominant_biome_image, height_image, biomes, world_size_m)

    if spawn_assets:
        _spawn_biome_assets(terrain, dominant_biome_image, biomes, world_seed, world_size_m)

    return {
        "ok": true,
        "map_size": map_size,
        "height_image": height_image,
        "dominant_biome_image": dominant_biome_image,
    }


func apply_surface_only(terrain: Node, biomes: Array[AetherBiomeResource], options: Dictionary = {}) -> Dictionary:
    if terrain == null:
        return {"ok": false, "error": "Terrain node is null."}
    if biomes.is_empty():
        return {"ok": false, "error": "At least one biome is required."}

    var map_size: int = int(options.get("map_size", DEFAULT_MAP_SIZE))
    var world_size_m: float = float(options.get("world_size_m", DEFAULT_WORLD_SIZE_METERS))
    var world_seed: int = int(options.get("seed", 1337))
    var procedural_blend: float = clampf(float(options.get("procedural_blend", 1.0)), 0.0, 1.0)
    var painted_blend: float = clampf(float(options.get("painted_blend", 0.0)), 0.0, 1.0)
    var weight_sharpness: float = clampf(float(options.get("weight_sharpness", 2.4)), 1.0, 6.0)
    var painted_masks: Dictionary = options.get("painted_masks", {})
    var apply_textures: bool = bool(options.get("apply_textures", true))
    var spawn_assets: bool = bool(options.get("spawn_assets", true))

    var generated: Dictionary = _build_blended_maps(
        biomes,
        map_size,
        world_size_m,
        world_seed,
        procedural_blend,
        painted_blend,
        painted_masks,
        weight_sharpness
    )

    var dominant_biome_image: Image = generated["dominant_biome_image"]
    var sampled_height: Image = _capture_height_image_from_terrain(terrain, map_size, world_size_m)

    if apply_textures:
        _apply_texture_rules(terrain, dominant_biome_image, sampled_height, biomes, world_size_m)

    if spawn_assets:
        _spawn_biome_assets(terrain, dominant_biome_image, biomes, world_seed, world_size_m)

    return {
        "ok": true,
        "map_size": map_size,
        "dominant_biome_image": dominant_biome_image,
    }


func build_biome_preview(biomes: Array[AetherBiomeResource], options: Dictionary = {}) -> Dictionary:
    if biomes.is_empty():
        return {"ok": false, "error": "At least one biome is required."}

    var map_size: int = int(options.get("map_size", DEFAULT_MAP_SIZE))
    var world_size_m: float = float(options.get("world_size_m", DEFAULT_WORLD_SIZE_METERS))
    var world_seed: int = int(options.get("seed", 1337))
    var procedural_blend: float = clampf(float(options.get("procedural_blend", 1.0)), 0.0, 1.0)
    var painted_blend: float = clampf(float(options.get("painted_blend", 0.0)), 0.0, 1.0)
    var weight_sharpness: float = clampf(float(options.get("weight_sharpness", 2.4)), 1.0, 6.0)
    var painted_masks: Dictionary = options.get("painted_masks", {})

    var generated: Dictionary = _build_blended_maps(
        biomes,
        map_size,
        world_size_m,
        world_seed,
        procedural_blend,
        painted_blend,
        painted_masks,
        weight_sharpness
    )

    return {
        "ok": true,
        "map_size": map_size,
        "dominant_biome_image": generated["dominant_biome_image"],
    }


func flatten_safe_zone_around_marker(
    terrain: Node,
    marker: Marker3D,
    radius_world: float,
    map_size: int = DEFAULT_MAP_SIZE,
    world_size_m: float = DEFAULT_WORLD_SIZE_METERS
) -> Dictionary:
    if terrain == null:
        return {"ok": false, "error": "Terrain node is null."}
    if marker == null:
        return {"ok": false, "error": "Marker3D is null."}

    var data: Object = terrain.get("data")
    if data == null:
        return {"ok": false, "error": "Terrain data object is missing."}

    var image := Image.create(map_size, map_size, false, Image.FORMAT_RF)
    for y: int in range(map_size):
        for x: int in range(map_size):
            var world_pos: Vector3 = _image_to_world(x, y, map_size, map_size, world_size_m)
            var existing_h: float = _sample_terrain_height(terrain, world_pos)
            image.set_pixel(x, y, Color(existing_h, 0.0, 0.0))

    _flatten_safe_zone(image, terrain, marker.global_position, radius_world, world_size_m)
    return _apply_height_image(terrain, image)


func _build_blended_maps(
    biomes: Array[AetherBiomeResource],
    map_size: int,
    world_size_m: float,
    world_seed: int,
    procedural_blend: float,
    painted_blend: float,
    painted_masks: Dictionary,
    weight_sharpness: float
) -> Dictionary:
    var height_image := Image.create(map_size, map_size, false, Image.FORMAT_RF)
    var dominant_biome_image := Image.create(map_size, map_size, false, Image.FORMAT_R8)

    var noise_per_biome: Array[FastNoiseLite] = []
    for biome: AetherBiomeResource in biomes:
        noise_per_biome.append(biome.to_noise(world_seed))

    for y: int in range(map_size):
        for x: int in range(map_size):
            var world_pos: Vector3 = _image_to_world(x, y, map_size, map_size, world_size_m)
            var weights: Array[float] = _sample_biome_weights(
                biomes,
                noise_per_biome,
                world_pos.x,
                world_pos.z,
                x,
                y,
                procedural_blend,
                painted_blend,
                painted_masks,
                weight_sharpness
            )

            var blended_height: float = 0.0
            var max_weight: float = -1.0
            var dominant_idx: int = 0
            for i: int in range(biomes.size()):
                var n: float = (noise_per_biome[i].get_noise_2d(world_pos.x, world_pos.z) + 1.0) * 0.5
                var biome_height: float = ((n - 0.5) * biomes[i].height_multiplier * 1.25) + (biomes[i].height_multiplier * 0.42)
                blended_height += biome_height * weights[i]
                if weights[i] > max_weight:
                    max_weight = weights[i]
                    dominant_idx = i

            var radial_distance: float = Vector2(world_pos.x, world_pos.z).length() / maxf(world_size_m * 0.5, 0.001)
            var island_factor: float = clampf(1.0 - pow(radial_distance, 1.15), 0.0, 1.0)
            blended_height = maxf(0.0, blended_height * lerpf(0.2, 1.0, island_factor))

            height_image.set_pixel(x, y, Color(blended_height, 0.0, 0.0))
            dominant_biome_image.set_pixel(x, y, Color(float(dominant_idx) / 255.0, 0.0, 0.0))

    return {
        "height_image": height_image,
        "dominant_biome_image": dominant_biome_image,
    }


func _sample_biome_weights(
    biomes: Array[AetherBiomeResource],
    noise_per_biome: Array[FastNoiseLite],
    world_x: float,
    world_z: float,
    px: int,
    py: int,
    procedural_blend: float,
    painted_blend: float,
    painted_masks: Dictionary,
    weight_sharpness: float
) -> Array[float]:
    var weights: Array[float] = []
    var procedural_weights: Array[float] = []
    var painted_weights: Array[float] = []
    weights.resize(biomes.size())
    procedural_weights.resize(biomes.size())
    painted_weights.resize(biomes.size())

    var painted_total: float = 0.0
    for i: int in range(biomes.size()):
        var n: float = (noise_per_biome[i].get_noise_2d(world_x * 0.25, world_z * 0.25) + 1.0) * 0.5
        procedural_weights[i] = lerpf(1.0, n, procedural_blend)

        var painted_weight: float = 0.0
        var mask_key: String = biomes[i].biome_name
        if painted_blend > 0.0 and painted_masks.has(mask_key):
            var image: Image = painted_masks[mask_key]
            if image != null and px < image.get_width() and py < image.get_height():
                painted_weight = image.get_pixel(px, py).r
        painted_weights[i] = painted_weight
        painted_total += painted_weight

    var total: float = 0.0
    for i: int in range(biomes.size()):
        var combined: float
        if painted_total > 0.0001 and painted_blend > 0.0:
            var normalized_painted: float = painted_weights[i] / painted_total
            combined = (procedural_weights[i] * (1.0 - painted_blend)) + (normalized_painted * painted_blend)
        else:
            combined = procedural_weights[i]

        combined = pow(maxf(0.0001, combined), weight_sharpness)
        weights[i] = combined
        total += combined

    if total <= 0.0:
        var fallback: float = 1.0 / float(max(1, biomes.size()))
        for i: int in range(weights.size()):
            weights[i] = fallback
        return weights

    for i: int in range(weights.size()):
        weights[i] = weights[i] / total
    return weights


func _flatten_safe_zone(
    height_image: Image,
    terrain: Node,
    center_world: Vector3,
    radius_world: float,
    world_size_m: float
) -> void:
    var width: int = height_image.get_width()
    var height: int = height_image.get_height()
    var center_px: Vector2i = _world_to_image(center_world, world_size_m, width, height)
    var radius_px: float = (radius_world / maxf(world_size_m, 0.001)) * float(width)
    var safe_height: float = _sample_terrain_height(terrain, center_world)

    for y: int in range(height):
        for x: int in range(width):
            var dist: float = Vector2(float(x), float(y)).distance_to(Vector2(center_px))
            if dist > radius_px:
                continue
            var t: float = clampf(dist / maxf(radius_px, 0.001), 0.0, 1.0)
            var falloff: float = smoothstep(0.0, 1.0, t)
            var current_height: float = height_image.get_pixel(x, y).r
            var blended: float = lerpf(safe_height, current_height, falloff)
            height_image.set_pixel(x, y, Color(blended, 0.0, 0.0))


func _apply_height_safety(height_image: Image, spike_threshold: float, spike_softness: float, smoothing_passes: int) -> void:
    if smoothing_passes <= 0 or (spike_threshold <= 0.0 and spike_softness <= 0.0):
        return

    var width: int = height_image.get_width()
    var height: int = height_image.get_height()
    if width < 3 or height < 3:
        return

    for _pass: int in range(smoothing_passes):
        var source: Image = height_image.duplicate()
        for y: int in range(1, height - 1):
            for x: int in range(1, width - 1):
                var current_h: float = source.get_pixel(x, y).r
                var neighbor_avg: float = _sample_neighbor_average(source, x, y)
                var safe_h: float = current_h

                if spike_threshold > 0.0 and current_h > neighbor_avg + spike_threshold:
                    var overshoot: float = current_h - (neighbor_avg + spike_threshold)
                    safe_h -= overshoot * spike_softness

                var smooth_strength: float = 0.12 * spike_softness
                safe_h = lerpf(safe_h, neighbor_avg, smooth_strength)
                height_image.set_pixel(x, y, Color(maxf(0.0, safe_h), 0.0, 0.0))


func _capture_height_image_from_terrain(terrain: Node, map_size: int, world_size_m: float) -> Image:
    var image := Image.create(map_size, map_size, false, Image.FORMAT_RF)
    for y: int in range(map_size):
        for x: int in range(map_size):
            var world_pos: Vector3 = _image_to_world(x, y, map_size, map_size, world_size_m)
            var existing_h: float = _sample_terrain_height(terrain, world_pos)
            image.set_pixel(x, y, Color(existing_h, 0.0, 0.0))
    return image


func _sample_neighbor_average(image: Image, x: int, y: int) -> float:
    var total: float = 0.0
    var count: int = 0
    for oy: int in range(-1, 2):
        for ox: int in range(-1, 2):
            if ox == 0 and oy == 0:
                continue
            total += image.get_pixel(x + ox, y + oy).r
            count += 1
    if count == 0:
        return image.get_pixel(x, y).r
    return total / float(count)


func _apply_height_image(terrain: Node, height_image: Image) -> Dictionary:
    var data: Object = terrain.get("data")
    if data == null:
        return {"ok": false, "error": "Terrain has no data object."}

    if data.has_method("has_region") and not bool(data.call("has_region", Vector2i.ZERO)):
        if data.has_method("add_region_blank"):
            data.call("add_region_blank", Vector2i.ZERO, false)

    if data.has_method("import_images"):
        var import_payload: Array = [height_image, null, null]
        data.call("import_images", import_payload, Vector3.ZERO, 0.0, 1.0)
    elif data.has_method("set_height"):
        _apply_height_by_sampling(terrain, data, height_image)
    else:
        return {"ok": false, "error": "Terrain data does not expose import_images or set_height."}

    if data.has_method("update_maps"):
        data.call("update_maps", UPDATE_MAPS_ALL, false)

    if data.has_method("save_directory"):
        data.call("save_directory", terrain.get("data_directory"))

    return {"ok": true}


func _apply_height_by_sampling(terrain: Node, data: Object, height_image: Image) -> void:
    var width: int = height_image.get_width()
    var height: int = height_image.get_height()
    var world_size_m: float = DEFAULT_WORLD_SIZE_METERS

    if terrain.has_method("get_mesh_size"):
        var mesh_size: Variant = terrain.call("get_mesh_size")
        if mesh_size is float:
            world_size_m = float(mesh_size)

    for y: int in range(height):
        for x: int in range(width):
            var pos: Vector3 = _image_to_world(x, y, width, height, world_size_m)
            data.call("set_height", pos, height_image.get_pixel(x, y).r)


func _apply_texture_rules(
    terrain: Node,
    dominant_biome_image: Image,
    height_image: Image,
    biomes: Array[AetherBiomeResource],
    world_size_m: float
) -> void:
    var data: Object = terrain.get("data")
    if data == null:
        return

    if not data.has_method("set_control_base_id"):
        return

    var has_overlay: bool = data.has_method("set_control_overlay_id")
    var has_blend: bool = data.has_method("set_control_blend")

    var width: int = dominant_biome_image.get_width()
    var height: int = dominant_biome_image.get_height()
    var texture_step: int = maxi(1, int(ceil(float(width) / float(TEXTURE_TARGET_RESOLUTION))))
    for y: int in range(0, height, texture_step):
        for x: int in range(0, width, texture_step):
            var biome_idx: int = int(round(dominant_biome_image.get_pixel(x, y).r * 255.0))
            if biome_idx < 0 or biome_idx >= biomes.size():
                continue

            var biome: AetherBiomeResource = biomes[biome_idx]
            var world_pos: Vector3 = _image_to_world(x, y, width, height, world_size_m)
            data.call("set_control_base_id", world_pos, biome.base_texture_index)

            var height_value: float = height_image.get_pixel(x, y).r
            var slope_deg: float = _sample_slope_degrees(height_image, x, y, world_size_m)
            var height_weight: float = _height_blend_factor(height_value, biome)
            var slope_weight: float = _slope_blend_factor(slope_deg, biome)
            var blend_weight: float = clampf(maxf(height_weight, slope_weight) * biome.texture_blend_strength, 0.0, 1.0)

            if has_overlay:
                var overlay_id: int = _resolve_overlay_texture_id(biome, slope_weight, height_weight)
                if overlay_id >= 0:
                    data.call("set_control_overlay_id", world_pos, overlay_id)

            if has_blend:
                data.call("set_control_blend", world_pos, blend_weight)

    if data.has_method("update_maps"):
        data.call("update_maps", UPDATE_MAPS_ALL, false)


func _resolve_overlay_texture_id(biome: AetherBiomeResource, slope_weight: float, height_weight: float) -> int:
    if slope_weight > 0.001 and biome.cliff_texture_index >= 0:
        return biome.cliff_texture_index
    if height_weight > 0.001 and biome.detail_texture_index >= 0:
        return biome.detail_texture_index
    if biome.detail_texture_index >= 0:
        return biome.detail_texture_index
    if biome.cliff_texture_index >= 0:
        return biome.cliff_texture_index
    return -1


func _height_blend_factor(height_value: float, biome: AetherBiomeResource) -> float:
    if not biome.height_based_blending:
        return 0.0
    if biome.height_blend_end <= biome.height_blend_start:
        return 0.0
    return clampf((height_value - biome.height_blend_start) / (biome.height_blend_end - biome.height_blend_start), 0.0, 1.0)


func _slope_blend_factor(slope_deg: float, biome: AetherBiomeResource) -> float:
    if not biome.slope_based_blending:
        return 0.0
    if biome.slope_blend_end_degrees <= biome.slope_blend_start_degrees:
        return 0.0
    return clampf((slope_deg - biome.slope_blend_start_degrees) / (biome.slope_blend_end_degrees - biome.slope_blend_start_degrees), 0.0, 1.0)


func _sample_slope_degrees(height_image: Image, px: int, py: int, world_size_m: float) -> float:
    var width: int = height_image.get_width()
    var height: int = height_image.get_height()
    var x0: int = maxi(0, px - 1)
    var x1: int = mini(width - 1, px + 1)
    var y0: int = maxi(0, py - 1)
    var y1: int = mini(height - 1, py + 1)

    var dx: float = height_image.get_pixel(x1, py).r - height_image.get_pixel(x0, py).r
    var dz: float = height_image.get_pixel(px, y1).r - height_image.get_pixel(px, y0).r
    var meters_per_pixel: float = world_size_m / float(maxi(1, width - 1))
    var gradient: float = Vector2(dx, dz).length() / maxf(meters_per_pixel * 2.0, 0.001)
    return rad_to_deg(atan(gradient))


func _spawn_biome_assets(
    terrain: Node,
    dominant_biome_image: Image,
    biomes: Array[AetherBiomeResource],
    world_seed: int,
    world_size_m: float
) -> void:
    _clear_previous_biome_multimeshes(terrain)

    var map_w: int = dominant_biome_image.get_width()
    var map_h: int = dominant_biome_image.get_height()

    for biome_idx: int in range(biomes.size()):
        var biome: AetherBiomeResource = biomes[biome_idx]
        for entry: Dictionary in biome.spawn_entries:
            var transforms: Array[Transform3D] = _build_spawn_transforms(
                terrain,
                dominant_biome_image,
                biome_idx,
                entry,
                world_seed,
                map_w,
                map_h,
                world_size_m
            )
            if transforms.is_empty():
                continue

            if not _spawn_with_terrain_instancer(terrain, entry, transforms):
                _spawn_with_multimesh_fallback(terrain, entry, transforms, biome.biome_name)


func _build_spawn_transforms(
    terrain: Node,
    dominant_biome_image: Image,
    biome_idx: int,
    entry: Dictionary,
    world_seed: int,
    map_w: int,
    map_h: int,
    world_size_m: float
) -> Array[Transform3D]:
    var density: float = maxf(0.0, float(entry.get("density", 0.0)))
    if density <= 0.0:
        return []

    var budget: int = clampi(int(float(map_w * map_h) * density), 0, MAX_SPAWN_BUDGET_PER_ENTRY)
    if budget == 0:
        return []

    var min_h: float = float(entry.get("min_height", -INF))
    var max_h: float = float(entry.get("max_height", INF))
    var min_scale: float = float(entry.get("min_scale", 1.0))
    var max_scale: float = float(entry.get("max_scale", 1.0))
    var yaw_random: bool = bool(entry.get("yaw_random", true))

    var transforms: Array[Transform3D] = []
    transforms.resize(0)
    var rng := RandomNumberGenerator.new()
    rng.seed = hash([world_seed, biome_idx, entry.get("name", "spawn")])

    var placed: int = 0
    var attempts: int = 0
    var max_attempts: int = budget * 8
    while placed < budget and attempts < max_attempts:
        attempts += 1
        var px: int = rng.randi_range(0, map_w - 1)
        var py: int = rng.randi_range(0, map_h - 1)
        var idx: int = int(round(dominant_biome_image.get_pixel(px, py).r * 255.0))
        if idx != biome_idx:
            continue

        var world_pos: Vector3 = _image_to_world(px, py, map_w, map_h, world_size_m)
        world_pos.y = _sample_terrain_height(terrain, world_pos)
        if world_pos.y < min_h or world_pos.y > max_h:
            continue

        var yaw: float = rng.randf_range(0.0, TAU) if yaw_random else 0.0
        var scale_value: float = rng.randf_range(min_scale, max_scale)
        var basis: Basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_value)
        transforms.append(Transform3D(basis, world_pos))
        placed += 1

    return transforms


func _spawn_with_terrain_instancer(terrain: Node, entry: Dictionary, transforms: Array[Transform3D]) -> bool:
    var instancer: Object = terrain.get("instancer")
    if instancer == null:
        return false
    if not instancer.has_method("add_transforms"):
        return false

    var mesh_id: int = int(entry.get("terrain_mesh_id", -1))
    if mesh_id < 0:
        return false

    if instancer.has_method("clear_by_mesh"):
        instancer.call("clear_by_mesh", mesh_id)

    instancer.call("add_transforms", mesh_id, transforms, PackedColorArray(), false)
    if instancer.has_method("update_mmis"):
        instancer.call("update_mmis")
    return true


func _spawn_with_multimesh_fallback(terrain: Node, entry: Dictionary, transforms: Array[Transform3D], biome_name: String) -> void:
    var mesh: Mesh = _resolve_spawn_mesh(entry)
    if mesh == null:
        return

    var parent: Node3D = terrain as Node3D
    if parent == null:
        return

    var mm := MultiMesh.new()
    mm.mesh = mesh
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.instance_count = transforms.size()
    for i: int in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])

    var mm_node := MultiMeshInstance3D.new()
    mm_node.name = "Biome_%s_%s" % [biome_name, String(entry.get("name", "Spawn"))]
    mm_node.multimesh = mm
    parent.add_child(mm_node)
    if Engine.is_editor_hint() and mm_node.get_owner() == null:
        mm_node.owner = _find_owner_root(parent)


func _resolve_spawn_mesh(entry: Dictionary) -> Mesh:
    var raw_mesh: Variant = entry.get("mesh", null)
    if raw_mesh is Mesh:
        return raw_mesh

    var raw_scene: Variant = entry.get("scene", null)
    if raw_scene is PackedScene:
        var node: Node = raw_scene.instantiate()
        var mesh_instance: MeshInstance3D = _find_mesh_instance(node)
        node.free()
        if mesh_instance != null:
            return mesh_instance.mesh
    return null


func _clear_previous_biome_multimeshes(terrain: Node) -> void:
    var parent: Node3D = terrain as Node3D
    if parent == null:
        return

    for child: Node in parent.get_children():
        if child is MultiMeshInstance3D and String(child.name).begins_with("Biome_"):
            child.queue_free()


func _find_mesh_instance(node: Node) -> MeshInstance3D:
    if node is MeshInstance3D:
        return node
    for child: Node in node.get_children():
        var found: MeshInstance3D = _find_mesh_instance(child)
        if found != null:
            return found
    return null


func _sample_terrain_height(terrain: Node, world_pos: Vector3) -> float:
    var data: Object = terrain.get("data")
    if data != null and data.has_method("get_height"):
        return float(data.call("get_height", world_pos))
    if terrain.has_method("get_height"):
        return float(terrain.call("get_height", world_pos))
    return world_pos.y


func height_image_sample(world_pos: Vector3, terrain: Node) -> float:
    return _sample_terrain_height(terrain, world_pos)


func _world_to_image(world_pos: Vector3, world_size_m: float, width: int, height: int) -> Vector2i:
    var nx: float = clampf((world_pos.x / maxf(world_size_m, 0.001)) + 0.5, 0.0, 1.0)
    var nz: float = clampf((world_pos.z / maxf(world_size_m, 0.001)) + 0.5, 0.0, 1.0)
    return Vector2i(int(nx * float(width - 1)), int(nz * float(height - 1)))


func _image_to_world(px: int, py: int, width: int, height: int, world_size_m: float) -> Vector3:
    var nx: float = float(px) / float(max(1, width - 1))
    var nz: float = float(py) / float(max(1, height - 1))
    return Vector3((nx - 0.5) * world_size_m, 0.0, (nz - 0.5) * world_size_m)


func _find_owner_root(node: Node) -> Node:
    var cursor: Node = node
    while cursor.get_owner() != null:
        cursor = cursor.get_owner()
    return cursor
