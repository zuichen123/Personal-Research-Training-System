import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

import '../utils/signature_canvas_utils.dart';
import 'ai_multimodal_message_input.dart' show AIChatAttachmentPayload;

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
  final int maxAttachments;
  final Object? resetKey;

  @override
  State<PracticeMultimodalAnswerInput> createState() =>
      _PracticeMultimodalAnswerInputState();
}

class _PracticeMultimodalAnswerInputState
    extends State<PracticeMultimodalAnswerInput> {
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
        ? '已展开：图片 / 拍照 / 语音 / 手写'
        : '已展开：图片 / 语音 / 手写';

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
          ...widget.extraToolActions,
        ],
      ),
    );
  }

  Widget _buildHandwritingPanel(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
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
              IconButton(
                tooltip: '画笔',
                onPressed: widget.enabled ? () => _setEraserMode(false) : null,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: _eraserMode
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
              IconButton(
                tooltip: '橡皮',
                onPressed: widget.enabled ? () => _setEraserMode(true) : null,
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.auto_fix_normal,
                  size: 18,
                  color: _eraserMode
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
              TextButton(
                onPressed: widget.enabled ? _clearSignature : null,
                child: const Text('清空'),
              ),
              FilledButton.tonalIcon(
                onPressed: widget.enabled ? _captureSignatureAttachment : null,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text('加入附件'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 160,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: _handleSignaturePointerDown,
                onPointerMove: _handleSignaturePointerMove,
                onPointerUp: _handleSignaturePointerEnd,
                onPointerCancel: _handleSignaturePointerEnd,
                child: Signature(
                  controller: _signatureController,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点击“加入附件”后，手写内容会转换为图片并作为附件提交。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
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
    if (_signatureController.isEmpty) {
      _showSnack('请先在手写区书写内容');
      return;
    }
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
      _showSnack('手写内容转换失败');
      return;
    }
    _appendAttachment(
      AIChatAttachmentPayload(
        name: 'handwriting_${DateTime.now().millisecondsSinceEpoch}.png',
        source: 'handwriting',
        mimeType: 'image/png',
        dataUrl: _toDataUrl('image/png', bytes),
      ),
    );
    _signatureController.clear();
  }

  void _appendAttachment(AIChatAttachmentPayload attachment) {
    if (widget.attachments.length >= widget.maxAttachments) {
      _showSnack('最多添加 ${widget.maxAttachments} 个附件');
      return;
    }
    widget.onAttachmentsChanged([...widget.attachments, attachment]);
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
