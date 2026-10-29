import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final name = TextEditingController();
  final age = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  bool filled = false;

  void _fill() {
    final p = store.profile;
    name.text = p.name;
    age.text = p.age.toString();
    height.text = fmtNum(p.heightCm, 1);
    weight.text = fmtNum(p.weightKg, 1);
    filled = true;
  }

  void _update() {
    final p = store.profile;
    p.name = name.text.trim();
    p.age = int.tryParse(age.text.trim()) ?? p.age;
    final h = parseNum(height.text);
    if (h != null && h > 80 && h < 250) p.heightCm = h;
    final w = parseNum(weight.text);
    if (w != null && w > 25 && w < 300) p.weightKg = w;
    store.profileSet = true;
    store.changed();
  }

  Future<void> _export() async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(store.exportBackup()));
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Save VJ Fit backup',
        fileName: 'vjfit-backup-${dateKey(DateTime.now())}.json',
        bytes: bytes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(path == null ? 'Backup not saved.' : 'Backup saved.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save the backup: $e')));
      }
    }
  }

  Future<void> _import() async {
    final ok = await confirm(context, 'Restore a backup?',
        'This replaces your plans, diets, own exercises, own foods and logs on this phone with the ones in the backup file.',
        action: 'Choose file');
    if (!ok) return;
    try {
      final r = await FilePicker.platform.pickFiles(withData: true);
      final file = r?.files.single;
      if (file == null || file.bytes == null) return;
      store.importBackup(utf8.decode(file.bytes!));
      _fill();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup restored.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That file could not be restored. Pick a .json backup saved from VJ Fit.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!filled) _fill();
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.profile;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Me', style: TextStyle(fontWeight: FontWeight.w900))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Card(
                color: cs.primary,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily target', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700)),
                    Text('${fmtNum(p.targetKcal)} kcal',
                        style: TextStyle(color: cs.onPrimary, fontSize: 34, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Protein ${fmtNum(p.targetProtein)} g · Carbs ${fmtNum(p.targetCarbs)} g · Fat ${fmtNum(p.targetFat)} g',
                        style: TextStyle(color: cs.onPrimary)),
                    const SizedBox(height: 8),
                    Text(
                      'Maintenance about ${fmtNum(p.maintenance)} kcal · BMI ${fmtNum(p.bmi, 1)}',
                      style: TextStyle(color: cs.onPrimary.withAlpha(220), fontSize: 12),
                    ),
                  ]),
                ),
              ),
              const SectionTitle('Your details'),
              TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Name'), onChanged: (_) => _update()),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'm', label: Text('Male')), ButtonSegment(value: 'f', label: Text('Female'))],
                selected: {p.sex},
                onSelectionChanged: (s) {
                  p.sex = s.first;
                  _update();
                },
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _num(age, 'Age', integer: true)),
                const SizedBox(width: 8),
                Expanded(child: _num(height, 'Height (cm)')),
                const SizedBox(width: 8),
                Expanded(child: _num(weight, 'Weight (kg)')),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<double>(
                value: activityLevels.containsKey(p.activity) ? p.activity : 1.55,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'How active are you?'),
                items: [for (final e in activityLevels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) {
                  if (v == null) return;
                  p.activity = v;
                  _update();
                },
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: [for (final g in goals.entries) ButtonSegment(value: g.key, label: Text(g.value))],
                selected: {p.goal},
                onSelectionChanged: (s) {
                  p.goal = s.first;
                  _update();
                },
              ),
              const SizedBox(height: 8),
              Text('Targets use the Mifflin-St Jeor formula. They are a starting point. Check progress every 2-3 weeks and adjust.',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const SectionTitle('Workout history'),
              _History(),
              const SectionTitle('Backup'),
              Text('Your data is stored only on this phone. Save a backup before changing phones or reinstalling.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.tonalIcon(onPressed: _export, icon: const Icon(Icons.save_alt), label: const Text('Save backup')),
                OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.restore), label: const Text('Restore backup')),
              ]),
              const SectionTitle('About'),
              Text(
                'VJ Fit 1.0. Exercise photos and instructions come from the public-domain Free Exercise DB. '
                'Food values are approximate. This app does not give medical advice; check with a doctor before starting a new diet or training plan.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _num(TextEditingController c, String label, {bool integer = false}) => TextField(
        controller: c,
        keyboardType: integer ? TextInputType.number : const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => _update(),
      );
}

class _History extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final rows = <(String, int, double)>[];
    final dates = store.workoutLog.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final d in dates) {
      var sets = 0;
      var volume = 0.0;
      store.workoutLog[d]!.forEach((_, list) {
        for (final s in list) {
          if (!s.done) continue;
          sets++;
          if (s.weight != null && s.reps != null) volume += s.weight! * s.reps!;
        }
      });
      if (sets > 0) rows.add((d, sets, volume));
      if (rows.length >= 30) break;
    }
    if (rows.isEmpty) {
      return const Text('No workouts logged yet. Tick sets on the Today tab and they will show here.');
    }
    return Card(
      child: Column(children: [
        for (final r in rows)
          ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(_pretty(r.$1)),
            subtitle: Text('${r.$2} sets${r.$3 > 0 ? ' · ${fmtNum(r.$3)} kg lifted' : ''}'),
          ),
      ]),
    );
  }

  String _pretty(String key) {
    final p = key.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return '${weekdayLong[d.weekday - 1]}, ${d.day}/${d.month}/${d.year}';
  }
}
