// lib/settings_panel.dart
//
// The control panel. Wrapped in ListenableBuilder so every control reflects
// the live value -- the omission of exactly this is why v2's sliders snapped
// back and its toggles refused to move.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'controls.dart';

enum SettingsSection { connection, calibration, pump, appearance, dashboard }

Future<void> showSettingsPanel(
  BuildContext context, {
  required AppSettings settings,
  required VoidCallback onReconnect,
  required double? currentRaw,
  SettingsSection initialSection = SettingsSection.connection,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SettingsPanel(
      settings: settings,
      onReconnect: onReconnect,
      currentRaw: currentRaw,
      initialSection: initialSection,
    ),
  );
}

class SettingsPanel extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onReconnect;
  final double? currentRaw;
  final SettingsSection initialSection;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.onReconnect,
    required this.currentRaw,
    required this.initialSection,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final TextEditingController _username;
  late final TextEditingController _key;
  late final TextEditingController _moistureFeed;
  late final TextEditingController _pumpFeed;
  late final TextEditingController _dry;
  late final TextEditingController _wet;
  late final TextEditingController _title;
  late final TextEditingController _label;
  late final TextEditingController _unit;
  late final TextEditingController _pumpLabel;
  late final TextEditingController _onValue;
  late final TextEditingController _offValue;

  final _scrollController = ScrollController();
  final _calibrationKey = GlobalKey();
  final _pumpKey = GlobalKey();
  final _appearanceKey = GlobalKey();
  final _dashboardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _username = TextEditingController(text: s.aioUsername);
    _key = TextEditingController(text: s.aioKey);
    _moistureFeed = TextEditingController(text: s.moistureFeedKey);
    _pumpFeed = TextEditingController(text: s.pumpFeedKey);
    _dry = TextEditingController(text: s.sensorDryValue.toStringAsFixed(0));
    _wet = TextEditingController(text: s.sensorWetValue.toStringAsFixed(0));
    _title = TextEditingController(text: s.gaugeTitle);
    _label = TextEditingController(text: s.gaugeLabel);
    _unit = TextEditingController(text: s.gaugeUnit);
    _pumpLabel = TextEditingController(text: s.pumpLabel);
    _onValue = TextEditingController(text: s.pumpOnValue);
    _offValue = TextEditingController(text: s.pumpOffValue);

    if (widget.initialSection != SettingsSection.connection) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToSection());
    }
  }

  void _jumpToSection() {
    final key = switch (widget.initialSection) {
      SettingsSection.calibration => _calibrationKey,
      SettingsSection.pump => _pumpKey,
      SettingsSection.appearance => _appearanceKey,
      SettingsSection.dashboard => _dashboardKey,
      SettingsSection.connection => null,
    };
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.05,
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _username,
      _key,
      _moistureFeed,
      _pumpFeed,
      _dry,
      _wet,
      _title,
      _label,
      _unit,
      _pumpLabel,
      _onValue,
      _offValue,
    ]) {
      c.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  double _parse(String s, double fallback) => double.tryParse(s.trim()) ?? fallback;

  Future<void> _pickBackground() async {
    try {
      final picked =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          '${dir.path}/bg_${DateTime.now().millisecondsSinceEpoch}.img';
      await File(picked.path).copy(dest);

      final old = widget.settings.backgroundImagePath;
      await widget.settings.setAndCommit(() {
        widget.settings.backgroundImagePath = dest;
      });
      if (old.isNotEmpty && old != dest) {
        try {
          final f = File(old);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        final s = widget.settings;
        final p = AppPalette.from(s);

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: s.darkMode ? const Color(0xFF141414) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(26)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.trackInactive,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                  child: Row(
                    children: [
                      Text(
                        'Settings',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close, color: p.textSecondary),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    children: [
                      ..._connectionSection(s, p),
                      ..._calibrationSection(s, p),
                      ..._pumpSection(s, p),
                      ..._appearanceSection(s, p),
                      ..._dashboardSection(s, p),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ------------------------------------------------ Connection
  List<Widget> _connectionSection(AppSettings s, AppPalette p) => [
        SectionHeader(title: 'Connection', palette: p, icon: Icons.cloud),
        SettingTextField(
          label: 'Adafruit IO username',
          controller: _username,
          palette: p,
        ),
        SettingTextField(
          label: 'Adafruit IO key',
          controller: _key,
          palette: p,
          obscure: true,
          hint: 'From io.adafruit.com, "My Key"',
        ),
        SettingTextField(
          label: 'Moisture feed key',
          controller: _moistureFeed,
          palette: p,
          hint: 'The slug in the feed URL, not the block title',
        ),
        SettingTextField(
          label: 'Pump feed key',
          controller: _pumpFeed,
          palette: p,
        ),
        AccentButton(
          label: 'Save and reconnect',
          icon: Icons.sync,
          palette: p,
          onTap: () async {
            await s.setAndCommit(() {
              s.aioUsername = _username.text.trim();
              s.aioKey = _key.text.trim();
              s.moistureFeedKey = _moistureFeed.text.trim();
              s.pumpFeedKey = _pumpFeed.text.trim();
            });
            widget.onReconnect();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reconnecting...')),
              );
            }
          },
        ),
      ];

  // ------------------------------------------------ Calibration
  List<Widget> _calibrationSection(AppSettings s, AppPalette p) {
    final raw = widget.currentRaw;
    final livePercent = raw != null ? s.rawToPercent(raw) : null;

    return [
      SectionHeader(
        key: _calibrationKey,
        title: 'Calibration',
        palette: p,
        icon: Icons.tune,
      ),

      // Live readout, so you can calibrate against reality in-app.
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.trackInactive.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _readout('live raw', raw?.toStringAsFixed(0) ?? '--', p),
            _readout(
              'shows as',
              livePercent != null ? s.formatPercent(livePercent) : '--',
              p,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Put the probe in the condition you want to define, wait for the '
        'live raw number to settle, then capture it.',
        style: TextStyle(color: p.textFaint, fontSize: 11, height: 1.4),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: AccentButton(
              label: 'Capture as 0%',
              icon: Icons.wb_sunny_outlined,
              palette: p,
              outlined: true,
              onTap: raw == null
                  ? () {}
                  : () async {
                      await s.setAndCommit(() => s.sensorDryValue = raw);
                      _dry.text = raw.toStringAsFixed(0);
                    },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AccentButton(
              label: 'Capture as 100%',
              icon: Icons.water_drop_outlined,
              palette: p,
              outlined: true,
              onTap: raw == null
                  ? () {}
                  : () async {
                      await s.setAndCommit(() => s.sensorWetValue = raw);
                      _wet.text = raw.toStringAsFixed(0);
                    },
            ),
          ),
        ],
      ),
      SettingTextField(
        label: 'Raw value for 0% (dry)',
        controller: _dry,
        palette: p,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (v) =>
            s.setAndCommit(() => s.sensorDryValue = _parse(v, s.sensorDryValue)),
      ),
      SettingTextField(
        label: 'Raw value for 100% (wet)',
        controller: _wet,
        palette: p,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onSubmitted: (v) =>
            s.setAndCommit(() => s.sensorWetValue = _parse(v, s.sensorWetValue)),
      ),
      SettingTextField(
        label: 'Gauge label', controller: _label, palette: p),
      SettingTextField(
        label: 'Gauge subtitle', controller: _title, palette: p),
      SettingTextField(label: 'Unit symbol', controller: _unit, palette: p),
      AccentButton(
        label: 'Apply calibration',
        icon: Icons.check,
        palette: p,
        onTap: () => s.setAndCommit(() {
          s.sensorDryValue = _parse(_dry.text, s.sensorDryValue);
          s.sensorWetValue = _parse(_wet.text, s.sensorWetValue);
          s.gaugeLabel = _label.text;
          s.gaugeTitle = _title.text;
          s.gaugeUnit = _unit.text;
        }),
      ),
      SettingSlider(
        label: 'Low warning below',
        value: s.lowWarningPercent,
        min: 0,
        max: 100,
        divisions: 20,
        palette: p,
        format: (v) => '${v.toStringAsFixed(0)}%',
        onChanged: (v) => s.set(() => s.lowWarningPercent = v),
        onCommit: (v) => s.setAndCommit(() => s.lowWarningPercent = v),
      ),
      SettingSlider(
        label: 'Healthy above',
        value: s.goodThresholdPercent,
        min: 0,
        max: 100,
        divisions: 20,
        palette: p,
        format: (v) => '${v.toStringAsFixed(0)}%',
        onChanged: (v) => s.set(() => s.goodThresholdPercent = v),
        onCommit: (v) => s.setAndCommit(() => s.goodThresholdPercent = v),
      ),
      SettingSlider(
        label: 'Decimal places',
        value: s.decimalPlaces.toDouble(),
        min: 0,
        max: 2,
        divisions: 2,
        palette: p,
        onChanged: (v) => s.set(() => s.decimalPlaces = v.round()),
        onCommit: (v) => s.setAndCommit(() => s.decimalPlaces = v.round()),
      ),
      SettingRow(
        label: 'Show raw value on gauge',
        hint: 'Needed for calibrating',
        palette: p,
        trailing: PillToggle(
          value: s.showRawValue,
          palette: p,
          haptics: s.hapticFeedback,
          onChanged: (v) => s.setAndCommit(() => s.showRawValue = v),
        ),
      ),
    ];
  }

  Widget _readout(String label, String value, AppPalette p) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: p.textFaint, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: p.accent,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------ Pump
  List<Widget> _pumpSection(AppSettings s, AppPalette p) => [
        SectionHeader(
          key: _pumpKey,
          title: 'Pump',
          palette: p,
          icon: Icons.water,
        ),
        SettingTextField(
          label: 'Pump label', controller: _pumpLabel, palette: p),
        SettingTextField(
          label: 'Value sent for ON',
          controller: _onValue,
          palette: p,
        ),
        SettingTextField(
          label: 'Value sent for OFF',
          controller: _offValue,
          palette: p,
        ),
        AccentButton(
          label: 'Save pump settings',
          icon: Icons.check,
          palette: p,
          onTap: () => s.setAndCommit(() {
            s.pumpLabel = _pumpLabel.text;
            s.pumpOnValue = _onValue.text.trim();
            s.pumpOffValue = _offValue.text.trim();
          }),
        ),
        SettingRow(
          label: 'Knob on the right means ON',
          palette: p,
          trailing: PillToggle(
            value: s.toggleRightIsOn,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.toggleRightIsOn = v),
          ),
        ),
        SettingRow(
          label: 'Confirm before switching on',
          hint: 'Guards against accidental taps',
          palette: p,
          trailing: PillToggle(
            value: s.confirmPumpOn,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.confirmPumpOn = v),
          ),
        ),
      ];

  // ------------------------------------------------ Appearance
  List<Widget> _appearanceSection(AppSettings s, AppPalette p) => [
        SectionHeader(
          key: _appearanceKey,
          title: 'Appearance',
          palette: p,
          icon: Icons.palette_outlined,
        ),
        SettingRow(
          label: 'Dark mode',
          palette: p,
          trailing: PillToggle(
            value: s.darkMode,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.darkMode = v),
          ),
        ),
        const SizedBox(height: 6),
        Text('Accent colour',
            style: TextStyle(color: p.textPrimary, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: List.generate(kAccentPalette.length, (i) {
            final selected = s.accentIndex == i;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => s.setAndCommit(() => s.accentIndex = i),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kAccentPalette[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? p.textPrimary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          size: 17, color: Colors.black)
                      : null,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        AccentButton(
          label: s.hasBackgroundImage
              ? 'Change background image'
              : 'Choose background image',
          icon: Icons.image_outlined,
          palette: p,
          outlined: true,
          onTap: _pickBackground,
        ),
        if (s.hasBackgroundImage)
          AccentButton(
            label: 'Remove background image',
            icon: Icons.delete_outline,
            palette: p,
            outlined: true,
            onTap: () => s.setAndCommit(() => s.backgroundImagePath = ''),
          ),
        SettingRow(
          label: 'Frosted blur',
          hint: s.hasBackgroundImage
              ? 'Costs performance on older phones'
              : 'Only visible with a background image',
          palette: p,
          trailing: PillToggle(
            value: s.blurEnabled,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.blurEnabled = v),
          ),
        ),
        if (s.blurEnabled)
          SettingSlider(
            label: 'Blur strength',
            value: s.blurIntensity,
            min: 0,
            max: 40,
            palette: p,
            onChanged: (v) => s.set(() => s.blurIntensity = v),
            onCommit: (v) => s.setAndCommit(() => s.blurIntensity = v),
          ),
        SettingSlider(
          label: 'Card opacity',
          value: s.cardOpacity,
          min: 0.1,
          max: 1.0,
          palette: p,
          format: (v) => '${(v * 100).toStringAsFixed(0)}%',
          onChanged: (v) => s.set(() => s.cardOpacity = v),
          onCommit: (v) => s.setAndCommit(() => s.cardOpacity = v),
        ),
        if (s.hasBackgroundImage)
          SettingSlider(
            label: 'Background dim',
            value: s.backgroundDim,
            min: 0,
            max: 0.85,
            palette: p,
            format: (v) => '${(v * 100).toStringAsFixed(0)}%',
            onChanged: (v) => s.set(() => s.backgroundDim = v),
            onCommit: (v) => s.setAndCommit(() => s.backgroundDim = v),
          ),
      ];

  // ------------------------------------------------ Dashboard
  List<Widget> _dashboardSection(AppSettings s, AppPalette p) => [
        SectionHeader(
          key: _dashboardKey,
          title: 'Dashboard',
          palette: p,
          icon: Icons.dashboard_outlined,
        ),
        SettingRow(
          label: 'Show grid while arranging',
          palette: p,
          trailing: PillToggle(
            value: s.showGridInEditMode,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.showGridInEditMode = v),
          ),
        ),
        SettingRow(
          label: 'Haptic feedback',
          palette: p,
          trailing: PillToggle(
            value: s.hapticFeedback,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.hapticFeedback = v),
          ),
        ),
        SettingRow(
          label: 'Show error messages',
          hint: 'Connection and publish failures',
          palette: p,
          trailing: PillToggle(
            value: s.showErrorToasts,
            palette: p,
            haptics: s.hapticFeedback,
            onChanged: (v) => s.setAndCommit(() => s.showErrorToasts = v),
          ),
        ),
        const SizedBox(height: 8),
        AccentButton(
          label: 'Reset widget layout',
          icon: Icons.grid_view,
          palette: p,
          outlined: true,
          onTap: () async {
            await s.resetLayout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Layout reset')),
              );
            }
          },
        ),
      ];
}
