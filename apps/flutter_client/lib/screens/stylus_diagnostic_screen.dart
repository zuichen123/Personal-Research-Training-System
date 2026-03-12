import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Temporary diagnostic screen to visualize raw pointer events from all
/// input devices (mouse, touch, stylus, inverted stylus).
///
/// Add a route to this screen temporarily to diagnose stylus issues.
class StylusDiagnosticScreen extends StatefulWidget {
  const StylusDiagnosticScreen({super.key});

  @override
  State<StylusDiagnosticScreen> createState() =>
      _StylusDiagnosticScreenState();
}

class _StylusDiagnosticScreenState extends State<StylusDiagnosticScreen> {
  final List<_PointerEventLog> _logs = <_PointerEventLog>[];
  Offset? _lastPosition;
  PointerDeviceKind? _lastKind;
  double _lastPressure = 0;
  int _lastButtons = 0;
  final List<Offset> _drawPoints = <Offset>[];

  void _logEvent(String type, PointerEvent event) {
    setState(() {
      _lastPosition = event.localPosition;
      _lastKind = event.kind;
      _lastPressure = event.pressure;
      _lastButtons = event.buttons;

      _logs.insert(
        0,
        _PointerEventLog(
          type: type,
          kind: event.kind,
          pointer: event.pointer,
          position: event.localPosition,
          pressure: event.pressure,
          buttons: event.buttons,
          down: event.down,
          timestamp: DateTime.now(),
        ),
      );
      if (_logs.length > 100) {
        _logs.removeRange(100, _logs.length);
      }

      // Draw trail
      if (type == 'DOWN' || type == 'MOVE') {
        _drawPoints.add(event.localPosition);
        if (_drawPoints.length > 2000) {
          _drawPoints.removeRange(0, 500);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('手写笔诊断工具 (Stylus Diagnostic)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
            onPressed: () => setState(() {
              _logs.clear();
              _drawPoints.clear();
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: '设备类型',
                  value: _lastKind?.name ?? '等待输入...',
                  highlight: _lastKind == PointerDeviceKind.stylus ||
                      _lastKind == PointerDeviceKind.invertedStylus,
                ),
                _StatusChip(
                  label: '位置',
                  value: _lastPosition != null
                      ? '(${_lastPosition!.dx.toStringAsFixed(0)}, ${_lastPosition!.dy.toStringAsFixed(0)})'
                      : '-',
                ),
                _StatusChip(
                  label: '压感',
                  value: _lastPressure.toStringAsFixed(3),
                  highlight: _lastPressure > 0 && _lastPressure < 1,
                ),
                _StatusChip(
                  label: 'Buttons',
                  value: '0x${_lastButtons.toRadixString(16)}',
                ),
                _StatusChip(
                  label: '事件数',
                  value: '${_logs.length}',
                ),
              ],
            ),
          ),
          // Drawing area + event log
          Expanded(
            child: Row(
              children: [
                // Left: drawing canvas
                Expanded(
                  flex: 3,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) => _logEvent('DOWN', e),
                    onPointerMove: (e) => _logEvent('MOVE', e),
                    onPointerUp: (e) => _logEvent('UP', e),
                    onPointerCancel: (e) => _logEvent('CANCEL', e),
                    onPointerHover: (e) => _logEvent('HOVER', e),
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Text(
                              '在此区域用手写笔 / 手指 / 鼠标进行操作\n'
                              '观察右侧日志显示的设备类型',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          CustomPaint(
                            size: Size.infinite,
                            painter: _TrailPainter(_drawPoints),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Right: event log
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '事件日志 (最新在前)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _logs.length,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            itemBuilder: (context, index) {
                              final log = _logs[index];
                              final isStylus =
                                  log.kind == PointerDeviceKind.stylus ||
                                      log.kind ==
                                          PointerDeviceKind.invertedStylus;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                  horizontal: 6,
                                ),
                                margin: const EdgeInsets.only(bottom: 2),
                                decoration: BoxDecoration(
                                  color: isStylus
                                      ? Colors.green.withAlpha(30)
                                      : null,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${log.type.padRight(6)} '
                                  '${log.kind.name.padRight(14)} '
                                  'p=${log.pressure.toStringAsFixed(2)} '
                                  'btn=0x${log.buttons.toRadixString(16)} '
                                  'ptr=${log.pointer}',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: isStylus
                                        ? Colors.green.shade800
                                        : null,
                                    fontWeight:
                                        log.type == 'DOWN' || log.type == 'UP'
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom: tap test buttons
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _showSnack('ElevatedButton 点击成功!'),
                  child: const Text('测试按钮点击'),
                ),
                OutlinedButton(
                  onPressed: () => _showSnack('OutlinedButton 点击成功!'),
                  child: const Text('测试按钮点击 2'),
                ),
                IconButton(
                  onPressed: () => _showSnack('IconButton 点击成功!'),
                  icon: const Icon(Icons.touch_app),
                  tooltip: '测试图标按钮',
                ),
                Checkbox(
                  value: false,
                  onChanged: (_) => _showSnack('Checkbox 点击成功!'),
                ),
                Switch(
                  value: false,
                  onChanged: (_) => _showSnack('Switch 点击成功!'),
                ),
                const Text('← 用手写笔点击这些控件，测试是否有反应'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 1)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: highlight ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: highlight
                ? Border.all(color: Colors.green.shade400)
                : null,
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? Colors.green.shade900 : null,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _TrailPainter extends CustomPainter {
  _TrailPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  @override
  bool shouldRepaint(_TrailPainter oldDelegate) => true;
}

class _PointerEventLog {
  _PointerEventLog({
    required this.type,
    required this.kind,
    required this.pointer,
    required this.position,
    required this.pressure,
    required this.buttons,
    required this.down,
    required this.timestamp,
  });

  final String type;
  final PointerDeviceKind kind;
  final int pointer;
  final Offset position;
  final double pressure;
  final int buttons;
  final bool down;
  final DateTime timestamp;
}
