import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:signature/signature.dart';

class AIChatAttachmentPayload {
  AIChatAttachmentPayload({
    required this.name,
    required this.source,
    required this.mimeType,
    required this.dataUrl,
  });

  final String name;
  final String source;
  final String mimeType;
  final String dataUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'source': source,
    'mime_type': mimeType,
    'data_url': dataUrl,
  };
}

class AIMultimodalMessageInput extends StatefulWidget {
  const AIMultimodalMessageInput({
    super.key,
    required this.sending,
    required this.onSend,
    this.hintText = '输入消息...',
    this.sendLabel = '发送',
  });

  final bool sending;
  final String hintText;
  final String sendLabel;
  final Future<void> Function(
    String text,
    List<AIChatAttachmentPayload> attachments,
  )
  onSend;

  @override
  State<AIMultimodalMessageInput> createState() =>
      _AIMultimodalMessageInputState();
}

class _AIMultimodalMessageInputState extends State<AIMultimodalMessageInput> {
  final TextEditingController _inputController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  SignatureController _signatureController = SignatureController(
    penColor: Colors.black,
    penStrokeWidth: 2.4,
    exportBackgroundColor: Colors.white,
  );

  final List<AIChatAttachmentPayload> _attachments =
      <AIChatAttachmentPayload>[];
  bool _localSending = false;
  bool _eraserMode = false;
  bool _toolsExpanded = false;
  bool _showHandwritingPanel = false;

  bool get _busy => widget.sending || _localSending;

  @override
  void dispose() {
    _inputController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_attachments.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _attachments
                .asMap()
                .entries
                .map(
                  (entry) => InputChip(
                    label: Text(_attachmentLabel(entry.value)),
                    onDeleted: _busy
                        ? null
                        : () => _removeAttachment(entry.key),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 8),
        ],
        if (_toolsExpanded) ...[
          _buildAttachmentToolPanel(context),
          if (_showHandwritingPanel) ...[
            const SizedBox(height: 8),
            _buildHandwritingPanel(context),
          ],
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() {
                        _toolsExpanded = !_toolsExpanded;
                        if (!_toolsExpanded) {
                          _showHandwritingPanel = false;
                        }
                      });
                    },
              icon: Icon(_toolsExpanded ? Icons.close : Icons.add),
              tooltip: _toolsExpanded ? '收起附件工具' : '展开附件工具',
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _inputController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(widget.sendLabel),
            ),
          ],
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
            onPressed: _busy ? null : _pickImageAttachment,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('上传图片'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickAudioAttachment,
            icon: const Icon(Icons.mic_external_on_outlined),
            label: const Text('上传语音'),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy
                ? null
                : () => setState(
                    () => _showHandwritingPanel = !_showHandwritingPanel,
                  ),
            icon: const Icon(Icons.draw_outlined),
            label: Text(_showHandwritingPanel ? '收起画板' : '展开画板'),
          ),
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
                '画板',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                tooltip: '画笔',
                onPressed: _busy ? null : () => _setEraserMode(false),
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
                onPressed: _busy ? null : () => _setEraserMode(true),
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
                onPressed: _busy ? null : _clearSignature,
                child: const Text('清空'),
              ),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _captureSignatureAttachment,
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
              child: Signature(
                controller: _signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点击“加入附件”后，画板内容会转换为图片发送给 AI。',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) {
      return;
    }
    setState(() => _localSending = true);
    try {
      final snapshot = _attachments
          .map(
            (item) => AIChatAttachmentPayload(
              name: item.name,
              source: item.source,
              mimeType: item.mimeType,
              dataUrl: item.dataUrl,
            ),
          )
          .toList(growable: false);
      await widget.onSend(text, snapshot);
      if (!mounted) {
        return;
      }
      setState(() {
        _inputController.clear();
        _attachments.clear();
        _signatureController.clear();
        _toolsExpanded = false;
        _showHandwritingPanel = false;
      });
    } finally {
      if (mounted) {
        setState(() => _localSending = false);
      }
    }
  }

  Future<void> _pickImageAttachment() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        return;
      }
      final name = picked.name.trim().isEmpty
          ? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : picked.name;
      final mimeType = _guessMimeType(name, fallback: 'image/jpeg');
      _appendAttachment(
        AIChatAttachmentPayload(
          name: name,
          source: 'gallery',
          mimeType: mimeType,
          dataUrl: _toDataUrl(mimeType, bytes),
        ),
      );
    } catch (_) {
      // Keep UI silent; parent page will surface network/send errors.
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
      // Keep UI silent; parent page will surface network/send errors.
    }
  }

  Future<void> _captureSignatureAttachment() async {
    if (_signatureController.isEmpty) {
      return;
    }
    final bytes = await _signatureController.toPngBytes();
    if (bytes == null || bytes.isEmpty) {
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
    if (_attachments.length >= 6) {
      return;
    }
    setState(() => _attachments.add(attachment));
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) {
      return;
    }
    setState(() => _attachments.removeAt(index));
  }

  void _setEraserMode(bool eraserMode) {
    if (_eraserMode == eraserMode) {
      return;
    }
    final previous = _signatureController;
    final recreated = SignatureController(
      points: List.from(previous.points),
      penColor: eraserMode ? Colors.white : Colors.black,
      penStrokeWidth: eraserMode ? 14 : 2.4,
      exportBackgroundColor: Colors.white,
    );
    setState(() {
      _eraserMode = eraserMode;
      _signatureController = recreated;
    });
    previous.dispose();
  }

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
}
