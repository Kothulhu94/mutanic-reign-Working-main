from PIL import Image
import os

path = "d:/GodoTDev/mutanic-reign-Working-main/art_src/GemMine.png"
if not os.path.exists(path):
    print("File not found")
    exit(1)

try:
    img = Image.open(path)
    print(f"Format: {img.format}")
    print(f"Size: {img.size}")
    print(f"Mode: {img.mode}")
    img.verify()
    print("Verification successful")
except Exception as e:
    print(f"Invalid image: {e}")
