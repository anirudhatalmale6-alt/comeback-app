"""Bake the chrome reflection maps.

The look is derived rather than hand-painted: the nail is modelled as a curved
surface, the view direction is reflected off that surface, and the reflected
ray is looked up in a small analytic "studio" environment. That is what makes
the highlights follow the shape of the nail instead of sitting on top of it as
stripes, and it is why the bands bow inwards as the nail narrows to the tip.

Three maps come out:
  chrome_mirror.png  greyscale, composited over the nail colour with hardLight
                     (0 -> black, 0.5 -> the colour untouched, 1 -> white), so
                     every colour gets its own dark-and-light metal ramp.
  chrome_gloss.png   white + alpha, the clear top coat's own specular. Added
                     with BlendMode.plus so it reads wet on top of the metal.
  chrome_irid.png    RGB + alpha, the faint colour roll a chrome powder throws.

Each map is an ATLAS of NVAR tiles. The geometry is identical in every tile --
it has to be, it is the same nail -- but the environment is rotated a little,
so five nails on one hand reflect the room from slightly different angles
instead of being five copies of one stamp.
"""
import numpy as np
from PIL import Image

TW, TH = 256, 384        # one tile = one nail
NVAR = 4                 # how many environment variations are baked
# Azimuth / elevation nudge per tile. Small: these are five fingers of one
# hand, not five different rooms.
VAR = [(0.00, 0.00), (0.16, -0.05), (-0.13, 0.04), (0.29, 0.02)]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def band(x, centre, half, soft):
    """1 inside [centre-half, centre+half], falling to 0 over `soft`."""
    return 1.0 - smoothstep(half, half + soft, np.abs(x - centre))


# ---------------------------------------------------------------- geometry
u = (np.arange(TW) + 0.5) / TW        # 0..1 across the nail
v = (np.arange(TH) + 0.5) / TH        # 0 = free edge, 1 = cuticle
U, V = np.meshgrid(u, v)

# A nail is only as wide as its silhouette at a given height, and it is much
# narrower at the free edge. Normalising the cross position by that half-width
# is what bows the reflection bands inward as they run down to the tip: at the
# tip the same sweep of the room is squeezed into a third of the width.
halfw = np.clip(0.40 + 1.30 * V, 0.40, 1.0)
halfw = np.where(V > 0.62, 1.0 - 0.15 * smoothstep(0.62, 1.0, V), halfw)
cx = np.clip((2 * U - 1) / halfw, -1.30, 1.30)

# C-curve across the nail, tighter at the free edge where a nail curls more.
# Kept modest on purpose: a wide sweep drags a whole room across the nail and
# comes out as stripes, which is the brushed-metal look, not a mirror.
A = 0.78 * (1.0 + 0.30 * (1.0 - V))
ang_x = A * cx
# Lengthwise curve, positive at the free edge. This is what tilts the horizon
# and bows the bands; flat, the reflection is just columns. Positive at the tip
# means the tip looks UP into the room and the cuticle looks DOWN at the floor,
# which is the way round a hand is actually held and photographed.
B = 0.40
ang_y = B * np.clip((0.62 - V) / 0.62, -0.70, 1.0)

nx = np.sin(ang_x) * np.cos(ang_y)
ny = np.sin(ang_y)
nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 1e-6, 1.0))

# Reflect the view direction (0,0,1) about the normal.
rx = 2 * nz * nx
ry = 2 * nz * ny
rz = 2 * nz * nz - 1.0

AZI = np.arctan2(rx, rz)              # sweeps across the width
ELE = np.arcsin(np.clip(ry, -1, 1))   # sweeps along the length


# ------------------------------------------------------------- environment
def studio(a, b):
    """Luminance of the room in the direction (azimuth a, elevation b)."""
    # Ceiling above, floor below, with a horizon between them. The horizon is
    # the single strongest "this is a mirror" cue: a reflective surface shows
    # you the edge of the room, and a painted one never does.
    ceiling = 0.62 + 0.15 * smoothstep(0.04, 0.55, b)
    # Below the horizon it is just floor: a calm ramp with one soft bounce.
    # Calm is the point. Every light I put down here came out as a bright bar
    # laid across the vertical bands, and a horizontal bar crossing vertical
    # bars is the "patterned / dark cross" look, not a reflection.
    floor = 0.34 + 0.13 * smoothstep(-0.70, -0.30, b)
    above = smoothstep(-0.26, -0.02, b)
    L = floor + (ceiling - floor) * above

    # How much of the room's detail survives at a given elevation. Everything
    # below the horizon is floor, and a floor has no windows in it, so the
    # lights fade out as the reflection drops past the horizon.
    lit = 0.18 + 0.82 * above

    # The key light: a big softbox off to one side. Crisp-edged, because a
    # mirror shows a light's edge sharply and a satin surface does not.
    L += lit * 0.34 * band(a, -0.46, 0.24, 0.10) * band(b, 0.18, 1.05, 0.55)
    # A dark wall pressed right up against it. The jump between the two is
    # where the metal comes from; brightness on its own just looks pale.
    L -= lit * 0.17 * band(a, 0.26, 0.15, 0.13)
    # Two narrow strip lights further round, so the surface is not two tones.
    L += lit * 0.22 * band(a, 0.72, 0.065, 0.07)
    L += lit * 0.13 * band(a, -1.02, 0.05, 0.08)
    # The room falls away at the far ends of the sweep.
    L -= lit * 0.11 * smoothstep(1.05, 1.70, np.abs(a))
    return L


