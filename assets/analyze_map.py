from PIL import Image
from collections import Counter
import os

# Increase limit for large images
Image.MAX_IMAGE_PIXELS = None

INPUT_FILE = "TheMap.png"

def analyze_colors():
    if not os.path.exists(INPUT_FILE):
        print(f"Error: {INPUT_FILE} not found.")
        return

    print(f"Opening {INPUT_FILE} for color analysis...")
    img = Image.open(INPUT_FILE)
    
    # Resize heavily for quick sampling (e.g., down to 1024x1024 or even smaller)
    # We just want dominant colors
    print("Resampling image for color statistics...")
    small_img = img.resize((1024, 1024), Image.Resampling.NEAREST)
    
    # Convert to RGB to ignore alpha if present
    small_img = small_img.convert("RGB")
    
    pixels = list(small_img.getdata())
    color_counts = Counter(pixels)
    
    print("\nTop 20 Most Common Colors (R, G, B):")
    total_pixels = len(pixels)
    for color, count in color_counts.most_common(20):
        percentage = (count / total_pixels) * 100
        print(f"Color {color}: {count} pixels ({percentage:.2f}%)")

if __name__ == "__main__":
    analyze_colors()
