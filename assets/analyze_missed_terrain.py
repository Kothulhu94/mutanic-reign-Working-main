import os
import json
import math
from PIL import Image
from collections import Counter

# Allow massive images
Image.MAX_IMAGE_PIXELS = None

CONFIG_FILE = "terrain_config.json"
INPUT_FILE = "TheMap.png"

def load_config():
    with open(CONFIG_FILE, 'r') as f:
        return json.load(f)

def color_distance(c1, c2):
    r = c1[0] - c2[0]
    g = c1[1] - c2[1]
    b = c1[2] - c2[2]
    return math.sqrt(r*r + g*g + b*b)

def analyze_missed():
    print(f"Analyzing {INPUT_FILE} for missed terrain shades...")
    
    if not os.path.exists(CONFIG_FILE):
        print("Config missing.")
        return

    config = load_config()
    terrain_defs = config["terrain_types"]
    
    # Pre-parse
    targets = []
    for key, data in terrain_defs.items():
        targets.append({
            "name": key,
            "color": tuple(data["color"]),
            "tol": data["tolerance"]
        })

    # Load and resize for speed (higher res than before to catch details)
    img = Image.open(INPUT_FILE).convert("RGB")
    # 2048 is decent balance
    img = img.resize((2048, 2048), Image.Resampling.NEAREST)
    pixels = list(img.getdata())
    
    missed_counts = Counter()
    
    # Track which biome "almost" claimed it
    missed_by_biome = {t["name"]: Counter() for t in targets}
    
    print("Partitioning pixels...")
    global_missed = Counter()
    
    for px in pixels:
        matched = False
        
        # Check if it matches ANY current definition
        for t in targets:
            dist = color_distance(px, t["color"])
            if dist <= t["tol"]:
                matched = True
                break
        
        if matched:
            continue
            
        # If not matched, check if it was "Close" (e.g. within 2x tolerance)
        # Also track globally
        global_missed[px] += 1
        
        for t in targets:
            dist = color_distance(px, t["color"])
            # 3x tolerance window to catch the "shades" user mentioned
            if dist <= (t["tol"] * 3.0):
                missed_by_biome[t["name"]][px] += 1
                
    print("\n=== GLOBAL UNMATCHED COLORS (Top 10) ===")
    for color, count in global_missed.most_common(10):
        print(f"  Color {color} - Count: {count}")
    
    print("\n=== MISSED SHADES BY BIOME ===")
    
    found_suggestions = {}
    
    for name, counter in missed_by_biome.items():
        print(f"\n[{name}] Missed Candidate Shades:")
        if not counter:
            print("  (None found in 3x range)")
            continue
            
        # Get top 3 most common "missed" colors for this biome
        top_misses = counter.most_common(5)
        suggestions = []
        
        for color, count in top_misses:
            print(f"  Color {color} - Count: {count}")
            suggestions.append(color)
            
        found_suggestions[name] = suggestions

    return found_suggestions

if __name__ == "__main__":
    analyze_missed()
