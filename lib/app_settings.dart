// lib/app_settings.dart
//
// Single source of truth for everything configurable. Extends ChangeNotifier
// so the UI can rebuild on change -- see main.dart, which wraps the whole app
// in a ListenableBuilder. (v2's bug: it notified, but nobody listened.)
//
// Two separate operations on purpose:
//   set(...)      -> mutate + notify, NO disk write. Use during slider drags.
//   commit()      -> write to disk. Use on drag end / button press.
//   setAndCommit  -> both, for discrete changes like a toggle.
// Writing to SharedPreferences on every slider frame is what made v2 janky.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fixed accent palette. We store an INDEX, not a Color, so persistence
/// never depends on Color.value (deprecated) or on serialising ARGB ints.
const List<Color> kAccentPalette = [
  Color(0xFF00E676), // green
  Color(0xFFFF7043), // deep orange
  Color(0xFF40C4FF), // light blue
  Color(0xFFB388FF), // purple
  Color(0xFFFFD54F), // amber
  Color(0xFFFF4081), // pink
];

/// Grid position + size, in grid cells (not pixels) so layout scales
/// across screen sizes and orientations.
class WidgetLayout {
  final int col;
  final int row;
  final int widthCells;
  final int heightCells;

  const WidgetLayout({
    required this.col,
    required this.row,
    required this.widthCells,
    required this.heightCells,
  });

  WidgetLayout copyWith({
    int? col,
    int? row,
    int? widthCells,
    int? heightCells,
  }) {
    return WidgetLayout(
      col: col ?? this.col,
      row: row ?? this.row,
      widthCells: widthCells ?? this.widthCells,
      heightCells: heightCells ?? this.heightCells,
    );
  }

  Map<String, dynamic> toJson() => {
        'col': col,
        'row': row,
        'w': widthCells,
        'h': heightCells,
      };

  static WidgetLayout fromJson(Map<String, dynamic> j, WidgetLayout fallback) {
    return WidgetLayout(
      col: (j['col'] as num?)?.toInt() ?? fallback.col,
      row: (j['row'] as num?)?.toInt() ?? fallback.row,
      widthCells: (j['w'] as num?)?.toInt() ?? fallback.widthCells,
      heightCells: (j['h'] as num?)?.toInt() ?? fallback.heightCells,
    );
  }
}

class AppSettings extends ChangeNotifier {
  // ---------------- Connection ----------------
  String aioUsername = '';
  String aioKey = '';
  String moistureFeedKey = 'moisture';
  String pumpFeedKey = 'pump-state';

  // ---------------- Calibration ----------------
  /// Raw ADC reading that should display as 0%.
  double sensorDryValue = 4095;

  /// Raw ADC reading that should display as 100%.
  double sensorWetValue = 1300;

  String gaugeTitle = 'lower is better';
  String gaugeLabel = 'moisture';
  String gaugeUnit = '%';
  int decimalPlaces = 0;
  double lowWarningPercent = 25;
  double goodThresholdPercent = 55;

  /// Show the raw sensor number under the percentage. Makes calibrating
  /// possible without opening the Adafruit site in a browser.
  bool showRawValue = true;

  // ---------------- Pump / toggle ----------------
  String pumpLabel = 'pump state';
  String pumpOnValue = '1';
  String pumpOffValue = '0';

  /// true  -> knob sits on the RIGHT when the pump is ON (your request)
  /// false -> knob sits on the LEFT when ON (old behaviour)
  bool toggleRightIsOn = true;

  /// Ask before switching the pump on, to avoid pocket-taps flooding a plant.
  bool confirmPumpOn = false;

  // ---------------- Appearance ----------------
  int accentIndex = 0;
  bool darkMode = true;

  /// Master switch for BackdropFilter. Real blur is genuinely expensive on
  /// older GPUs; off, cards use a plain translucent fill that looks close
  /// but costs virtually nothing.
  bool blurEnabled = true;
  double blurIntensity = 18;

  /// Opacity of the card fill over the background.
  double cardOpacity = 0.55;

  /// Darkening veil over the background image so white text stays readable.
  double backgroundDim = 0.35;

  String backgroundImagePath = '';

  // ---------------- Dashboard behaviour ----------------
  /// Surface connection/publish errors as snackbars.
  bool showErrorToasts = true;
  bool showGridInEditMode = true;
  bool hapticFeedback = true;

  // ---------------- Layout ----------------
  static const WidgetLayout defaultGaugeLayout =
      WidgetLayout(col: 0, row: 0, widthCells: 8, heightCells: 7);
  static const WidgetLayout defaultPumpLayout =
      WidgetLayout(col: 0, row: 7, widthCells: 8, heightCells: 2);

  WidgetLayout gaugeLayout = defaultGaugeLayout;
  WidgetLayout pumpLayout = defaultPumpLayout;

  // ---------------- Derived ----------------
  Color get accentColor =>
      kAccentPalette[accentIndex.clamp(0, kAccentPalette.length - 1)];

  bool get hasBackgroundImage => backgroundImagePath.isNotEmpty;

