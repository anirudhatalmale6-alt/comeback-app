import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "My Colours" — the palette a customer builds up herself.
///
/// Dialling in an exact shade on the colour wheel takes a moment, and until now
/// that shade was gone as soon as she moved on. Saving it puts it at the front
/// of the colour strip, on every nail-colour tab (Solids, French, Chrome, Cat
/// Eye), so a favourite is one tap away next time.
///
/// Stored on the device with shared_preferences, so the palette survives closing
/// the app. Colours are held as opaque ARGB ints, newest first.
class SavedColors {
  static const String _key = 'tryon_saved_colors';

  /// Plenty for a personal palette while keeping the strip scrollable.
  static const int max = 24;

  /// The current palette. Listen to it so every strip rebuilds the moment a
  /// colour is saved or removed, wherever that happened.
  static final ValueNotifier<List<int>> colors = ValueNotifier<List<int>>([]);

  static bool _loaded = false;

  /// Reads the saved palette off the device. Safe to call more than once.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_key) ?? const <String>[];
      colors.value = raw
          .map(int.tryParse)
          .whereType<int>()
          .map((v) => v | 0xFF000000)
          .toList();
    } catch (_) {
      // No storage available (rare) — the palette just stays empty for this
      // run rather than breaking the try-on.
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
          _key, colors.value.map((v) => v.toString()).toList());
    } catch (_) {
      // Keep the in-memory palette working even if the write fails.
    }
  }

  static bool has(int argb) => colors.value.contains(argb | 0xFF000000);

  /// Saves a colour, moving it to the front if it was already there.
  static Future<void> add(int argb) async {
    final v = argb | 0xFF000000;
    final list = [...colors.value]..remove(v);
    list.insert(0, v);
    if (list.length > max) list.removeRange(max, list.length);
    colors.value = list;
    await _persist();
  }

  static Future<void> remove(int argb) async {
    final v = argb | 0xFF000000;
    if (!colors.value.contains(v)) return;
    colors.value = [...colors.value]..remove(v);
    await _persist();
  }

  /// Saves the colour, or removes it if it was already saved. Returns true when
  /// the colour ends up saved, so the caller can word its confirmation.
  static Future<bool> toggle(int argb) async {
    final saved = has(argb);
    if (saved) {
      await remove(argb);
    } else {
      await add(argb);
    }
    return !saved;
  }
}
