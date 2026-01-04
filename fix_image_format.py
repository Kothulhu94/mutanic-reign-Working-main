from PIL import Image
import os

path = "d:/GodoTDev/mutanic-reign-Working-main/art_src/GemMine.png"
try:
    img = Image.open(path)
    # Force load data
    img.load() 
    # Save as PNG explicitly
    img.save(path, format="PNG")
    print(f"Converted {path} to actual PNG format.")
except Exception as e:
    print(f"Error converting: {e}")
