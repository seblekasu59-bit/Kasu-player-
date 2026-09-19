
import 'dart:async';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() => runApp(const KasuPlayerApp());

class Track {
  final String name, path;
  Track(this.name, this.path);
}

class KasuPlayerApp extends StatelessWidget {
  const KasuPlayerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Kasu player',
    theme: ThemeData.dark(useMaterial3: true),
    home: const KasuHome(),
  );
}

class KasuHome extends StatefulWidget {
  const KasuHome({super.key});
  @override
  State<KasuHome> createState() => _KasuHomeState();
}

class _KasuHomeState extends State<KasuHome>
    with SingleTickerProviderStateMixin {
  final AudioPlayer player = AudioPlayer();
  final List<Track> tracks = [];
  late final AnimationController reels;

  int current = 0;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  StreamSubscription? pSub, dSub, sSub, cSub;

  String get title => tracks.isEmpty ? 'Kasu player' : tracks[current].name;

  @override
  void initState() {
    super.initState();
    reels = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    pSub = player.onPositionChanged.listen((p) {
      if (mounted) setState(() => position = p);
    });
    dSub = player.onDurationChanged.listen((d) {
      if (mounted) setState(() => duration = d);
    });
    sSub = player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      final isPlaying = s == PlayerState.playing;
      setState(() => playing = isPlaying);
      if (isPlaying) {
        reels.repeat();
      } else {
        reels.stop();
      }
    });
    cSub = player.onPlayerComplete.listen((_) => next());
  }

  @override
  void dispose() {
    pSub?.cancel();
    dSub?.cancel();
    sSub?.cancel();
    cSub?.cancel();
    reels.dispose();
    player.dispose();
    super.dispose();
  }

  Future<void> addSongs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;

    final added = result.files
        .where((f) => f.path != null)
        .map((f) => Track(
              f.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
              f.path!,
            ))
        .toList();

    if (added.isEmpty) return;

    final wasEmpty = tracks.isEmpty;
    setState(() => tracks.addAll(added));

    if (wasEmpty) {
      current = 0;
      await loadCurrent(autoPlay: true);
    }
  }

  Future<void> loadCurrent({bool autoPlay = false}) async {
    if (tracks.isEmpty) return;
    await player.setSourceDeviceFile(tracks[current].path);
    if (mounted) {
      setState(() {
        position = Duration.zero;
        duration = Duration.zero;
      });
    }
    if (autoPlay) await player.resume();
  }

  Future<void> togglePlay() async {
    if (tracks.isEmpty) {
      await addSongs();
      return;
    }
    if (playing) {
      await player.pause();
    } else {
      await player.resume();
    }
  }

  Future<void> next() async {
    if (tracks.isEmpty) return;
    setState(() => current = (current + 1) % tracks.length);
    await loadCurrent(autoPlay: true);
  }

  Future<void> previous() async {
    if (tracks.isEmpty) return;
    if (position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    setState(() => current = (current - 1 + tracks.length) % tracks.length);
    await loadCurrent(autoPlay: true);
  }

  Future<void> rewind() async {
    final target = position - const Duration(seconds: 10);
    await player.seek(target.isNegative ? Duration.zero : target);
  }

  Future<void> forward() async {
    final target = position + const Duration(seconds: 10);
    await player.seek(target > duration ? duration : target);
  }

  String time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void openDisplay() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullDisplay(
          player: player,
          reels: reels,
          title: () => title,
          isPlaying: () => playing,
          position: () => position,
          duration: () => duration,
          onPlay: togglePlay,
          onPrevious: previous,
          onNext: next,
          onRewind: rewind,
          onForward: forward,
          time: time,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11100F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF11100F),
        centerTitle: true,
        title: const Text(
          'Kasu player',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Add songs',
            onPressed: addSongs,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            children: [
              GestureDetector(
                onTap: openDisplay,
                child: AnimatedBuilder(
                  animation: reels,
                  builder: (_, __) => Cassette(
                    angle: reels.value * math.pi * 2,
                    title: title,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text('${time(position)} / ${time(duration)}',
                  style: TextStyle(color: Colors.grey.shade400)),
              Slider(
                value: duration.inMilliseconds == 0
                    ? 0
                    : position.inMilliseconds
                        .clamp(0, duration.inMilliseconds)
                        .toDouble(),
                max: math.max(1, duration.inMilliseconds).toDouble(),
                onChanged: (v) =>
                    player.seek(Duration(milliseconds: v.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous song',
                    onPressed: previous,
                    iconSize: 34,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    tooltip: 'Rewind 10 seconds',
                    onPressed: rewind,
                    iconSize: 32,
                    icon: const Icon(Icons.replay_10),
                  ),
                  FloatingActionButton.large(
                    backgroundColor: const Color(0xFFD59A32),
                    foregroundColor: Colors.black,
                    onPressed: togglePlay,
                    child: Icon(
                      playing ? Icons.pause : Icons.play_arrow,
                      size: 42,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Forward 10 seconds',
                    onPressed: forward,
                    iconSize: 32,
                    icon: const Icon(Icons.forward_10),
                  ),
                  IconButton(
                    tooltip: 'Next song',
                    onPressed: next,
                    iconSize: 34,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: addSongs,
                icon: const Icon(Icons.library_music),
                label: const Text('Add songs'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: openDisplay,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Display'),
              ),
              if (tracks.isNotEmpty) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Playlist (${tracks.length})',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 6),
                ...List.generate(
                  tracks.length,
                  (i) => ListTile(
                    selected: i == current,
                    leading: CircleAvatar(
                      backgroundColor: i == current
                          ? const Color(0xFFD59A32)
                          : Colors.grey.shade800,
                      foregroundColor: Colors.black,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(
                      tracks[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: i == current && playing
                        ? const Icon(Icons.equalizer)
                        : null,
                    onTap: () async {
                      setState(() => current = i);
                      await loadCurrent(autoPlay: true);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Cassette extends StatelessWidget {
  final double angle;
  final String title;

  const Cassette({
    super.key,
    required this.angle,
    required this.title,
  });

  Widget reel() {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF151515),
          border: Border.all(
            color: const Color(0xFFC99A4B),
            width: 5,
          ),
        ),
        child: const Icon(
          Icons.settings,
          color: Color(0xFFC99A4B),
          size: 46,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.45,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF24211E),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFC99A4B),
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFD8B878),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black87,
                    width: 3,
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          reel(),
                          Container(
                            width: 74,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFF171513),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          reel(),
                        ],
                      ),
                    ),
                    Container(
                      height: 15,
                      color: const Color(0xFFB94B2C),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                13,
                (i) => Container(
                  width: 4,
                  height: 8 + (i % 5) * 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: const Color(0xFFD59A32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullDisplay extends StatefulWidget {
  final AudioPlayer player;
  final AnimationController reels;
  final String Function() title;
  final bool Function() isPlaying;
  final Duration Function() position;
  final Duration Function() duration;
  final VoidCallback onPlay, onPrevious, onNext, onRewind, onForward;
  final String Function(Duration) time;

  const FullDisplay({
    super.key,
    required this.player,
    required this.reels,
    required this.title,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlay,
    required this.onPrevious,
    required this.onNext,
    required this.onRewind,
    required this.onForward,
    required this.time,
  });

  @override
  State<FullDisplay> createState() => _FullDisplayState();
}

class _FullDisplayState extends State<FullDisplay> {
  StreamSubscription? pSub, sSub;

  @override
  void initState() {
    super.initState();
    pSub = widget.player.onPositionChanged.listen((_) {
      if (mounted) setState(() {});
    });
    sSub = widget.player.onPlayerStateChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    pSub?.cancel();
    sSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = widget.position();
    final dur = widget.duration();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0A09),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: const Text('Kasu player'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: widget.reels,
                builder: (_, __) => Cassette(
                  angle: widget.reels.value * math.pi * 2,
                  title: widget.title(),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 27, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Slider(
                value: dur.inMilliseconds == 0
                    ? 0
                    : pos.inMilliseconds
                        .clamp(0, dur.inMilliseconds)
                        .toDouble(),
                max: math.max(1, dur.inMilliseconds).toDouble(),
                onChanged: (v) =>
                    widget.player.seek(Duration(milliseconds: v.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.time(pos)),
                  Text(widget.time(dur)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: widget.onPrevious,
                    iconSize: 34,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    onPressed: widget.onRewind,
                    iconSize: 34,
                    icon: const Icon(Icons.replay_10),
                  ),
                  FloatingActionButton.large(
                    backgroundColor: const Color(0xFFD59A32),
                    foregroundColor: Colors.black,
                    onPressed: widget.onPlay,
                    child: Icon(
                      widget.isPlaying()
                          ? Icons.pause
                          : Icons.play_arrow,
                      size: 48,
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onForward,
                    iconSize: 34,
                    icon: const Icon(Icons.forward_10),
                  ),
                  IconButton(
                    onPressed: widget.onNext,
                    iconSize: 34,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
