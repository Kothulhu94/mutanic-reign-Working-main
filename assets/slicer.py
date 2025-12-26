from PIL import Image
import os

# Increase the limit for large images (16384x16384 is ~268MP)
Image.MAX_IMAGE_PIXELS = None

# CONFIGURATION
INPUT_FILE = "TheMap.png" # Path to your actual map file
OUTPUT_DIR = "map_chunks"
CHUNK_SIZE = 1024

def slice_map():
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    print(f"Loading massive image: {INPUT_FILE}...")
    # This might take a few seconds to load 1GB into RAM
    try:
        img = Image.open(INPUT_FILE)
    except FileNotFoundError:
        print(f"Error: {INPUT_FILE} not found. Please ensure it is in the same folder.")
        return

    width, height = img.size
    
    print(f"Image Size: {width}x{height}")
    
    # Calculate grid size (Should be 16x16 for a 16384 image)
    cols = width // CHUNK_SIZE
    rows = height // CHUNK_SIZE
    
    print(f"Slicing into {cols}x{rows} grid ({cols*rows} total chunks)...")

    for x in range(cols):
        for y in range(rows):
            # Calculate coordinates
            left = x * CHUNK_SIZE
            upper = y * CHUNK_SIZE
            right = left + CHUNK_SIZE
            lower = upper + CHUNK_SIZE
            
            # Crop and save
            chunk = img.crop((left, upper, right, lower))
            filename = f"{OUTPUT_DIR}/map_{x}_{y}.png"
            chunk.save(filename)
            
    print("Done! Check the 'map_chunks' folder.")

if __name__ == "__main__":
    slice_map()
