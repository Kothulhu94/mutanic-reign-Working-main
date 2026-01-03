from PIL import Image
from collections import Counter
import os
import math

# Allow loading massive images
Image.MAX_IMAGE_PIXELS = None

# Use the original map or a few representative chunks
INPUT_FILE = "TheMap.png"

def get_distinct_palette():
    print(f"Scanning {INPUT_FILE} for distinct distinct colors...")
    
    try:
        # Load low-res but using NEAREST to preserve exact pixel values (no blurring)
        img = Image.open(INPUT_FILE)
        
        # Resize to 2048x2048 to get enough detail but manageable
        # NEAREST is crucial to keep "Sand" as "Sand Color" and not "Sand+Grass Blend"
        img = img.resize((2048, 2048), Image.Resampling.NEAREST)
        img = img.convert("RGB")
        
        pixels = list(img.getdata())
        
        # Count all colors
        counts = Counter(pixels)
        
        print(f"Found {len(counts)} unique colors in sample.")
        
        # Filter out "Common Grays" and "Blacks" to find the interesting stuff
        # We classify based on Saturation or just ignore near-grays
        
        interesting_colors = {}
        for color, count in counts.items():
            r, g, b = color
            
            # Brightness
            lum = 0.299*r + 0.587*g + 0.114*b
            
            # Saturation-ish (Difference between max and min channel)
            sat = max(r, g, b) - min(r, g, b)
            
            # Filter:
            # - Ignore too dark (Void/Water?) -> Keep water candidates separately?
            # - Ignore too gray (Roads/Mountains?) unless requested
            
            # We want Sand (Yellowish) and Snow (White)
            
            # Snow Candidate: High Lum, Low Sat?
            if lum > 200 and sat < 20: 
                group = "Potential Snow"
            
            # Sand Candidate: Yellow/Brown? (R > B, G > B)
            elif r > b + 20 and g > b + 10 and lum > 50:
                 group = "Potential Sand/Earth"
                 
            # Water Candidate: Blueish? (B > R, B > G) or Dark?
            elif b > r + 10 and b > g + 10:
                group = "Potential Water"
            
            # Dark Void
            elif lum < 20:
                group = "Potential Void"
                
            else:
                group = "Other/Grass/Rock"
            
            if group not in interesting_colors:
                interesting_colors[group] = Counter()
            interesting_colors[group][color] = count

        print("\n=== PALETTE REPORT ===")
        for group, counter in interesting_colors.items():
            print(f"\n[{group}] Top 5:")
            for color, count in counter.most_common(5):
                print(f"  RGB: {color} - Count: {count}")
                
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    get_distinct_palette()
