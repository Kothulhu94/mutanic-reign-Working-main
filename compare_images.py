from PIL import Image
import os

files = [
    "d:/GodoTDev/mutanic-reign-Working-main/Actors/Bus_Sprite.png", 
    "d:/GodoTDev/mutanic-reign-Working-main/art_src/GemMine.png"
]

for f in files:
    print(f"\nAnalyzing: {f}")
    if not os.path.exists(f):
        print("  Files does not exist")
        continue
    try:
        img = Image.open(f)
        print(f"  Format: {img.format}")
        print(f"  Mode: {img.mode}")
        print(f"  Size: {img.size}")
        print(f"  Info keys: {list(img.info.keys())}")
        if 'icc_profile' in img.info:
            print("  Has ICC Profile: Yes")
        
        # Check actual pixel data type
        extrema = img.getextrema()
        print(f"  Extrema: {extrema}")
        
    except Exception as e:
        print(f"  Error: {e}")
