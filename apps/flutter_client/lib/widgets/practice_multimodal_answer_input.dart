import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../utils/signature_canvas_utils.dart';
import 'ai_multimodal_message_input.dart' show AIChatAttachmentPayload;

class PracticeAnswerHandwritingReference {
  const PracticeAnswerHandwritingReference({
    required this.key,
    required this.label,
    required this.content,
  });

  final String key;
  final String label;
  final String content;

  bool get hasContent => content.trim().isNotEmpty;
}

class PracticeMultimodalAnswerInput extends StatefulWidget {
  const PracticeMultimodalAnswerInput({
    super.key,
    required this.controller,
    required this.attachments,
    required this.onAttachmentsChanged,
    this.enabled = true,
    this.labelText = '你的答案',
    this.hintText,
    this.helperText,
    this.minLines = 3,
    this.maxLines = 6,
    this.onChanged,
    this.showCameraButton = true,
    this.extraToolActions = const <Widget>[],
    this.handwritingReferences = const <PracticeAnswerHandwritingReference>[],
    this.initialHandwritingReferenceKey,
    this.maxAttachments = 6,
    this.resetKey,
  });

  final TextEditingController controller;
  final List<AIChatAttachmentPayload> attachments;
  final ValueChanged<List<AIChatAttachmentPayload>> onAttachmentsChanged;
  final bool enabled;
  final String labelText;
  final String? hintText;
  final String? helperText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool showCameraButton;
  final List<Widget> extraToolActions;
  final List<PracticeAnswerHandwritingReference> handwritingReferences;
  final String? initialHandwritingReferenceKey;
  final int maxAttachments;
  final Object? resetKey;

  @override
  State<PracticeMultimodalAnswerInput> createState() =>
      _PracticeMultimodalAnswerInputState();
}

