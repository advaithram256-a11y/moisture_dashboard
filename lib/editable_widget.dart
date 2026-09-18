// lib/editable_widget.dart
//
// Drag/resize wrapper for dashboard widgets.
//
// The v2 bug, in full: position was recomputed each frame as
//     ((col * cellSize + delta.dx) / cellSize).round()
// where delta.dx is ONE FRAME's movement -- a few pixels. On a ~49px cell
// that always rounded straight back to the starting cell, so nothing ever
// moved unless a single frame happened to exceed half a cell. Resize had the
// same flaw.
//
// The fix: remember the layout at drag start, accumulate total pixel movement
// across the whole gesture, and convert that accumulated offset into cells.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';
import 'app_theme.dart';

class EditableWidgetBox extends StatefulWidget {
  final Widget child;
  final WidgetLayout layout;
  final bool editMode;
  final double cellSize;
  final int gridColumns;
  final int gridRows;
  final int minWidthCells;
  final int minHeightCells;
  final AppPalette palette;
  final bool haptics;
  final VoidCallback onGearTap;

  /// Fired continuously while dragging so the parent can show a live preview.
  final ValueChanged<WidgetLayout> onLayoutPreview;

  /// Fired once on release -- persist here.
  final ValueChanged<WidgetLayout> onLayoutCommit;

  const EditableWidgetBox({
    super.key,
    required this.child,
    required this.layout,
    required this.editMode,
    required this.cellSize,
    required this.gridColumns,
    required this.gridRows,
    required this.palette,
    required this.onGearTap,
    required this.onLayoutPreview,
    required this.onLayoutCommit,
    this.minWidthCells = 2,
    this.minHeightCells = 2,
    this.haptics = true,
  });

  @override
  State<EditableWidgetBox> createState() => _EditableWidgetBoxState();
}

class _EditableWidgetBoxState extends State<EditableWidgetBox> {
  /// Layout captured when the current gesture began.
  WidgetLayout? _base;

  /// Total pixels moved since the gesture began.
  Offset _accum = Offset.zero;

  int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

  void _startGesture() {
    _base = widget.layout;
    _accum = Offset.zero;
    if (widget.haptics) HapticFeedback.selectionClick();
  }

  void _endGesture() {
    _base = null;
    _accum = Offset.zero;
    widget.onLayoutCommit(widget.layout);
  }

  void _onMoveUpdate(DragUpdateDetails d) {
    final base = _base;
    if (base == null) return;
    _accum += d.delta;

    final dCol = (_accum.dx / widget.cellSize).round();
    final dRow = (_accum.dy / widget.cellSize).round();

    final next = base.copyWith(
      col: _clampInt(
        base.col + dCol,
        0,
        widget.gridColumns - base.widthCells,
      ),
      row: _clampInt(
        base.row + dRow,
        0,
        widget.gridRows - base.heightCells,
      ),
    );

    if (next.col != widget.layout.col || next.row != widget.layout.row) {
      if (widget.haptics) HapticFeedback.selectionClick();
      widget.onLayoutPreview(next);
    }
  }

  void _onResizeUpdate(DragUpdateDetails d) {
    final base = _base;
    if (base == null) return;
    _accum += d.delta;

    final dW = (_accum.dx / widget.cellSize).round();
    final dH = (_accum.dy / widget.cellSize).round();

    final next = base.copyWith(
      widthCells: _clampInt(
        base.widthCells + dW,
        widget.minWidthCells,
        widget.gridColumns - base.col,
      ),
      heightCells: _clampInt(
        base.heightCells + dH,
        widget.minHeightCells,
        widget.gridRows - base.row,
      ),
    );

    if (next.widthCells != widget.layout.widthCells ||
        next.heightCells != widget.layout.heightCells) {
      if (widget.haptics) HapticFeedback.selectionClick();
      widget.onLayoutPreview(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.layout;
    final cs = widget.cellSize;
    final accent = widget.palette.accent;

    return Positioned(
      left: l.col * cs,
      top: l.row * cs,
      width: l.widthCells * cs,
      height: l.heightCells * cs,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: widget.editMode
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => _startGesture(),
                    onPanUpdate: _onMoveUpdate,
                    onPanEnd: (_) => _endGesture(),
                    onPanCancel: _endGesture,
                    child: AbsorbPointer(
                      // Swallow taps aimed at the pump toggle etc. while
                      // arranging, so dragging never fires the pump.
                      child: widget.child,
                    ),
                  )
                : widget.child,
          ),

          if (widget.editMode) ...[
            // Selection outline.
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: accent, width: 1.8),
                  ),
                ),
              ),
            ),

            // Per-widget gear.
            Positioned(
              top: -12,
              left: -12,
              child: _HandleButton(
                icon: Icons.tune,
                background: accent,
                onTap: widget.onGearTap,
              ),
            ),

            // Resize grip.
            Positioned(
              bottom: -12,
              right: -12,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _startGesture(),
                onPanUpdate: _onResizeUpdate,
                onPanEnd: (_) => _endGesture(),
                onPanCancel: _endGesture,
                child: _HandleButton(
                  icon: Icons.open_in_full,
                  background: accent,
                  onTap: null,
                ),
              ),
            ),

            // Live size readout while arranging.
            Positioned(
              top: -10,
              right: -6,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${l.widthCells}x${l.heightCells}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HandleButton extends StatelessWidget {
  final IconData icon;
  final Color background;
  final VoidCallback? onTap;

  const _HandleButton({
    required this.icon,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 15, color: Colors.black),
    );

    if (onTap == null) return dot;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: dot,
    );
  }
}

/// Faint grid overlay shown behind widgets while arranging.
class EditGridOverlay extends StatelessWidget {
  final double cellSize;
  final int columns;
  final int rows;
  final Color color;

  const EditGridOverlay({
    super.key,
    required this.cellSize,
    required this.columns,
    required this.rows,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size(cellSize * columns, cellSize * rows),
        painter: _GridPainter(cellSize, columns, rows, color),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final double cellSize;
  final int columns;
  final int rows;
  final Color color;

  _GridPainter(this.cellSize, this.columns, this.rows, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    for (var c = 0; c <= columns; c++) {
      final x = c * cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, rows * cellSize), paint);
    }
    for (var r = 0; r <= rows; r++) {
      final y = r * cellSize;
      canvas.drawLine(Offset(0, y), Offset(columns * cellSize, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cellSize != cellSize ||
      old.columns != columns ||
      old.rows != rows ||
      old.color != color;
}
