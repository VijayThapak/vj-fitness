import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'platform/platform.dart' as platform;

String fmtNum(double v, [int digits = 0]) {
  if (digits == 0) return v.round().toString();
  final s = v.toStringAsFixed(digits);
  return s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
}

String fmtQty(double q) => fmtNum(q, 2);

/// Shows an asset image or a photo saved on the phone.
class AppImage extends StatelessWidget {
  final String path;
  final BoxFit fit;
  const AppImage(this.path, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final err = (BuildContext c, Object e, StackTrace? s) => Container(
          color: Theme.of(c).colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: const Icon(Icons.image_not_supported_outlined),
        );
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: fit, gaplessPlayback: true, errorBuilder: err);
    }
    return Image(image: platform.photoImage(path), fit: fit, gaplessPlayback: true, errorBuilder: err);
  }
}

/// Small square thumbnail for list rows.
class ExerciseThumb extends StatelessWidget {
  final Exercise? ex;
  final double size;
  const ExerciseThumb(this.ex, {super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final imgs = ex?.images ?? const <String>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: imgs.isNotEmpty
            ? AppImage(imgs.length > 1 ? imgs[1] : imgs[0])
            : Container(
                color: cs.primaryContainer,
                alignment: Alignment.center,
                child: Text(
                  (ex?.name.isNotEmpty ?? false) ? ex!.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: size * 0.4, fontWeight: FontWeight.w800, color: cs.onPrimaryContainer),
                ),
              ),
      ),
    );
  }
}

/// Large photo that flips between the start and finish position, like a short demo.
class PhotoDemo extends StatefulWidget {
  final List<String> images;
  const PhotoDemo(this.images, {super.key});
  @override
  State<PhotoDemo> createState() => _PhotoDemoState();
}

class _PhotoDemoState extends State<PhotoDemo> {
  int frame = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
        if (mounted) setState(() => frame = (frame + 1) % widget.images.length);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final labels = widget.images.length == 2 ? const ['Start', 'Finish'] : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 3 / 2,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(key: ValueKey(frame), child: AppImage(widget.images[frame])),
            ),
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            for (var i = 0; i < 2; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Chip(
                  label: Text(labels[i]),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: frame == i ? cs.primary : null,
                  labelStyle: TextStyle(color: frame == i ? cs.onPrimary : null, fontWeight: FontWeight.w700),
                ),
              ),
          ]),
        ],
      ],
    );
  }
}

class MuscleChips extends StatelessWidget {
  final List<String> primary;
  final List<String> secondary;
  const MuscleChips({super.key, required this.primary, required this.secondary});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final m in primary)
        Chip(
          label: Text(cap(m)),
          backgroundColor: cs.primary,
          labelStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w600),
          visualDensity: VisualDensity.compact,
        ),
      for (final m in secondary)
        Chip(label: Text(cap(m)), visualDensity: VisualDensity.compact),
    ]);
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(children: [
          Expanded(
            child: Text(text.toUpperCase(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

Future<void> openVideo(BuildContext context, String exerciseName) async {
  final uri = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeQueryComponent('$exerciseName exercise proper form')}');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open YouTube. Check that a browser or YouTube is installed.')));
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return r == true;
}

Future<String?> askText(BuildContext context, String title, {String initial = '', String label = 'Name'}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Save')),
      ],
    ),
  );
  final t = r?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

double? parseNum(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

// ---------------- Rest timer ----------------

class RestTimer extends ChangeNotifier {
  Timer? _t;
  DateTime? _end;
  int total = 0;
  String label = '';
  bool finished = false;

  int get remaining {
    final e = _end;
    if (e == null) return 0;
    final r = (e.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    return r < 0 ? 0 : r;
  }

  bool get running => _end != null;

  void start(int seconds, String what) {
    if (seconds <= 0) return;
    _t?.cancel();
    total = seconds;
    label = what;
    finished = false;
    _end = DateTime.now().add(Duration(seconds: seconds));
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (remaining <= 0) {
        _t?.cancel();
        _end = null;
        finished = true;
        _buzz();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void add(int seconds) {
    if (_end == null) return;
    _end = _end!.add(Duration(seconds: seconds));
    total += seconds;
    notifyListeners();
  }

  void stop() {
    _t?.cancel();
    _end = null;
    finished = false;
    notifyListeners();
  }

  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  }
}

final restTimer = RestTimer();

String fmtClock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class RestTimerBar extends StatelessWidget {
  const RestTimerBar({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: restTimer,
      builder: (context, _) {
        if (!restTimer.running && !restTimer.finished) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final rem = restTimer.remaining;
        final done = restTimer.finished;
        return Material(
          color: done ? cs.tertiaryContainer : cs.primaryContainer,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: done || restTimer.total == 0 ? 1 : rem / restTimer.total,
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(done ? 'Rest over. Next set!' : 'Rest  ${fmtClock(rem)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFeatures: [FontFeature.tabularFigures()])),
                    Text(restTimer.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (!done) TextButton(onPressed: () => restTimer.add(15), child: const Text('+15s')),
                IconButton(onPressed: restTimer.stop, icon: const Icon(Icons.close), tooltip: 'Close timer'),
              ]),
            ),
          ),
        );
      },
    );
  }
}
