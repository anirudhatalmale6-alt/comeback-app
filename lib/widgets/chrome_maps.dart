import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// The baked reflection maps behind the chrome finish.
///
/// Chrome is a mirror, and a mirror does not have a look of its own — it shows
/// you the room it is standing in. Every earlier attempt at this finish painted
/// the *appearance* of chrome by hand (a gradient, a stripe, some blurred
/// pools) and none of them held up, because a hand-painted highlight sits ON
/// the nail instead of being bent BY it.
///
/// These maps are produced the other way round, by `tools/bake_chrome_maps.py`:
/// the nail is modelled as a curved surface, the view direction is reflected
/// off that surface, and the reflected ray is looked up in a small analytic
/// studio (ceiling, horizon, floor, a softbox, a dark wall, two strip lights).
/// That is why the bands bow inwards as the nail narrows to the free edge and
/// why the horizon curves — the shape of the nail is doing the work.
///
/// Three maps, composited in this order over the nail's own colour:
///
///   [mirror] greyscale, drawn with [ui.BlendMode.hardLight]: 0 goes black,
///            0.5 leaves the colour untouched, 1 goes white. Every colour
///            therefore gets its OWN metal ramp — gold darkens to bronze and
///            lifts to pale gold, black becomes black chrome — rather than one
///            grey texture wearing a tint.
///   [irid]   the faint hue roll a chrome powder throws, overlaid gently.
///   [gloss]  the clear top coat's own specular, added on top so the metal
///            reads wet rather than dry.
///
/// Each file is an atlas of [tiles] variants. The geometry is identical in
/// every tile (it is the same nail) but the studio is rotated a few degrees, so
/// a hand does not come out as five copies of one stamp.
class ChromeMaps {
  ChromeMaps._();

  /// Number of environment variants baked into each atlas.
  static const int tiles = 4;

  static ui.Image? mirror;
  static ui.Image? irid;
  static ui.Image? gloss;

  static Future<void>? _loading;

  /// True once every map is decoded and the painter can use them. Until then
  /// the chrome finish falls back to a plain metallic gradient, so a missing
  /// or failed asset degrades to something reasonable instead of a blank nail.
  static bool get ready => mirror != null && irid != null && gloss != null;

  /// Decodes the maps once. Safe to call repeatedly.
  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    mirror = await _decode('assets/finishes/chrome_mirror.png');
    irid = await _decode('assets/finishes/chrome_irid.png');
    gloss = await _decode('assets/finishes/chrome_gloss.png');
  }

  static Future<ui.Image?> _decode(String asset) async {
    try {
      final data = await rootBundle.load(asset);
      final codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    } catch (_) {
      // Never let a finish take the app down. [ready] stays false and the
      // painter uses its fallback.
      return null;
    }
  }

  /// The source rectangle of one variant inside an atlas.
  static ui.Rect tile(ui.Image image, int variant) {
    final double w = image.width / tiles;
    final int v = variant.abs() % tiles;
    return ui.Rect.fromLTWH(v * w, 0, w, image.height.toDouble());
  }
}
