// lib/dashboard_screen.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'adafruit_mqtt_service.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'dashboard_cards.dart';
import 'editable_widget.dart';
import 'settings_panel.dart';

class DashboardScreen extends StatefulWidget {
  final AppSettings settings;
  const DashboardScreen({super.key, required this.settings});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  AdafruitMqttService? _mqtt;

  double? _rawValue;
  DateTime? _lastUpdate;
  bool _pumpOn = false;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  bool _editMode = false;

  final _scroll = ScrollController();
  double _scrollOffset = 0;

  static const int kGridColumns = 8;
  static const int kGridRows = 18;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final o = _scroll.hasClients ? _scroll.offset : 0.0;
      // Only repaint when the change is visually meaningful. Rebuilding on
      // every pixel is wasted work on a weaker GPU.
      if ((o - _scrollOffset).abs() > 2) {
        setState(() => _scrollOffset = o);
      }
    });
    _connect();
  }

  void _connect() {
    _mqtt?.dispose();
    final svc = AdafruitMqttService(widget.settings);
    _mqtt = svc;

    svc.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    svc.rawMoistureStream.listen((raw) {
      if (mounted) {
        setState(() {
          _rawValue = raw;
          _lastUpdate = DateTime.now();
        });
      }
    });
    svc.pumpStateStream.listen((v) {
      if (mounted) {
        setState(() => _pumpOn = v.trim() == widget.settings.pumpOnValue);
      }
    });
    svc.errorStream.listen((msg) {
      if (!mounted || !widget.settings.showErrorToasts) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
      );
    });

    svc.connect();
  }

  @override
  void dispose() {
    _mqtt?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _handlePumpChange(bool wantOn) async {
    final s = widget.settings;

    if (wantOn && s.confirmPumpOn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Switch pump on?'),
          content: Text('This will publish "${s.pumpOnValue}" to '
              '${s.pumpFeedKey}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch on'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    if (s.hapticFeedback) HapticFeedback.mediumImpact();
    _mqtt?.publishPumpState(wantOn ? s.pumpOnValue : s.pumpOffValue);
    setState(() => _pumpOn = wantOn);
  }

  void _openSettings([SettingsSection section = SettingsSection.connection]) {
    showSettingsPanel(
      context,
      settings: widget.settings,
      onReconnect: _connect,
      currentRaw: _rawValue,
      initialSection: section,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final p = AppPalette.from(s);

    final media = MediaQuery.of(context);
    final width = media.size.width;
    final cell = width / kGridColumns;
    // Extra room at the bottom so the floating bar never covers a widget.
    final canvasHeight = cell * kGridRows + 120;

    return Scaffold(
      backgroundColor: p.scaffold,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _background(s, p),
          Column(
            children: [
              _topBar(s, p, media.padding.top),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  // Critical: while arranging, the scroll view must not
                  // compete with the drag handlers for vertical gestures.
                  // This was the "responds weird to touches" problem.
                  physics: _editMode
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  child: SizedBox(
                    height: canvasHeight,
                    width: width,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_editMode && s.showGridInEditMode)
                          Positioned.fill(
                            child: EditGridOverlay(
                              cellSize: cell,
                              columns: kGridColumns,
                              rows: kGridRows,
                              color: p.accent.withOpacity(0.16),
                            ),
                          ),
                        EditableWidgetBox(
                          layout: s.gaugeLayout,
                          editMode: _editMode,
                          cellSize: cell,
                          gridColumns: kGridColumns,
                          gridRows: kGridRows,
                          palette: p,
                          haptics: s.hapticFeedback,
                          minWidthCells: 3,
                          minHeightCells: 3,
                          onGearTap: () =>
                              _openSettings(SettingsSection.calibration),
                          onLayoutPreview: (l) =>
                              s.set(() => s.gaugeLayout = l),
                          onLayoutCommit: (l) =>
                              s.setAndCommit(() => s.gaugeLayout = l),
                          child: GaugeCard(
                            settings: s,
                            palette: p,
                            rawValue: _rawValue,
                            lastUpdate: _lastUpdate,
                          ),
                        ),
                        EditableWidgetBox(
                          layout: s.pumpLayout,
                          editMode: _editMode,
                          cellSize: cell,
                          gridColumns: kGridColumns,
                          gridRows: kGridRows,
                          palette: p,
                          haptics: s.hapticFeedback,
                          minWidthCells: 3,
                          minHeightCells: 1,
                          onGearTap: () => _openSettings(SettingsSection.pump),
                          onLayoutPreview: (l) =>
                              s.set(() => s.pumpLayout = l),
                          onLayoutCommit: (l) =>
                              s.setAndCommit(() => s.pumpLayout = l),
                          child: PumpCard(
                            settings: s,
                            palette: p,
                            pumpOn: _pumpOn,
                            enabled: !_editMode,
                            onChanged: _handlePumpChange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          _bottomBar(s, p, media.padding.bottom),
        ],
      ),
    );
  }

  Widget _background(AppSettings s, AppPalette p) {
    final hasImage =
        s.hasBackgroundImage && File(s.backgroundImagePath).existsSync();

    if (!hasImage) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: s.darkMode
                ? [const Color(0xFF1A1A1A), const Color(0xFF080808)]
                : [const Color(0xFFFAFAFA), const Color(0xFFE4E4E4)],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          File(s.backgroundImagePath),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: p.scaffold),
        ),
        Container(color: Colors.black.withOpacity(s.backgroundDim)),
      ],
    );
  }

  Widget _topBar(AppSettings s, AppPalette p, double topInset) {
    // Content sliding under the bar drives the blur, which is the
    // scroll-reactive effect you asked for.
    final t = (_scrollOffset / 90).clamp(0.0, 1.0);
    final sigma = 4 + 14 * t;

    final bar = Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 12, 20, 14),
      color: (s.darkMode ? Colors.black : Colors.white)
          .withOpacity(0.18 + 0.42 * t),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MOISTSENSE',
            style: TextStyle(
              color: p.accent,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          _statusChip(p),
        ],
      ),
    );

    if (!s.blurEnabled) return bar;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: bar,
      ),
    );
  }

  Widget _statusChip(AppPalette p) {
    late Color c;
    late String label;
    switch (_status) {
      case ConnectionStatus.connected:
        c = const Color(0xFF00E676);
        label = 'LIVE';
        break;
      case ConnectionStatus.connecting:
        c = const Color(0xFFFFB74D);
        label = 'CONNECTING';
        break;
      case ConnectionStatus.error:
        c = const Color(0xFFFF5252);
        label = 'ERROR';
        break;
      case ConnectionStatus.disconnected:
        c = p.textFaint;
        label = 'OFFLINE';
        break;
    }
    return GestureDetector(
      onTap: _status == ConnectionStatus.connected ? null : _connect,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(AppSettings s, AppPalette p, double bottomInset) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 14, left: 44, right: 44),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Container(
            decoration: BoxDecoration(
              color: (s.darkMode ? Colors.black : Colors.white)
                  .withOpacity(0.82),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: p.cardBorder),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _barButton(
                  icon: Icons.water_drop,
                  active: !_editMode,
                  palette: p,
                  onTap: () {
                    if (_editMode) setState(() => _editMode = false);
                  },
                ),
                _barButton(
                  icon: _editMode ? Icons.check_circle : Icons.dashboard_customize,
                  active: _editMode,
                  palette: p,
                  onTap: () {
                    if (s.hapticFeedback) HapticFeedback.mediumImpact();
                    setState(() => _editMode = !_editMode);
                  },
                ),
                _barButton(
                  icon: Icons.settings,
                  active: false,
                  palette: p,
                  onTap: _openSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _barButton({
    required IconData icon,
    required bool active,
    required AppPalette palette,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: active ? palette.accent.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          size: 22,
          color: active ? palette.accent : palette.textSecondary,
        ),
      ),
    );
  }
}
