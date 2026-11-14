from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parent.parent
DRAWINGS = ROOT.parent / "assets" / "drawings"
OUT = ROOT / "assets" / "art"
SIZE = 198
IDS = ["yellow", "orange", "lime", "green", "teal", "cyan", "sky_blue", "blue", "pink", "brown", "gray", "white"]


def find_ball(img: Image.Image) -> tuple[float, float, float]:
	a = np.asarray(img.convert("RGB")).astype(np.int16)
	ink = a.min(axis=2) < 215
	ys, xs = np.nonzero(ink)
	x0, x1 = np.percentile(xs, [0.2, 99.8])
	y0, y1 = np.percentile(ys, [0.2, 99.8])
	return (x0 + x1) / 2.0, (y0 + y1) / 2.0, max(x1 - x0, y1 - y0) / 2.0


def cut(path: Path) -> Image.Image:
	img = Image.open(path).convert("RGB")
	cx, cy, r = find_ball(img)
	r += 3
	box = (int(cx - r), int(cy - r), int(cx + r), int(cy + r))
	crop = img.crop(box).convert("RGBA")
	n = crop.width
	k = 4
	mask = Image.new("L", (n * k, n * k), 0)
	ImageDraw.Draw(mask).ellipse((0, 0, n * k - 1, n * k - 1), fill=255)
	crop.putalpha(mask.resize((n, n), Image.LANCZOS))
	return crop.resize((SIZE, SIZE), Image.LANCZOS)


def sad(ball: Image.Image) -> Image.Image:
	out = ball.copy()
	d = SIZE
	box = (int(d * 0.2), int(d * 0.54), int(d * 0.8), int(d * 0.84))
	band = np.asarray(out.crop(box)).astype(np.float32)
	lum = band[..., :3].mean(axis=2)
	fill = np.median(lum[band[..., 3] > 200])
	ink = lum < fill * 0.88
	for _ in range(2):
		grown = ink.copy()
		grown[1:, :] |= ink[:-1, :]
		grown[:-1, :] |= ink[1:, :]
		grown[:, 1:] |= ink[:, :-1]
		grown[:, :-1] |= ink[:, 1:]
		ink = grown & (band[..., 3] > 200)
	clean = band.copy()
	rows = np.arange(band.shape[0])
	for x in range(band.shape[1]):
		col_ink = ink[:, x]
		if col_ink.any() and (~col_ink).sum() >= 2:
			for ch in range(3):
				clean[col_ink, x, ch] = np.interp(rows[col_ink], rows[~col_ink], band[~col_ink, x, ch])
	flipped = band[::-1, :]
	darker = flipped[..., :3].mean(axis=2) < clean[..., :3].mean(axis=2)
	frown = ink[::-1, :] & darker & (band[..., 3] > 200)
	clean[frown, :3] = flipped[frown, :3]
	clean[..., 3] = band[..., 3]
	out.paste(Image.fromarray(clean.clip(0, 255).astype(np.uint8), "RGBA"), box[:2])
	rgb = ImageEnhance.Brightness(out.convert("RGB")).enhance(0.88)
	rgb = ImageEnhance.Color(rgb).enhance(0.8)
	rgb.putalpha(out.getchannel("A"))
	draw = ImageDraw.Draw(rgb)
	crack = [(d * 0.62, d * 0.06), (d * 0.57, d * 0.2), (d * 0.66, d * 0.27), (d * 0.6, d * 0.38)]
	draw.line(crack, fill=(20, 20, 20, 255), width=5, joint="curve")
	draw.line([(d * 0.57, d * 0.2), (d * 0.48, d * 0.24)], fill=(20, 20, 20, 255), width=4)
	return rgb


def main() -> None:
	for vid in IDS:
		src = DRAWINGS / f"ball_{vid}.jpg"
		ball = cut(src)
		ball.save(OUT / f"variety_{vid}.png")
		sad(ball).save(OUT / f"variety_{vid}_dead.png")
	icon = Image.open(DRAWINGS / "sunset_smiley.jpg").convert("RGB")
	cx, cy, r = find_ball(icon)
	icon.crop((int(cx - r), int(cy - r), int(cx + r), int(cy + r))).resize((256, 256), Image.LANCZOS).save(ROOT / "icon.png")
	print("cut", len(IDS), "balls")


if __name__ == "__main__":
	main()
