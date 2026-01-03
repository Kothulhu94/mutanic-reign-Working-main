import os
import json
import math
from PIL import Image

# Config
CONFIG_FILE = "terrain_config.json"

# Debug Config
DEBUG_ENABLED = True
DEBUG_DIR = "map_debug"
DEBUG_COLORS = {
    1: (255, 255, 0, 100),    # Sand: Yellow semi-transparent
    2: (0, 255, 255, 100),    # Snow: Cyan semi-transparent
    3: (0, 0, 255, 180)       # Water: Blue mostly solid
}

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

def color_distance(c1, c2):
    # Euclidean distance approximated
    r = c1[0] - c2[0]
    g = c1[1] - c2[1]
    b = c1[2] - c2[2]
    return math.sqrt(r*r + g*g + b*b)

def process_chunk(chunk_path, output_path, debug_path, config):
    print(f"Baking {chunk_path}...")
    try:
        img = Image.open(chunk_path).convert("RGB")
    except Exception as e:
        print(f"Skipping {chunk_path}: {e}")
        return

    # Resize to target size (Data is lower res than Visuals)
    target_size = config.get("target_size", 512)
    
    # We work on the visual resolution for debug, but logical resolution for data
    # Ideally keep them 1:1 for the baker to be accurate
    # But if we resize down, we should debug the resized version
    
    img_small = img.resize((target_size, target_size), Image.Resampling.NEAREST)
    pixels = img_small.load()
    
    # Create output image (Grayscale / Paletted)
    # Mode 'L' (8-bit pixels, black and white)
    out_img = Image.new("L", (target_size, target_size), 0)
    out_pixels = out_img.load()
    
    # Debug Image (RGBA)
    if DEBUG_ENABLED:
        debug_img = img_small.convert("RGBA")
        debug_pixels = debug_img.load()
    
    terrain_defs = config["terrain_types"]
    
    # Pre-parse terrain config for speed
    terrains = []
    for key, data in terrain_defs.items():
        terrains.append({
            "id": data["id"],
            "color": tuple(data["color"]),
            "tol": data["tolerance"]
        })
        
    width, height = img_small.size
    
    for y in range(height):
        for x in range(width):
            px = pixels[x, y]
            
            # Default ID 0 (Grass/None)
            matched_id = 0
            
            # Find best match
            for t in terrains:
                if color_distance(px, t["color"]) <= t["tol"]:
                    matched_id = t["id"]
                    break
            
            out_pixels[x, y] = matched_id
            
            # Debug Overlay
            if DEBUG_ENABLED and matched_id in DEBUG_COLORS:
                # Alpha blend manually or just set if we don't prefer Image.alpha_composite
                # Simple tint:
                overlay_col = DEBUG_COLORS[matched_id]
                orig_col = pixels[x, y]
                
                # Simple alpha blending logic
                alpha = overlay_col[3] / 255.0
                inv_alpha = 1.0 - alpha
                
                nr = int(orig_col[0] * inv_alpha + overlay_col[0] * alpha)
                ng = int(orig_col[1] * inv_alpha + overlay_col[1] * alpha)
                nb = int(orig_col[2] * inv_alpha + overlay_col[2] * alpha)
                
                debug_pixels[x, y] = (nr, ng, nb, 255)
            
    out_img.save(output_path)
    
    if DEBUG_ENABLED:
        debug_img.save(debug_path)

def stitch_debug_map(config):
    if not DEBUG_ENABLED: return
    
    print("Stitching full debug map...")
    
    # 16x16 grid approximation from file list or hardcoded
    # We know the grid size is implicitly defined by file names, but let's be dynamic
    # Find max X and Y
    in_dir = config["output_dir"] # Use data dir, but we actually need debug files
    # Actually we saved debug images to DEBUG_DIR
    
    files = [f for f in os.listdir(DEBUG_DIR) if f.startswith("debug_") and f.endswith(".png")]
    if not files:
        print("No debug chunks found to stitch.")
        return

    max_x = 0
    max_y = 0
    
    for f in files:
        # debug_10_5.png
        parts = f.replace("debug_", "").replace(".png", "").split("_")
        if len(parts) == 2:
            x, y = int(parts[0]), int(parts[1])
            max_x = max(max_x, x)
            max_y = max(max_y, y)
            
    grid_w = max_x + 1
    grid_h = max_y + 1
    
    target_size = config.get("target_size", 512)
    full_w = grid_w * target_size
    full_h = grid_h * target_size
    
    # Create massive canvas
    # 16 * 512 = 8192. 8192x8192 is large but standard for texture (64MB raw, compressed PNG fine)
    full_img = Image.new("RGBA", (full_w, full_h))
    
    for f in files:
        parts = f.replace("debug_", "").replace(".png", "").split("_")
        x, y = int(parts[0]), int(parts[1])
        
        chunk_path = os.path.join(DEBUG_DIR, f)
        try:
            chunk = Image.open(chunk_path)
            full_img.paste(chunk, (x * target_size, y * target_size))
        except Exception as e:
            print(f"Failed to stitch {f}: {e}")
            
    out_path = os.path.join(DEBUG_DIR, "FULL_DEBUG_MAP.png")
    full_img.save(out_path)
    print(f"Saved Unified Debug Map: {out_path} ({full_w}x{full_h})")
    
    # Clean up individual debug chunks
    print("Cleaning up individual debug chunks...")
    for f in files:
        file_path = os.path.join(DEBUG_DIR, f)
        try:
            os.remove(file_path)
        except OSError as e:
            print(f"Error deleting {file_path}: {e}")
    print("Cleanup complete.")

def main():
    if not os.path.exists(CONFIG_FILE):
        print("Config not found!")
        return
        
    config = load_config()
    in_dir = config["input_dir"]
    out_dir = config["output_dir"]
    
    # Ensure directories exist
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
        
    if DEBUG_ENABLED and not os.path.exists(DEBUG_DIR):
        os.makedirs(DEBUG_DIR)
        
    # Process all chunks
    files = [f for f in os.listdir(in_dir) if f.endswith(".png")]
    total = len(files)
    print(f"Found {total} chunks to process with Debug={DEBUG_ENABLED}.")
    
    for i, filename in enumerate(files):
        in_path = os.path.join(in_dir, filename)
        out_name = filename.replace("map_", "data_")
        out_path = os.path.join(out_dir, out_name)
        
        debug_name = filename.replace("map_", "debug_")
        debug_path = os.path.join(DEBUG_DIR, debug_name)
        
        process_chunk(in_path, out_path, debug_path, config)
        
        if i % 10 == 0:
            print(f"Progress: {i}/{total}")
            
    # Stitch
    if DEBUG_ENABLED:
        stitch_debug_map(config)

if __name__ == "__main__":
    main()
