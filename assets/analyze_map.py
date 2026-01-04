import json
import math
import os
from collections import Counter
from PIL import Image

# Config
CONFIG_FILE = "terrain_config.json"
INPUT_FILE = "TheMap.png"

# Increase limit for large images
Image.MAX_IMAGE_PIXELS = None

def load_config():
    if not os.path.exists(CONFIG_FILE):
        print(f"Warning: {CONFIG_FILE} not found. Using defaults.")
        return {}
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

def color_distance(c1, c2):
    # Euclidean distance
    r = c1[0] - c2[0]
    g = c1[1] - c2[1]
    b = c1[2] - c2[2]
    return math.sqrt(r*r + g*g + b*b)

def analyze_map():
    config = load_config()
    terrain_types = config.get("terrain_types", {})
    
    # Find Water Config
    water_def = terrain_types.get("WATER")
    if not water_def:
        print("Config missing WATER definition. Cannot analyze rivers specifically.")
        return

    water_color = tuple(water_def["color"])
    water_tol = water_def["tolerance"]
    
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        return

    print(f"Analyzing {INPUT_FILE} using strict water tolerance: {water_tol}")
    img = Image.open(INPUT_FILE).convert("RGB")
    
    # We analyze a resized version for speed/relevance essentially mocking the baker
    # But for "Precision" we might want to look at full res? 
    # The baker resizes to 256 or 512. Let's start with a reasonable analysis resolution.
    target_res = 1024
    print(f"Resampling to {target_res}x{target_res} for analysis...")
    img = img.resize((target_res, target_res), Image.Resampling.NEAREST)
    pixels = img.load()
    width, height = img.size
    
    near_misses = 0
    diagonal_gaps = 0
    total_water = 0
    
    # Grid for connectivity check
    # 0 = Other, 1 = Water
    grid = [[0 for _ in range(width)] for _ in range(height)]
    
    print("Classifying pixels...")
    for y in range(height):
        for x in range(width):
            px = pixels[x, y]
            dist = color_distance(px, water_color)
            
            if dist <= water_tol:
                grid[y][x] = 1
                total_water += 1
            elif dist <= water_tol * 1.5:
                # Recorded as a near miss (potential missing pixel)
                near_misses += 1
    
    print("Checking for diagonal gaps...")
    # logic:
    # 1 0
    # 0 1
    # or
    # 0 1
    # 1 0
    
    for y in range(height - 1):
        for x in range(width - 1):
            tl = grid[y][x]
            tr = grid[y][x+1]
            bl = grid[y+1][x]
            br = grid[y+1][x+1]
            
            # Diagonal Case 1
            if tl == 1 and br == 1 and tr == 0 and bl == 0:
                diagonal_gaps += 1
                
            # Diagonal Case 2
            if tr == 1 and bl == 1 and tl == 0 and br == 0:
                diagonal_gaps += 1

    print("-" * 40)
    print("ANALYSIS REPORT")
    print("-" * 40)
    print(f"Total Water Pixels: {total_water}")
    print(f"Near Misses:        {near_misses} (Pixels within 1.5x tolerance)")
    print(f"Diagonal Gaps:      {diagonal_gaps} (Potential crossings)")
    
    if near_misses > 0:
        print("\nSUGGESTION: Consider increasing WATER tolerance slightly (e.g. +5 or +10)")
        print("            or enable 'Fill Holes' in baker.")
        
    if diagonal_gaps > 0:
        print("\nSUGGESTION: Enable 'Stitch Diagonals' in baker to close these gaps.")

if __name__ == "__main__":
    analyze_map()