# Fresnel: where the surface rolls away from the eye it stops showing the room
# and starts showing the light behind it, so the very edge lifts. Kept narrow;
# widened it turns into a halo and the nail looks like a sticker.
FRES = np.power(1.0 - nz, 3.0)


def mirror_tile(dazi, dele):
    L = studio(AZI + dazi, ELE + dele)
    L = L + 0.30 * FRES
    # The free edge is thin and translucent and always catches light.
    L = L + 0.30 * (1.0 - smoothstep(0.0, 0.024, V))
    # The cuticle rolls over the same way, more faintly.
    L = L + 0.13 * smoothstep(0.976, 1.0, V)
    # Centre the range on 0.5 so hardLight leaves the nail's own colour clearly
    # recognisable. The gain is deliberately modest: the depth has to come from
    # how FAST the tone changes, not from how far it travels. Cranked past this
    # the nail turns into black-and-white bars and the colour disappears --
    # which is exactly what went wrong the last three times.
    return np.clip(0.5 + (L - 0.50) * 1.18, 0.0, 1.0)


# ------------------------------------------------------------------- gloss
def spec(ldir, power, gain):
    lx, ly, lz = ldir
    n = (lx * lx + ly * ly + lz * lz) ** 0.5
    lx, ly, lz = lx / n, ly / n, lz / n
    hx, hy, hz = lx, ly, lz + 1.0          # half-vector, with V = (0,0,1)
    hn = (hx * hx + hy * hy + hz * hz) ** 0.5
    ndoth = np.clip((nx * hx + ny * hy + nz * hz) / hn, 0.0, 1.0)
    return gain * np.power(ndoth, power)


def gloss_tile(dazi):
    # The clear top coat's own reflection, on top of the metal: one tight wet
    # catch-light plus a smaller second one. Real gloss never has exactly one.
    g = spec((-0.26 + dazi * 0.6, 0.52, 0.86), 220.0, 0.80)
    g += spec((0.40 + dazi * 0.6, -0.14, 0.90), 420.0, 0.30)
    return np.clip(g, 0.0, 1.0)


# --------------------------------------------------------------- iridescence
def irid_tile(dazi, L):
    # A chrome powder shifts hue as the surface turns away from you. Ride the
    # shift on the azimuth, and only let it show in the MID-tones: iridescence
    # is invisible inside a blown highlight and invisible inside a black.
    hue = (((AZI + dazi) + 2.2) / 4.4 * 1.15) % 1.0
    a = 0.75 * np.power(1.0 - np.abs(2 * L - 1.0), 1.5)
    # Pull it back over the cuticle third. Down there the reflection is
    # floor rather than room, the tones are flat, and a hue roll on flat
    # tones reads as a stain rather than a shimmer.
    a = a * (1.0 - 0.55 * smoothstep(0.66, 1.0, V))
    hsv = np.stack([hue, np.full_like(hue, 0.55), np.full_like(hue, 0.55)], -1)
    rgb = np.asarray(
        Image.fromarray((hsv * 255).astype(np.uint8), "HSV").convert("RGB"),
        np.float32) / 255.0
    return rgb, np.clip(a, 0.0, 1.0)


# --------------------------------------------------------------------- bake
def bake(out_dir="."):
    mir = np.zeros((TH, TW * NVAR), np.float32)
    glo = np.zeros((TH, TW * NVAR), np.float32)
    irgb = np.zeros((TH, TW * NVAR, 3), np.float32)
    ia = np.zeros((TH, TW * NVAR), np.float32)

    for k, (da, de) in enumerate(VAR):
        x0 = k * TW
        L = mirror_tile(da, de)
        mir[:, x0:x0 + TW] = L
        glo[:, x0:x0 + TW] = gloss_tile(da)
        rgb, a = irid_tile(da, L)
        irgb[:, x0:x0 + TW] = rgb
        ia[:, x0:x0 + TW] = a

    Image.fromarray((mir * 255).astype(np.uint8), "L").save(
        f"{out_dir}/chrome_mirror.png")

    g = np.zeros((TH, TW * NVAR, 4), np.uint8)
    g[..., :3] = 255
    g[..., 3] = (glo * 255).astype(np.uint8)
    Image.fromarray(g, "RGBA").save(f"{out_dir}/chrome_gloss.png")

    ir = np.zeros((TH, TW * NVAR, 4), np.uint8)
    ir[..., :3] = (irgb * 255).astype(np.uint8)
    ir[..., 3] = (ia * 255).astype(np.uint8)
    Image.fromarray(ir, "RGBA").save(f"{out_dir}/chrome_irid.png")
    print(f"baked {NVAR} tiles of {TW}x{TH}")


if __name__ == "__main__":
    bake()
