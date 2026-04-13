import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../core/constants.dart';

/// Holds the media selected/recorded by [MediaAttachmentWidget].
/// Pass this to your form's submit logic to access the chosen files.
class MediaAttachmentController {
  XFile? photo;
  Uint8List? photoBytes; // cached bytes for web preview
  String? audioPath;   // file path on native; blob URL on web
  String? audioLabel;  // human-readable label
  String? videoName;
  PlatformFile? videoPlatformFile; // used on web
  XFile? videoFile;                // used on native

  bool get hasPhoto => photo != null;
  bool get hasAudio => audioPath != null;
  bool get hasVideo => videoName != null;

  void clearAll() {
    photo = null;
    photoBytes = null;
    audioPath = null;
    audioLabel = null;
    videoName = null;
    videoPlatformFile = null;
    videoFile = null;
  }
}

/// A reusable widget that lets users attach a photo, record an audio note,
/// and pick a video — fully web-compatible (Chrome).
class MediaAttachmentWidget extends StatefulWidget {
  final MediaAttachmentController controller;
  final String label;

  const MediaAttachmentWidget({
    super.key,
    required this.controller,
    this.label = 'Doctor Visit Media',
  });

  @override
  State<MediaAttachmentWidget> createState() => _MediaAttachmentWidgetState();
}

class _MediaAttachmentWidgetState extends State<MediaAttachmentWidget> {
  final _recorder = AudioRecorder();
  // Created lazily on first playback to avoid exhausting Web AudioContext limit
  AudioPlayer? _player;

