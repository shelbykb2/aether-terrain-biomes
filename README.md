# AetherTerrainBiomes

A Godot 4.x editor plugin providing biome authoring and procedural terrain generation tools for Terrain3D.

## Description

AetherTerrainBiomes adds a complete biome system to your Terrain3D-based project. Create multiple biomes with custom height, slope, and noise parameters, generate terrain procedurally, paint biome masks, and automatically import and assign PBR textures.

## Features

- **Multi-Biome Support**: Create unlimited biomes with unique colors, height multipliers, and noise parameters
- **Procedural Generation**: Generate terrain heightmaps using fractal noise with per-biome frequency, octaves, gain, and lacunarity controls
- **Biome Mask Painting**: Paint biome masks directly in the editor with smooth blending
- **Automatic Texture Import**: Scan folders for PBR texture sets, auto-pack them for Terrain3D, and assign to biomes with one click
- **Slope & Height Blending**: Configure automatic texture blending based on terrain slope and height
- **Asset Spawning**: Define spawn entries for props, foliage, and rocks per biome
- **Safe Zone Flattening**: Flatten areas around player spawn points (e.g., ship landing zone)
- **Live Preview**: Real-time biome dominance preview as you adjust parameters

## Installation

1. Clone or copy this repository into your Godot project's `addons/` folder:
   ```
   addons/aether_terrain_biomes/
   ```

2. Enable the plugin in Godot:
   - Go to **Project > Project Settings > Plugins**
   - Find **AetherTerrainBiomes** and click **Enable**

3. Restart Godot if prompted

## Usage

### Opening the Plugin

1. Open your project with a Terrain3D node in the scene
2. The plugin panel appears as a dock on the right side of the editor

### Creating Biomes

1. Click **+ Add Biome** to create new biomes
2. Select a biome in the list to edit its properties
3. Configure:
   - **Name**: Biome display name
   - **Colors**: Editor color for the biome preview
   - **Height**: Height multiplier and noise settings (frequency, octaves, gain, lacunarity)
   - **Textures**: Texture indices and file paths for base, detail, and cliff layers

### Generating Terrain

1. Set generation options (map size, world size, seed)
2. Click **Generate Terrain** to:
   - Apply fractal noise heightmap
   - Paint biome masks
   - Generate surface materials and spawn assets

3. Click **Apply Materials/Assets** to re-apply biomes without regenerating height

### Importing Textures

1. Place PBR textures in `res://textures/terrain/` following the naming convention:
   ```
   grass_albedo.png      # or grass_diffuse.png, grass_color.png
   grass_normal.png      # or grass_norm.png
   grass_roughness.png   # or grass_rough.png
   grass_displacement.png # or grass_height.png
   ```

2. Click **Import All Textures & Assign to Biomes**
   - Plugin auto-detects PBR sets by base name
   - Creates packed textures (Albedo+Height, Normal+Roughness)
   - Assigns to biome texture slots
   - Applies default slope/height blending rules

### Texture Blending

Each biome can use slope-based and height-based texture blending:
- **Slope**: Blend from base to cliff texture at specified angle thresholds
- **Height**: Blend based on terrain height in meters

## Requirements

- Godot 4.x (tested on 4.2+)
- Terrain3D plugin installed and configured

## License

MIT License - see LICENSE file for details.