  /// Maps a raw sensor reading onto 0..100 using the calibration endpoints.
  /// Works whether dry > wet (typical capacitive probe) or the reverse --
  /// no separate "invert" flag needed, the endpoints carry that information.
  double rawToPercent(double raw) {
    final span = sensorWetValue - sensorDryValue;
    if (span == 0) return 0;
    final pct = (raw - sensorDryValue) / span * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  String formatPercent(double pct) =>
      '${pct.toStringAsFixed(decimalPlaces)}$gaugeUnit';

  // ---------------- Mutation ----------------

  /// Mutate + notify, WITHOUT touching the disk. For live drags.
  void set(void Function() mutator) {
    mutator();
    notifyListeners();
  }

  /// Mutate + notify + persist. For discrete changes.
  Future<void> setAndCommit(void Function() mutator) async {
    mutator();
    notifyListeners();
    await commit();
  }

  // ---------------- Persistence ----------------
  static const _key = 'moistsense_settings_v3';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      notifyListeners();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;

      aioUsername = j['aioUsername'] as String? ?? aioUsername;
      aioKey = j['aioKey'] as String? ?? aioKey;
      moistureFeedKey = j['moistureFeedKey'] as String? ?? moistureFeedKey;
      pumpFeedKey = j['pumpFeedKey'] as String? ?? pumpFeedKey;

      sensorDryValue =
          (j['sensorDryValue'] as num?)?.toDouble() ?? sensorDryValue;
      sensorWetValue =
          (j['sensorWetValue'] as num?)?.toDouble() ?? sensorWetValue;
      gaugeTitle = j['gaugeTitle'] as String? ?? gaugeTitle;
      gaugeLabel = j['gaugeLabel'] as String? ?? gaugeLabel;
      gaugeUnit = j['gaugeUnit'] as String? ?? gaugeUnit;
      decimalPlaces = (j['decimalPlaces'] as num?)?.toInt() ?? decimalPlaces;
      lowWarningPercent =
          (j['lowWarningPercent'] as num?)?.toDouble() ?? lowWarningPercent;
      goodThresholdPercent =
          (j['goodThresholdPercent'] as num?)?.toDouble() ??
              goodThresholdPercent;
      showRawValue = j['showRawValue'] as bool? ?? showRawValue;

      pumpLabel = j['pumpLabel'] as String? ?? pumpLabel;
      pumpOnValue = j['pumpOnValue'] as String? ?? pumpOnValue;
      pumpOffValue = j['pumpOffValue'] as String? ?? pumpOffValue;
      toggleRightIsOn = j['toggleRightIsOn'] as bool? ?? toggleRightIsOn;
      confirmPumpOn = j['confirmPumpOn'] as bool? ?? confirmPumpOn;

      accentIndex = (j['accentIndex'] as num?)?.toInt() ?? accentIndex;
      darkMode = j['darkMode'] as bool? ?? darkMode;
      blurEnabled = j['blurEnabled'] as bool? ?? blurEnabled;
      blurIntensity =
          (j['blurIntensity'] as num?)?.toDouble() ?? blurIntensity;
      cardOpacity = (j['cardOpacity'] as num?)?.toDouble() ?? cardOpacity;
      backgroundDim =
          (j['backgroundDim'] as num?)?.toDouble() ?? backgroundDim;
      backgroundImagePath =
          j['backgroundImagePath'] as String? ?? backgroundImagePath;

      showErrorToasts = j['showErrorToasts'] as bool? ?? showErrorToasts;
      showGridInEditMode =
          j['showGridInEditMode'] as bool? ?? showGridInEditMode;
      hapticFeedback = j['hapticFeedback'] as bool? ?? hapticFeedback;

      final gl = j['gaugeLayout'];
      if (gl is Map<String, dynamic>) {
        gaugeLayout = WidgetLayout.fromJson(gl, defaultGaugeLayout);
      }
      final pl = j['pumpLayout'];
      if (pl is Map<String, dynamic>) {
        pumpLayout = WidgetLayout.fromJson(pl, defaultPumpLayout);
      }
    } catch (_) {
      // Corrupt prefs must never brick the app; defaults already stand.
    }
    notifyListeners();
  }

  Future<void> commit() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'aioUsername': aioUsername,
        'aioKey': aioKey,
        'moistureFeedKey': moistureFeedKey,
        'pumpFeedKey': pumpFeedKey,
        'sensorDryValue': sensorDryValue,
        'sensorWetValue': sensorWetValue,
        'gaugeTitle': gaugeTitle,
        'gaugeLabel': gaugeLabel,
        'gaugeUnit': gaugeUnit,
        'decimalPlaces': decimalPlaces,
        'lowWarningPercent': lowWarningPercent,
        'goodThresholdPercent': goodThresholdPercent,
        'showRawValue': showRawValue,
        'pumpLabel': pumpLabel,
        'pumpOnValue': pumpOnValue,
        'pumpOffValue': pumpOffValue,
        'toggleRightIsOn': toggleRightIsOn,
        'confirmPumpOn': confirmPumpOn,
        'accentIndex': accentIndex,
        'darkMode': darkMode,
        'blurEnabled': blurEnabled,
        'blurIntensity': blurIntensity,
        'cardOpacity': cardOpacity,
        'backgroundDim': backgroundDim,
        'backgroundImagePath': backgroundImagePath,
        'showErrorToasts': showErrorToasts,
        'showGridInEditMode': showGridInEditMode,
        'hapticFeedback': hapticFeedback,
        'gaugeLayout': gaugeLayout.toJson(),
        'pumpLayout': pumpLayout.toJson(),
      }),
    );
  }

  Future<void> resetLayout() async {
    await setAndCommit(() {
      gaugeLayout = defaultGaugeLayout;
      pumpLayout = defaultPumpLayout;
    });
  }
}
