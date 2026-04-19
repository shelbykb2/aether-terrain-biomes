@tool
extends RefCounted
class_name AetherBiomePainter

var _mask_images: Dictionary = {}


func ensure_masks(biomes: Array[AetherBiomeResource], map_size: int) -> void:
    for biome: AetherBiomeResource in biomes:
        var key: String = biome.biome_name
        if _mask_images.has(key):
            continue
        var mask := Image.create(map_size, map_size, false, Image.FORMAT_RF)
        mask.fill(Color(0.0, 0.0, 0.0, 1.0))
        _mask_images[key] = mask


func clear_masks(biomes: Array[AetherBiomeResource], map_size: int) -> void:
    _mask_images.clear()
    ensure_masks(biomes, map_size)


func paint_at_pixel(biome_name: String, pixel: Vector2i, radius: float, strength: float, hardness: float = 0.65) -> void:
    if not _mask_images.has(biome_name):
        return
    var image: Image = _mask_images[biome_name]
    if image == null:
        return

    var min_x: int = maxi(0, int(floor(float(pixel.x) - radius)))
    var max_x: int = mini(image.get_width() - 1, int(ceil(float(pixel.x) + radius)))
    var min_y: int = maxi(0, int(floor(float(pixel.y) - radius)))
    var max_y: int = mini(image.get_height() - 1, int(ceil(float(pixel.y) + radius)))

    for y: int in range(min_y, max_y + 1):
        for x: int in range(min_x, max_x + 1):
            var dist: float = Vector2(float(x), float(y)).distance_to(Vector2(pixel))
            if dist > radius:
                continue
            var t: float = clampf(dist / maxf(radius, 0.001), 0.0, 1.0)
            var falloff: float = pow(1.0 - t, lerpf(0.5, 2.5, hardness))
            var current: float = image.get_pixel(x, y).r
            var painted: float = clampf(current + (strength * falloff), 0.0, 1.0)
            image.set_pixel(x, y, Color(painted, 0.0, 0.0, 1.0))


func get_masks() -> Dictionary:
    return _mask_images
