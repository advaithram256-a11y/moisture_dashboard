// lib/dashboard_cards.dart
//
// The two dashboard widgets. Both use LayoutBuilder and hide optional
// elements when short, because the user can resize them to any dimensions
// in edit mode and a fixed Column would simply overflow (yellow stripes).

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'controls.dart';
import 'glass_card.dart';

class GaugeCard extends StatelessWidget {
  final AppSettings settings;
  final AppPalette palette;

  /// Raw sensor reading, or null if nothing has arrived yet.
  final double? rawValue;
  final DateTime? lastUpdate;

  const GaugeCard({
    super.key,
    required this.settings,
    required this.palette,
    required this.rawValue,
    required this.lastUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = rawValue != null;
    // Computed at paint time, so calibration edits show up instantly.
    final percent = hasData ? settings.rawToPercent(rawValue!) : 0.0;
    final color = palette.forMoisture(percent, settings);

    return GlassCard(
      settings: settings,
      palette: palette,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final compact = box.maxHeight < 190;
          final tiny = box.maxHeight < 120;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!tiny)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        settings.gaugeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (!compact && settings.gaugeTitle.isNotEmpty)
                      Flexible(
                        child: Text(
                          settings.gaugeTitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.textFaint,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              Expanded(
                child: SfRadialGauge(
                  axes: [
                    RadialAxis(
                      minimum: 0,
                      maximum: 100,
                      startAngle: 150,
                      endAngle: 30,
                      showTicks: false,
                      showLabels: false,
                      radiusFactor: 0.95,
                      axisLineStyle: AxisLineStyle(
                        thickness: 0.14,
                        thicknessUnit: GaugeSizeUnit.factor,
                        color: palette.trackInactive,
                        cornerStyle: CornerStyle.bothCurve,
                      ),
                      pointers: [
                        RangePointer(
                          value: hasData ? percent : 0,
                          width: 0.14,
                          sizeUnit: GaugeSizeUnit.factor,
                          color: color,
                          cornerStyle: CornerStyle.bothCurve,
                          enableAnimation: true,
                          animationDuration: 500,
                        ),
                      ],
                      annotations: [
                        GaugeAnnotation(
                          positionFactor: 0.05,
                          angle: 90,
                          widget: _GaugeCenter(
                            settings: settings,
                            palette: palette,
                            percent: percent,
                            rawValue: rawValue,
                            hasData: hasData,
                            compact: compact,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GaugeCenter extends StatelessWidget {
  final AppSettings settings;
  final AppPalette palette;
  final double percent;
  final double? rawValue;
  final bool hasData;
  final bool compact;

  const _GaugeCenter({
    required this.settings,
    required this.palette,
    required this.percent,
    required this.rawValue,
    required this.hasData,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!compact)
          Icon(
            Icons.water_drop,
            size: 20,
            color: palette.textSecondary,
          ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            hasData ? settings.formatPercent(percent) : '--',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: compact ? 28 : 40,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
        ),
        // The raw number is what you actually need in order to calibrate.
        if (settings.showRawValue && hasData)
          Text(
            'raw ${rawValue!.toStringAsFixed(0)}',
            style: TextStyle(
              color: palette.textFaint,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
      ],
    );
  }
}

class PumpCard extends StatelessWidget {
  final AppSettings settings;
  final AppPalette palette;
  final bool pumpOn;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const PumpCard({
    super.key,
    required this.settings,
    required this.palette,
    required this.pumpOn,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      settings: settings,
      palette: palette,
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: LayoutBuilder(
        builder: (context, box) {
          final narrow = box.maxWidth < 200;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.pumpLabel.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    if (!narrow)
                      Text(
                        pumpOn ? 'running' : 'idle',
                        style: TextStyle(
                          color: pumpOn ? palette.accent : palette.textFaint,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PillToggle(
                value: pumpOn,
                palette: palette,
                haptics: settings.hapticFeedback,
                rightIsOn: settings.toggleRightIsOn,
                width: 64,
                height: 34,
                onChanged: enabled ? onChanged : (_) {},
              ),
            ],
          );
        },
      ),
    );
  }
}
