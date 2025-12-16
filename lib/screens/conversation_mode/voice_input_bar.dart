import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:audio_waveforms/audio_waveforms.dart';

class VoiceInputBar extends StatefulWidget {
  final Future<void> Function(String content, String type, String previewText) onSend;

  const VoiceInputBar({super.key, required this.onSend});

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar> {
  bool _isRecording = false;
  bool _isUploading = false;

  final SupabaseClient _supabase = Supabase.instance.client;
  final Uuid _uuid = const Uuid();

  late final RecorderController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC;
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/${_uuid.v4()}.m4a';
    await _waveController.record(path: filePath);
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _waveController.stop();
    setState(() => _isRecording = false);

    if (path != null) {
      _uploadAndSendAudio(File(path));
    }
  }

  Future<void> _uploadAndSendAudio(File audioFile) async {
    setState(() => _isUploading = true);
    try {
      const bucketName = 'videoMessage';
      final fileExtension = audioFile.path.split('.').last;
      final fileName = '${_uuid.v4()}.$fileExtension';
      final storagePath = 'audio/$fileName';

      await _supabase.storage.from(bucketName).upload(
            storagePath,
            audioFile,
            fileOptions: const FileOptions(contentType: 'audio/m4a', upsert: false),
          );

      final publicUrl = _supabase.storage.from(bucketName).getPublicUrl(storagePath);

      await widget.onSend(publicUrl, 'voice', 'Sent a voice message');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload audio.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 64,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFAC46FF), Color(0xFFE50076)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: GestureDetector(
            onTap: _isUploading
                ? null
                : (_isRecording ? _stopRecording : _startRecording),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isUploading
                        ? Icons.hourglass_empty
                        : _isRecording
                            ? Icons.stop
                            : Icons.mic,
                    color: Colors.white,
                    size: 28,
                  ),
                  if (_isRecording) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: AudioWaveforms(
                        size: const Size(double.infinity, 30),
                        recorderController: _waveController,
                        waveStyle: const WaveStyle(
                          waveColor: Colors.white,
                          extendWaveform: true,
                          showMiddleLine: false,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}