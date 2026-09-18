// lib/controls.dart
//
// Hand-rolled settings controls.
//
// Why not SwitchListTile: it paints its background and ink splash on the
// nearest Material ancestor. Inside our decorated glass panel that produced
// the "ListTile background color or ink splashes may be invisible" assertion
// on every single build -- the wall of red in your log.
//
// Why the slider is stateful: Slider.onChanged fires every frame of a drag.
// v2 called SharedPreferences.setString() on each of those frames, so the
// disk write raced the rebuild and the thumb snapped back. Here the drag is
// local state, and persistence happens once, on release.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';

class SettingRow extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget trailing;
  final AppPalette palette;

  const SettingRow({
    super.key,
    required this.label,
    required this.trailing,
    required this.palette,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    hint!,
                    style: TextStyle(color: palette.textFaint, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Pill toggle. No Material ancestor required, no deprecated activeColor.
class PillToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppPalette palette;
  final bool haptics;

  /// When false, the knob sits right for OFF instead of right for ON.
  final bool rightIsOn;

  final double width;
  final double height;
  final Color? onColor;

  const PillToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.palette,
    this.haptics = true,
    this.rightIsOn = true,
    this.width = 56,
    this.height = 32,
    this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;
    // Whether the knob renders on the right is a display concern, decoupled
    // from what "on" means, so the convention can be flipped in settings.
    final knobOnRight = rightIsOn ? value : !value;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (haptics) HapticFeedback.selectionClick();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: value
              ? (onColor ?? palette.accent)
              : palette.trackInactive,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment:
              knobOnRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Container(
              width: knob,
              height: knob,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slider that previews live but only persists once, on release.
class SettingSlider extends StatefulWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final AppPalette palette;

  /// Live preview -- mutate + notify, do NOT write to disk here.
  final ValueChanged<double> onChanged;

  /// Called once when the finger lifts -- persist here.
  final ValueChanged<double> onCommit;

  final String Function(double)? format;

  const SettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.palette,
    required this.onChanged,
    required this.onCommit,
    this.divisions,
    this.format,
  });

  @override
  State<SettingSlider> createState() => _SettingSliderState();
}

class _SettingSliderState extends State<SettingSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final double shown = (_dragValue ?? widget.value)
        .clamp(widget.min, widget.max)
        .toDouble();
    final text = widget.format?.call(shown) ?? shown.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  color: widget.palette.textPrimary,
                  fontSize: 14,
                ),
              ),
              Text(
                text,
                style: TextStyle(
                  color: widget.palette.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 32,
            child: Slider(
              value: shown.toDouble(),
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              onChanged: (v) {
                setState(() => _dragValue = v);
                widget.onChanged(v);
              },
              onChangeEnd: (v) {
                setState(() => _dragValue = null);
                widget.onCommit(v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Text field that commits on submit / focus loss rather than per keystroke.
class SettingTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final AppPalette palette;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? hint;
  final ValueChanged<String>? onSubmitted;

  const SettingTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.palette,
    this.obscure = false,
    this.keyboardType,
    this.hint,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperStyle: TextStyle(color: palette.textFaint, fontSize: 11),
          labelStyle: TextStyle(color: palette.textSecondary, fontSize: 13),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.trackInactive),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: palette.accent, width: 1.6),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final AppPalette palette;
  final IconData icon;

  const SectionHeader({
    super.key,
    required this.title,
    required this.palette,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: palette.accent),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: palette.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class AccentButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AppPalette palette;
  final IconData? icon;
  final bool outlined;

  const AccentButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.palette,
    this.icon,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : palette.accent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: outlined ? palette.accent : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 17,
                    color: outlined ? palette.accent : Colors.black,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: outlined ? palette.accent : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
