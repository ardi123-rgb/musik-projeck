// Dart | lib/main.dart | Flutter | Android & iOS
//
// Music player sederhana:
// - Tambah lagu dari file lokal (file picker)
// - Tambah lagu dari URL streaming (link langsung ke file audio, sumber legal)
// - Play / pause / next / previous
// - Auto lanjut ke lagu berikutnya saat lagu selesai

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const MusicPlayerApp());
}

class MusicPlayerApp extends StatelessWidget {
  const MusicPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const PlayerHomePage(),
    );
  }
}

/// Satu lagu di playlist — bisa dari file lokal atau URL streaming.
class Track {
  final String title;
  final String source; // path file lokal, atau URL streaming
  final bool isLocal;

  Track({required this.title, required this.source, required this.isLocal});
}

class PlayerHomePage extends StatefulWidget {
  const PlayerHomePage({super.key});

  @override
  State<PlayerHomePage> createState() => _PlayerHomePageState();
}

class _PlayerHomePageState extends State<PlayerHomePage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Track> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;

  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final name = result.files.single.name;

    setState(() {
      _playlist.add(Track(title: name, source: path, isLocal: true));
    });
  }

  void _addStreamingUrl() {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _playlist.add(
        Track(title: _shortTitleFromUrl(url), source: url, isLocal: false),
      );
      _urlController.clear();
    });
  }

  String _shortTitleFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final segments = uri.pathSegments;
    return segments.isNotEmpty ? segments.last : url;
  }

  Future<void> _playTrackAt(int index) async {
    if (index < 0 || index >= _playlist.length) return;

    final track = _playlist[index];

    try {
      if (track.isLocal) {
        await _audioPlayer.setFilePath(track.source);
      } else {
        await _audioPlayer.setUrl(track.source);
      }
      await _audioPlayer.play();
      setState(() {
        _currentIndex = index;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memutar: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_currentIndex == -1 && _playlist.isNotEmpty) {
      _playTrackAt(0);
      return;
    }
    if (_isPlaying) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  void _playNext() {
    if (_playlist.isEmpty) return;
    final nextIndex = (_currentIndex + 1) % _playlist.length;
    _playTrackAt(nextIndex);
  }

  void _playPrevious() {
    if (_playlist.isEmpty) return;
    final prevIndex =
        _currentIndex <= 0 ? _playlist.length - 1 : _currentIndex - 1;
    _playTrackAt(prevIndex);
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack =
        _currentIndex >= 0 && _currentIndex < _playlist.length
            ? _playlist[_currentIndex]
            : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Music Player')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      hintText: 'Tempel URL audio (streaming)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_link),
                  tooltip: 'Tambah dari URL',
                  onPressed: _addStreamingUrl,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _pickLocalFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('Tambah file lokal'),
              ),
            ),
          ),
          const Divider(),
          Expanded(
            child: _playlist.isEmpty
                ? const Center(child: Text('Playlist masih kosong'))
                : ListView.builder(
                    itemCount: _playlist.length,
                    itemBuilder: (context, index) {
                      final track = _playlist[index];
                      final isActive = index == _currentIndex;
                      return ListTile(
                        leading: Icon(
                          track.isLocal ? Icons.folder : Icons.cloud,
                        ),
                        title: Text(
                          track.title,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(track.isLocal ? 'Lokal' : 'Streaming'),
                        onTap: () => _playTrackAt(index),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    currentTrack?.title ?? 'Belum ada lagu diputar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous),
                        onPressed: _playPrevious,
                      ),
                      IconButton(
                        iconSize: 56,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                        onPressed: _togglePlayPause,
                      ),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next),
                        onPressed: _playNext,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
