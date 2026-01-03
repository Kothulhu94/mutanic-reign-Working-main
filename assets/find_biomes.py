from PIL import Image
from collections import Counter
import os
import glob

# Scan a diagonal and corners to find biome variation
# 0,0 (Top Left), 8,8 (Center), 15,15 (Bottom Right), etc.
CHUNKS_TO_SCAN = [
    "map_chunks/map_0_0.png",
    "map_chunks/map_0_15.png",
    "map_chunks/map_15_0.png",
    "map_chunks/map_15_15.png",
    "map_chunks/map_8_8.png",
    "map_chunks/map_4_4.png",
    "map_chunks/map_12_4.png"
]

def find_biomes():
    print("Scanning chunks for biome colors...")
    
    unique_colors = Counter()
    
    for chunk_path in CHUNKS_TO_SCAN:
        if not os.path.exists(chunk_path):
            continue
            
        print(f"Scanning {chunk_path}...")
        img = Image.open(chunk_path).convert("RGB")
        # Resize to minimal thumb to get dominant vibes
        thumb = img.resize((100, 100), Image.Resampling.NEAREST)
        unique_colors.update(thumb.getdata())
        
    print("\nTop 30 Global Colors (excluding near-blacks):")
    
    # Filter out near-blacks (assuming < 40 total brightness is 'void')
    visible_colors = {
        k: v for k, v in unique_colors.items() 
        if sum(k) > 50
    }
    
    # Sort by frequency
    sorted_colors = sorted(visible_colors.items(), key=lambda x: x[1], reverse=True)
    
    for color, count in sorted_colors[:30]:
        print(f"Color {color} - Count: {count}")

if __name__ == "__main__":
    find_biomes()