  bool _isRecording = false;
  bool _isPlaying = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player?.dispose();
    super.dispose();
  }

  // ── Photo ────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    try {
      XFile? file;
      if (kIsWeb) {
        // On web, calling await showDialog() before the picker loses the
        // browser's user-gesture context, blocking the file input.
        // Skip the dialog and open the file picker directly.
        file = await ImagePicker().pickImage(source: ImageSource.gallery);
      } else {
        final source = await showDialog<ImageSource>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add Photo'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Camera'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Gallery / File'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
        if (source == null) return;
        file = await ImagePicker()
            .pickImage(source: source, imageQuality: 80);
      }
      if (file != null && mounted) {
        Uint8List? bytes;
        if (kIsWeb) bytes = await file.readAsBytes();
        setState(() {
          widget.controller.photo = file;
          widget.controller.photoBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not pick photo: $e'),
            backgroundColor: kError,
          ),
        );
      }
    }
  }

  // ── Audio ────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Microphone permission is required to record audio.'),
            backgroundColor: kError,
          ),
        );
      }
      return;
    }

    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path =
          '${dir.path}/visit_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _recorder.start(
      RecordConfig(
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    _timer?.cancel();
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
      widget.controller.audioPath = null;
      widget.controller.audioLabel = null;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    final label = 'Audio note — ${_fmtDuration(_elapsed)}';
    setState(() {
      _isRecording = false;
      widget.controller.audioPath = path;
      widget.controller.audioLabel = label;
    });
  }

  Future<void> _togglePlayback() async {
    final path = widget.controller.audioPath;
    if (path == null) return;
    _player ??= AudioPlayer(); // create lazily on first playback

    if (_isPlaying) {
      await _player!.stop();
      if (mounted) setState(() => _isPlaying = false);
    } else {
      if (mounted) setState(() => _isPlaying = true);
      final Source src =
          kIsWeb ? UrlSource(path) : DeviceFileSource(path);
      await _player!.play(src);
      _player!.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _isPlaying = false);
      });
    }
  }

  String _fmtDuration(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:'
      '${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  // ── Video ────────────────────────────────────────────────────────────────

  // Keep web video limit reasonable to avoid Chrome out-of-memory crashes.
  static const _maxVideoBytes = 500 * 1024 * 1024; // 500 MB
  static const _maxVideoBytesNative = 500 * 1024 * 1024; // 500 MB on native

  Future<void> _pickVideo() async {
    if (kIsWeb) {
      // withData: true is required on web — path is unavailable, only bytes work.
      // Limit to 50 MB to avoid Chrome out-of-memory crashes.
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.first;
        if (file.size > _maxVideoBytes) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Video is too large (${(file.size / (1024 * 1024)).toStringAsFixed(1)} MB). Please choose a video under 500 MB.'),
            backgroundColor: kError,
          ));
          return;
        }
        setState(() {
          widget.controller.videoPlatformFile = file;
          widget.controller.videoName = file.name;
          widget.controller.videoFile = null;
        });
      }
    } else {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );
      if (file != null && mounted) {
        final size = await file.length();
        if (!mounted) return;
        if (size > _maxVideoBytesNative) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Video is too large (${(size / (1024 * 1024)).toStringAsFixed(1)} MB). Please choose a file under 500 MB.'),
            backgroundColor: kError,
          ));
          return;
        }
        setState(() {
          widget.controller.videoFile = file;
          widget.controller.videoName = file.name;
          widget.controller.videoPlatformFile = null;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            const Icon(Icons.perm_media_outlined, size: 16, color: kPrimary),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Three action buttons
        Row(
          children: [
            _MediaActionButton(
              icon: Icons.camera_alt_outlined,
              label: 'Photo',
              isActive: c.hasPhoto,
              onTap: _pickPhoto,
            ),
            const SizedBox(width: 8),
            _MediaActionButton(
              icon: _isRecording
                  ? Icons.stop_circle_outlined
                  : Icons.mic_outlined,
              label: _isRecording
                  ? _fmtDuration(_elapsed)
                  : (c.hasAudio ? 'Re-record' : 'Record'),
              isActive: c.hasAudio,
              isRecording: _isRecording,
              onTap: _isRecording ? _stopRecording : _startRecording,
            ),
            const SizedBox(width: 8),
            _MediaActionButton(
              icon: Icons.videocam_outlined,
              label: 'Video',
              isActive: c.hasVideo,
              onTap: _pickVideo,
            ),
          ],
        ),

        // Attached media previews
        if (c.hasPhoto || c.hasAudio || c.hasVideo) ...[
          const SizedBox(height: 10),
          if (c.hasPhoto)
            _MediaPreviewTile(
              label: 'Photo attached',
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: kIsWeb && c.photoBytes != null
                    ? Image.memory(c.photoBytes!,
                        width: 48, height: 48, fit: BoxFit.cover)
                    : kIsWeb
                        ? const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.image, color: kPrimary),
                          )
                        : Image.file(File(c.photo!.path),
                            width: 48, height: 48, fit: BoxFit.cover),
              ),
              onRemove: () => setState(() => c.photo = null),
            ),
          if (c.hasAudio)
            _MediaPreviewTile(
              label: c.audioLabel ?? 'Audio note',
              leading: const Icon(Icons.audiotrack, color: kPrimary, size: 26),
              trailing: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  color: kPrimary,
                  size: 28,
                ),
                onPressed: _togglePlayback,
              ),
              onRemove: () => setState(() {
                c.audioPath = null;
                c.audioLabel = null;
                _isPlaying = false;
                _player?.stop();
              }),
            ),
          if (c.hasVideo)
            _MediaPreviewTile(
              label: c.videoName ?? 'Video attached',
              leading: const Icon(Icons.video_file_outlined,
                  color: kPrimary, size: 26),
              onRemove: () => setState(() {
                c.videoName = null;
                c.videoFile = null;
                c.videoPlatformFile = null;
              }),
            ),
        ],
      ],
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _MediaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final bool isRecording;
  final VoidCallback onTap;

  const _MediaActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isRecording = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? kError : (isActive ? kSuccess : kPrimary);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isActive || isRecording ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPreviewTile extends StatelessWidget {
  final String label;
  final Widget leading;
  final Widget? trailing;
  final VoidCallback onRemove;

  const _MediaPreviewTile({
    required this.label,
    required this.leading,
    required this.onRemove,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: kText),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            trailing!,
            const SizedBox(width: 4),
          ],
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: kSubtext),
          ),
        ],
      ),
    );
  }
}
