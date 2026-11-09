import sys, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter
OUT = sys.argv[1]
DJ = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
INTER_B = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
INTER = "/usr/share/fonts/opentype/inter/Inter-Medium.otf"
ACC = (64, 156, 255)

def make(W, H, panel, header_h, title_px, sub_px, knight_px, credit_px):
    # diagonal gradient
    img = Image.new("RGB", (W, H))
    px = img.load()
    c0, c1 = (7, 10, 20), (20, 28, 48)
    for y in range(H):
        for x in range(0, W):
            t = (x / W * 0.45 + y / H * 0.55)
            px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
    # soft accent glow top-left
    glow = Image.new("L", (W, H), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-W*0.25, -H*0.6, W*0.55, H*0.45), fill=70)
    glow = glow.filter(ImageFilter.GaussianBlur(W/10))
    img = Image.composite(Image.new("RGB", (W, H), (30, 70, 140)), img, glow)
    # faint grid
    grid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    g = ImageDraw.Draw(grid)
    step = W // 40
    for x in range(0, W, step): g.line([(x, 0), (x, H)], fill=(120, 160, 255, 10))
    for y in range(0, H, step): g.line([(0, y), (W, y)], fill=(120, 160, 255, 10))
    img = Image.alpha_composite(img.convert("RGBA"), grid)
    # big faint knight bottom-right
    kn = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    kd = ImageDraw.Draw(kn)
    kf = ImageFont.truetype(DJ, knight_px)
    kd.text((W - knight_px*0.78, H - knight_px*1.05), "♞", font=kf, fill=(140, 180, 255, 22))
    img = Image.alpha_composite(img, kn)
    # header: small knight + title + subtitle + accent line
    hd = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(hd)
    x0 = panel[0]
    tf = ImageFont.truetype(INTER_B, title_px)
    sf = ImageFont.truetype(INTER, sub_px)
    ks = ImageFont.truetype(DJ, int(title_px*1.25))
    ty = (header_h - title_px) // 2 - title_px // 6
    d.text((x0, ty - title_px*0.18), "♞", font=ks, fill=ACC + (255,))
    tx = x0 + int(title_px*1.25)
    d.text((tx, ty), "BLACKKNIGHT", font=tf, fill=(235, 240, 250, 255))
    tw = d.textlength("BLACKKNIGHT", font=tf)
    d.text((tx + tw + title_px*0.5, ty + (title_px - sub_px)*0.62), "network boot", font=sf, fill=(140, 165, 205, 255))
    rtxt = "netboot.xyz  •  10.10.10.98"
    rw = d.textlength(rtxt, font=sf)
    d.text((panel[2] - rw, ty + (title_px - sub_px)*0.62), rtxt, font=sf, fill=(110, 130, 165, 255))
    img = Image.alpha_composite(img, hd)
    # panel: drop shadow + translucent dark body + accent top edge
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([panel[0]+6, panel[1]+10, panel[2]+6, panel[3]+10], radius=18, fill=(0, 0, 0, 140))
    sh = sh.filter(ImageFilter.GaussianBlur(16))
    img = Image.alpha_composite(img, sh)
    pn = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    p = ImageDraw.Draw(pn)
    p.rounded_rectangle(panel, radius=16, fill=(6, 9, 17, 225), outline=(70, 95, 140, 120), width=2)
    p.rounded_rectangle([panel[0], panel[1], panel[2], panel[1]+4], radius=2, fill=ACC + (255,))
    img = Image.alpha_composite(img, pn)
    # credit, right-aligned under the panel
    cr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    c = ImageDraw.Draw(cr)
    cf = ImageFont.truetype(INTER, credit_px)
    l1, l2 = "Coded by Spencer Reiser", "http://github.com/Sonni4154"
    y1 = panel[3] + (H - panel[3] - credit_px*2.5) / 2
    c.text((panel[2] - c.textlength(l1, font=cf), y1), l1, font=cf, fill=(150, 170, 205, 255))
    c.text((panel[2] - c.textlength(l2, font=cf), y1 + credit_px*1.35), l2, font=cf, fill=ACC + (230,))
    img = Image.alpha_composite(img, cr)
    return img.convert("RGB")

# 1920x1080: text box = margins L/R 384, top 196, bottom 108 -> 1152x776 (144x48 chars)
make(1920, 1080, [360, 168, 1560, 996], 168, 52, 26, 640, 22).save(OUT + "/bg-1920x1080.png", optimize=True)
# 1024x768: text box = margins L/R 56, top 124, bottom 72 -> 912x572 (114x35 chars)
make(1024, 768, [36, 100, 988, 712], 100, 34, 17, 380, 13).save(OUT + "/bg-1024x768.png", optimize=True)
