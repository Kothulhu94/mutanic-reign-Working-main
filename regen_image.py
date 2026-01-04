from PIL import Image
import os

src = "d:/GodoTDev/mutanic-reign-Working-main/art_src/GemMine.png"
dst = "d:/GodoTDev/mutanic-reign-Working-main/art_src/GemMine_v2.png"

try:
    img = Image.open(src)
    # Convert to RGBA clearly
    img = img.convert("RGBA")
    # Save as new file
    img.save(dst, format="PNG")
    print(f"Saved {dst}")
except Exception as e:
    print(f"Error: {e}")