class _PracticeMultimodalAnswerInputState
    extends State<PracticeMultimodalAnswerInput> {
  static const double _handwritingCanvasWidth = 2400;
  static const double _handwritingCanvasHeight = 1600;

  final ImagePicker _imagePicker = ImagePicker();
  final SignatureController _signatureController = SignatureController(
    disabled: true,
    penColor: Colors.black,
    penStrokeWidth: 2.4,
    exportBackgroundColor: Colors.white,
  );

  bool _eraserMode = false;
  int? _signaturePointerId;
  bool _toolsExpanded = false;
  bool _showHandwritingPanel = false;

  @override
  void didUpdateWidget(covariant PracticeMultimodalAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetKey != widget.resetKey) {
      _signatureController.clear();
      _signaturePointerId = null;
      if (_eraserMode || _toolsExpanded || _showHandwritingPanel) {
        setState(() {
          _eraserMode = false;
          _toolsExpanded = false;
          _showHandwritingPanel = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expandedToolsText = widget.showCameraButton
        ? '已展开：图片 / 拍照 / 语音 / 手写 / 全屏'
        : '已展开：图片 / 语音 / 手写 / 全屏';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.attachments.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.attachments
                .asMap()
                .entries
                .map(
                  (entry) => InputChip(
                    label: Text(_attachmentLabel(entry.value)),
                    onDeleted: widget.enabled
                        ? () => _removeAttachment(entry.key)
                        : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: widget.enabled
                  ? () {
                      setState(() {
                        _toolsExpanded = !_toolsExpanded;
                        if (!_toolsExpanded) {
                          _showHandwritingPanel = false;
                        }
                      });
                    }
                  : null,
              icon: Icon(_toolsExpanded ? Icons.close : Icons.add),
              tooltip: _toolsExpanded ? '收起多模态工具' : '展开多模态工具',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _toolsExpanded ? expandedToolsText : '点击 + 展开多模态输入工具',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
        if (_toolsExpanded) ...[
          const SizedBox(height: 8),
          _buildAttachmentToolPanel(context),
          if (_showHandwritingPanel) ...[
            const SizedBox(height: 8),
            _buildHandwritingPanel(context),
          ],
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText,
            alignLabelWithHint: widget.maxLines > 1 || widget.minLines > 1,
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentToolPanel(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: widget.enabled
                ? () => _pickImageAttachment(ImageSource.gallery)
                : null,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('上传图片'),
          ),
          if (widget.showCameraButton)
            OutlinedButton.icon(
              onPressed: widget.enabled
                  ? () => _pickImageAttachment(ImageSource.camera)
                  : null,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('拍照'),
            ),
          OutlinedButton.icon(
            onPressed: widget.enabled ? _pickAudioAttachment : null,
            icon: const Icon(Icons.mic_external_on_outlined),
            label: const Text('上传语音'),
          ),
          FilledButton.tonalIcon(
            onPressed: widget.enabled
                ? () => setState(
                    () => _showHandwritingPanel = !_showHandwritingPanel,
                  )
                : null,
            icon: const Icon(Icons.draw_outlined),
            label: Text(_showHandwritingPanel ? '收起手写' : '展开手写'),
          ),
          OutlinedButton.icon(
            onPressed: widget.enabled ? _openHandwritingFullscreen : null,
            icon: const Icon(Icons.fullscreen),
            label: const Text('全屏画板'),
          ),
          ...widget.extraToolActions,
        ],
      ),
    );
  }

  Widget _buildHandwritingPanel(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    final viewportHeight = _handwritingViewportHeight(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '手写区',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.enabled ? _openHandwritingFullscreen : null,
                icon: const Icon(Icons.fullscreen, size: 18),
                label: const Text('全屏'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => _setEraserMode(false) : null,
                icon: Icon(
                  Icons.edit,
                  color: _eraserMode
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
                label: const Text('画笔'),
              ),
              OutlinedButton.icon(
                onPressed: widget.enabled ? () => _setEraserMode(true) : null,
                icon: Icon(
                  Icons.auto_fix_normal,
                  color: _eraserMode
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                label: const Text('橡皮'),
              ),
              OutlinedButton.icon(
                onPressed: widget.enabled ? _clearSignature : null,
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('清空'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.enabled ? _captureSignatureAttachment : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('加入附件'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: viewportHeight,
            width: double.infinity,
            child: _HandwritingBoardCanvas(
              controller: _signatureController,
              onPointerDown: _handleSignaturePointerDown,
              onPointerMove: _handleSignaturePointerMove,
              onPointerUp: _handleSignaturePointerEnd,
              onPointerCancel: _handleSignaturePointerEnd,
              canvasWidth: _handwritingCanvasWidth,
              canvasHeight: _handwritingCanvasHeight,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '支持大画布书写；移动端可直接进入全屏，并在全屏中切换题目或选项参考。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  double _handwritingViewportHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.26).clamp(220.0, 320.0).toDouble();
  }

  Future<void> _openHandwritingFullscreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => _PracticeHandwritingFullscreenPage(
          controller: _signatureController,
          references: widget.handwritingReferences,
          initialReferenceKey: widget.initialHandwritingReferenceKey,
          initialAttachmentsCount: widget.attachments.length,
          maxAttachments: widget.maxAttachments,
          onAppendAttachment: _appendAttachmentInternal,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickImageAttachment(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        _showSnack('图片读取失败');
        return;
      }
      final name = picked.name.trim().isEmpty
          ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final mimeType = _guessMimeType(name, fallback: 'image/jpeg');
      _appendAttachment(
        AIChatAttachmentPayload(
          name: name,
          source: source == ImageSource.camera ? 'camera' : 'gallery',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      _showSnack('上传图片失败');
    }
  }

  Future<void> _pickAudioAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'webm'],
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showSnack('语音文件读取失败');
        return;
      }
      final name = file.name.trim().isEmpty
          ? 'voice_${DateTime.now().millisecondsSinceEpoch}.wav'
          : file.name;
      final mimeType = _guessMimeType(name, fallback: 'audio/wav');
      _appendAttachment(
        AIChatAttachmentPayload(
          name: name,
          source: 'audio_upload',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      _showSnack('上传语音失败');
    }
  }

  Future<void> _captureSignatureAttachment() async {
    final attachment = await _buildHandwritingAttachmentFromController(
      _signatureController,
    );
    if (attachment == null) {
      _showSnack('请先在手写区书写内容');
      return;
    }
    _appendAttachment(attachment);
    _signatureController.clear();
  }

  void _appendAttachment(AIChatAttachmentPayload attachment) {
    if (!_appendAttachmentInternal(attachment)) {
      _showSnack('最多添加 ${widget.maxAttachments} 个附件');
    }
  }

  bool _appendAttachmentInternal(AIChatAttachmentPayload attachment) {
    if (widget.attachments.length >= widget.maxAttachments) {
      return false;
    }
    widget.onAttachmentsChanged([...widget.attachments, attachment]);
    return true;
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= widget.attachments.length) {
      return;
    }
    final next = [...widget.attachments]..removeAt(index);
    widget.onAttachmentsChanged(next);
  }

  void _setEraserMode(bool eraserMode) {
    if (_eraserMode == eraserMode) {
      return;
    }
    setState(() {
      _eraserMode = eraserMode;
    });
  }

  void _handleSignaturePointerDown(PointerDownEvent event) {
    if (!widget.enabled || !_isPrimaryButtonPressed(event.buttons)) {
      _signaturePointerId = null;
      return;
    }
    _signaturePointerId = event.pointer;
    if (_eraserMode) {
      SignatureCanvasUtils.eraseAt(_signatureController, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      _signatureController,
      event.localPosition,
      PointType.tap,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleSignaturePointerMove(PointerMoveEvent event) {
    if (_signaturePointerId != event.pointer ||
        !_isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    if (_eraserMode) {
      SignatureCanvasUtils.eraseAt(_signatureController, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      _signatureController,
      event.localPosition,
      PointType.move,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleSignaturePointerEnd(PointerEvent event) {
    if (_signaturePointerId == event.pointer) {
      _signaturePointerId = null;
    }
  }

  bool _isPrimaryButtonPressed(int buttons) => (buttons & kPrimaryButton) != 0;

  double _normalizedPressure(double pressure) => pressure > 0 ? pressure : 1.0;

  void _clearSignature() {
    _signatureController.clear();
  }

  String _attachmentLabel(AIChatAttachmentPayload attachment) {
    final mime = attachment.mimeType.toLowerCase();
    final prefix = mime.startsWith('audio/') ? '语音' : '图片';
    return '$prefix · ${attachment.name}';
  }

  String _toDataUrl(String mimeType, Uint8List bytes) {
    return 'data:$mimeType;base64,${base64Encode(bytes)}';
  }

  String _guessMimeType(String fileName, {required String fallback}) {
    final normalized = fileName.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.gif')) return 'image/gif';
    if (normalized.endsWith('.heic')) return 'image/heic';
    if (normalized.endsWith('.heif')) return 'image/heif';
    if (normalized.endsWith('.bmp')) return 'image/bmp';
    if (normalized.endsWith('.wav')) return 'audio/wav';
    if (normalized.endsWith('.mp3')) return 'audio/mpeg';
    if (normalized.endsWith('.m4a')) return 'audio/mp4';
    if (normalized.endsWith('.aac')) return 'audio/aac';
    if (normalized.endsWith('.ogg')) return 'audio/ogg';
    if (normalized.endsWith('.webm')) return 'audio/webm';
    return fallback;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _PracticeHandwritingFullscreenPage extends StatefulWidget {
  const _PracticeHandwritingFullscreenPage({
    required this.controller,
    required this.references,
    required this.initialReferenceKey,
    required this.initialAttachmentsCount,
    required this.maxAttachments,
    required this.onAppendAttachment,
  });

  final SignatureController controller;
  final List<PracticeAnswerHandwritingReference> references;
  final String? initialReferenceKey;
  final int initialAttachmentsCount;
  final int maxAttachments;
  final bool Function(AIChatAttachmentPayload attachment) onAppendAttachment;

  @override
  State<_PracticeHandwritingFullscreenPage> createState() =>
      _PracticeHandwritingFullscreenPageState();
}

class _PracticeHandwritingFullscreenPageState
    extends State<_PracticeHandwritingFullscreenPage> {
  static const String _noneReferenceKey = '__none__';

  bool _eraserMode = false;
  int? _signaturePointerId;
  late int _attachmentCount;
  late String _referenceKey;

  List<PracticeAnswerHandwritingReference> get _availableReferences => widget
      .references
      .where((item) => item.hasContent)
      .toList(growable: false);

  PracticeAnswerHandwritingReference? get _activeReference {
    if (_referenceKey == _noneReferenceKey) {
      return null;
    }
    for (final item in _availableReferences) {
      if (item.key == _referenceKey) {
        return item;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _attachmentCount = widget.initialAttachmentsCount;
    _referenceKey = _resolveReferenceKey(widget.initialReferenceKey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('全屏手写画板')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth < 720 ? 12.0 : 16.0;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12,
                horizontalPadding,
                12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolbar(context),
                  if (_availableReferences.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildReferenceSelector(),
                  ],
                  const SizedBox(height: 12),
                  Expanded(child: _buildResponsiveBoardLayout(constraints)),
                  const SizedBox(height: 8),
                  const Text(
                    '移动端可直接全屏书写；可按需切换题目或选项参考，并通过双指缩放、拖拽查看画布。',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _setEraserMode(false),
          icon: Icon(
            Icons.edit,
            color: _eraserMode
                ? Colors.grey
                : Theme.of(context).colorScheme.primary,
          ),
          label: const Text('画笔'),
        ),
        OutlinedButton.icon(
          onPressed: () => _setEraserMode(true),
          icon: Icon(
            Icons.auto_fix_normal,
            color: _eraserMode
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          label: const Text('橡皮'),
        ),
        OutlinedButton.icon(
          onPressed: _clearSignature,
          icon: const Icon(Icons.layers_clear_outlined),
          label: const Text('清空'),
        ),
        FilledButton.tonalIcon(
          onPressed: _appendAsAttachment,
          icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text('加入附件（$_attachmentCount/${widget.maxAttachments}）'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('完成'),
        ),
      ],
    );
  }

  Widget _buildReferenceSelector() {
    return DropdownButtonFormField<String>(
      value: _referenceKey,
      decoration: const InputDecoration(
        labelText: '参考内容',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: <DropdownMenuItem<String>>[
        const DropdownMenuItem<String>(
          value: _noneReferenceKey,
          child: Text('不显示参考'),
        ),
        ..._availableReferences.map(
          (item) => DropdownMenuItem<String>(
            value: item.key,
            child: Text(item.label),
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) {
          return;
        }
        setState(() => _referenceKey = value);
      },
    );
  }

  Widget _buildResponsiveBoardLayout(BoxConstraints constraints) {
    final reference = _activeReference;
    if (reference == null || !reference.hasContent) {
      return _buildBoardCanvas();
    }

    final narrow = constraints.maxWidth < 900;
    if (narrow) {
      final referenceHeight = (constraints.maxHeight * 0.28)
          .clamp(160.0, 260.0)
          .toDouble();
      return Column(
        children: [
          SizedBox(
            height: referenceHeight,
            child: _HandwritingReferencePanel(reference: reference),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBoardCanvas()),
        ],
      );
    }

    final referenceWidth = (constraints.maxWidth * 0.34)
        .clamp(260.0, 440.0)
        .toDouble();
    return Row(
      children: [
        SizedBox(
          width: referenceWidth,
          child: _HandwritingReferencePanel(reference: reference),
        ),
        const SizedBox(width: 12),
        Expanded(child: _buildBoardCanvas()),
      ],
    );
  }

  Widget _buildBoardCanvas() {
    return _HandwritingBoardCanvas(
      controller: widget.controller,
      onPointerDown: _handleSignaturePointerDown,
      onPointerMove: _handleSignaturePointerMove,
      onPointerUp: _handleSignaturePointerEnd,
      onPointerCancel: _handleSignaturePointerEnd,
      canvasWidth: _PracticeMultimodalAnswerInputState._handwritingCanvasWidth,
      canvasHeight:
          _PracticeMultimodalAnswerInputState._handwritingCanvasHeight,
    );
  }

  Future<void> _appendAsAttachment() async {
    if (_attachmentCount >= widget.maxAttachments) {
      _showSnack('最多添加 ${widget.maxAttachments} 个附件');
      return;
    }
    final attachment = await _buildHandwritingAttachmentFromController(
      widget.controller,
    );
    if (attachment == null) {
      _showSnack('请先在手写区书写内容');
      return;
    }
    if (!widget.onAppendAttachment(attachment)) {
      _showSnack('最多添加 ${widget.maxAttachments} 个附件');
      return;
    }
    setState(() {
      _attachmentCount += 1;
    });
    widget.controller.clear();
    _showSnack('手写内容已加入附件');
  }

  void _setEraserMode(bool eraserMode) {
    if (_eraserMode == eraserMode) {
      return;
    }
    setState(() {
      _eraserMode = eraserMode;
    });
  }

  void _handleSignaturePointerDown(PointerDownEvent event) {
    if (!_isPrimaryButtonPressed(event.buttons)) {
      _signaturePointerId = null;
      return;
    }
    _signaturePointerId = event.pointer;
    if (_eraserMode) {
      SignatureCanvasUtils.eraseAt(widget.controller, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      widget.controller,
      event.localPosition,
      PointType.tap,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleSignaturePointerMove(PointerMoveEvent event) {
    if (_signaturePointerId != event.pointer ||
        !_isPrimaryButtonPressed(event.buttons)) {
      return;
    }
    if (_eraserMode) {
      SignatureCanvasUtils.eraseAt(widget.controller, event.localPosition);
      return;
    }
    SignatureCanvasUtils.addPoint(
      widget.controller,
      event.localPosition,
      PointType.move,
      pressure: _normalizedPressure(event.pressure),
    );
  }

  void _handleSignaturePointerEnd(PointerEvent event) {
    if (_signaturePointerId == event.pointer) {
      _signaturePointerId = null;
    }
  }

  bool _isPrimaryButtonPressed(int buttons) => (buttons & kPrimaryButton) != 0;

  double _normalizedPressure(double pressure) => pressure > 0 ? pressure : 1.0;

  void _clearSignature() {
    widget.controller.clear();
  }

  String _resolveReferenceKey(String? candidate) {
    final references = _availableReferences;
    if (references.isEmpty) {
      return _noneReferenceKey;
    }
    if (candidate != null) {
      for (final item in references) {
        if (item.key == candidate) {
          return candidate;
        }
      }
    }
    return references.first.key;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _HandwritingBoardCanvas extends StatelessWidget {
  const _HandwritingBoardCanvas({
    required this.controller,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final SignatureController controller;
  final void Function(PointerDownEvent event) onPointerDown;
  final void Function(PointerMoveEvent event) onPointerMove;
  final void Function(PointerEvent event) onPointerUp;
  final void Function(PointerEvent event) onPointerCancel;
  final double canvasWidth;
  final double canvasHeight;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: InteractiveViewer(
          constrained: false,
          minScale: 0.5,
          maxScale: 6,
          child: SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: ColoredBox(
              color: Colors.white,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: onPointerDown,
                onPointerMove: onPointerMove,
                onPointerUp: onPointerUp,
                onPointerCancel: onPointerCancel,
                child: Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandwritingReferencePanel extends StatelessWidget {
  const _HandwritingReferencePanel({required this.reference});

  final PracticeAnswerHandwritingReference reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  reference.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  reference.content,
                  style: const TextStyle(fontSize: 12, height: 1.45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<AIChatAttachmentPayload?> _buildHandwritingAttachmentFromController(
  SignatureController controller,
) async {
  if (controller.isEmpty) {
    return null;
  }
  final bytes = await controller.toPngBytes();
  if (bytes == null || bytes.isEmpty) {
    return null;
  }
  return AIChatAttachmentPayload(
    name: 'handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
    source: 'handwriting',
    mimeType: 'image/png',
    dataUrl: 'data:image/png;base64,${base64Encode(bytes)}',
  );
}
