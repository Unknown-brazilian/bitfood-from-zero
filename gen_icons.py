#!/usr/bin/env python3
"""
Generate adaptive launcher icons for all 3 BitFood Flutter apps.
Sizes: mdpi(48), hdpi(72), xhdpi(96), xxhdpi(144), xxxhdpi(192)
Play Store: 512x512 hi-res
"""
from PIL import Image, ImageDraw
import os, math

# iFood red
PRIMARY = "#EA1D2C"
BG = "#F7F7F7"

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def draw_fork_knife(draw, cx, cy, size, color):
    """Simple fork+knife silhouette scaled to size."""
    lw = max(2, size // 20)
    h = size * 0.55
    ys = cy - h / 2
    # Knife (right)
    kx = cx + size * 0.10
    draw.line([(kx, ys), (kx, ys + h)], fill=color, width=lw)
    draw.rectangle([kx - lw, ys, kx + lw*1.5, ys + h*0.35], fill=color)
    # Fork (left)
    fx = cx - size * 0.12
    draw.line([(fx, ys), (fx, ys + h)], fill=color, width=lw)
    for dx in [-size*0.055, 0, size*0.055]:
        tx = fx + dx
        draw.line([(tx, ys), (tx, ys + h*0.38)], fill=color, width=lw)

def draw_lightning(draw, cx, cy, size, color):
    """Lightning bolt silhouette."""
    w, h = size * 0.40, size * 0.60
    pts = [
        (cx + w*0.15, cy - h/2),
        (cx - w*0.05, cy + h*0.05),
        (cx + w*0.15, cy + h*0.05),
        (cx - w*0.15, cy + h/2),
        (cx + w*0.05, cy - h*0.05),
        (cx - w*0.15, cy - h*0.05),
    ]
    draw.polygon(pts, fill=color)

def make_icon(path, size, symbol, bg_color=PRIMARY, fg_color="white"):
    img = Image.new("RGBA", (size, size), (0,0,0,0))
    draw = ImageDraw.Draw(img)
    r = hex_to_rgb(bg_color)
    # Rounded rectangle background
    corner = size // 5
    draw.rounded_rectangle([0, 0, size-1, size-1], radius=corner, fill=r)
    cx, cy = size / 2, size / 2
    if symbol == "fork_knife":
        draw_fork_knife(draw, cx, cy, size, fg_color)
        # Lightning bolt bottom-right overlay
        sub = size * 0.30
        scx = cx + size * 0.20
        scy = cy + size * 0.20
        draw_lightning(draw, scx, scy, sub, "#FF6900")
    elif symbol == "restaurant":
        draw_fork_knife(draw, cx, cy, size, fg_color)
    elif symbol == "rider":
        # Simple scooter / person icon
        hw = size * 0.30
        # head
        hr = size * 0.10
        draw.ellipse([cx - hr, cy - size*0.28 - hr, cx + hr, cy - size*0.28 + hr], fill=fg_color)
        # body
        draw.line([(cx, cy - size*0.18), (cx, cy + size*0.06)], fill=fg_color, width=max(2, size//18))
        # arms
        draw.line([(cx - hw, cy - size*0.06), (cx + hw, cy - size*0.06)], fill=fg_color, width=max(2, size//18))
        # legs / wheels
        draw.line([(cx - hw*0.6, cy + size*0.06), (cx - hw*0.6, cy + size*0.20)], fill=fg_color, width=max(2, size//18))
        draw.line([(cx + hw*0.6, cy + size*0.06), (cx + hw*0.6, cy + size*0.20)], fill=fg_color, width=max(2, size//18))
        wr = size * 0.09
        draw.ellipse([cx - hw*0.6 - wr, cy + size*0.20 - wr, cx - hw*0.6 + wr, cy + size*0.20 + wr], outline=fg_color, width=max(2, size//22))
        draw.ellipse([cx + hw*0.6 - wr, cy + size*0.20 - wr, cx + hw*0.6 + wr, cy + size*0.20 + wr], outline=fg_color, width=max(2, size//22))
        # lightning bolt (bottom right)
        sub = size * 0.28
        draw_lightning(draw, cx + size*0.22, cy + size*0.28, sub, "#FF6900")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")

# Density -> size map
DENSITIES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

APPS = [
    ("customer", "fork_knife"),
    ("restaurant", "restaurant"),
    ("rider", "rider"),
]

BASE = "/home/unknown/Desktop/bitfood/bitfood-from-zero/apps"

for app, symbol in APPS:
    res_dir = f"{BASE}/{app}/android/app/src/main/res"
    for density, size in DENSITIES.items():
        make_icon(f"{res_dir}/{density}/ic_launcher.png", size, symbol)
        make_icon(f"{res_dir}/{density}/ic_launcher_round.png", size, symbol)
    # Play Store hi-res 512x512
    make_icon(f"{BASE}/{app}/store/ic_launcher_512.png", 512, symbol)
    print(f"  {app} icons done")

print("All icons generated.")
