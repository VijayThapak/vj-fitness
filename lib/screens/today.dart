import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'workouts.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback onOpenDiet;
  const TodayScreen({super.key, required this.onOpenDiet});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late int day = DateTime.now().weekday - 1; // 0 = Monday
  bool awake = false;

  DateTime get dateForDay {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(Duration(days: day - (now.weekday - 1)));
  }

  Future<void> toggleAwake() async {
    try {
      await WakelockPlus.toggle(enable: !awake);
      setState(() => awake = !awake);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This device does not allow keeping the screen on.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final plan = store.activePlan;
        final todayIdx = DateTime.now().weekday - 1;
        final date = dateKey(dateForDay);
        final cs = Theme.of(context).colorScheme;
        final pd = plan?.days[day];
        return Scaffold(
          appBar: AppBar(
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.profile.name.isEmpty ? 'VJ Fit' : 'Hi, ${store.profile.name}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                '${weekdayLong[day]}${day == todayIdx ? ' · Today' : ''} · ${plan?.name ?? 'No plan'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
            actions: [
              IconButton(
                tooltip: awake ? 'Screen stays on' : 'Keep screen on',
                onPressed: toggleAwake,
                icon: Icon(awake ? Icons.lightbulb : Icons.lightbulb_outline),
              ),
            ],
          ),
          body: plan == null
              ? const Center(child: Text('Create a workout plan in the Workouts tab.'))
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    SizedBox(
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: 7,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (c, i) => ChoiceChip(
                          label: Text(weekdayShort[i] + (i == todayIdx ? ' •' : '')),
                          selected: i == day,
                          onSelected: (_) => setState(() => day = i),
                        ),
                      ),
                    ),
                    _DayHeader(day: pd!, date: date),
                    if (day == todayIdx) _DietSummary(onTap: widget.onOpenDiet),
                    if (pd.items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(children: [
                          Icon(Icons.self_improvement, size: 56, color: cs.primary),
                          const SizedBox(height: 8),
                          const Text('Nothing planned for this day. Rest well, or add exercises in Workouts.',
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    for (final phase in const ['warm', 'main', 'cool'])
                      if (pd.items.any((i) => i.phase == phase)) ...[
                        SectionTitle(phase == 'warm' ? 'Warm-up' : phase == 'cool' ? 'Cool-down' : 'Workout'),
                        for (final it in pd.items.where((i) => i.phase == phase))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                            child: WorkoutItemCard(item: it, date: date),
                          ),
                      ],
                  ],
                ),
        );
      },
    );
  }
}

class _DayHeader extends StatelessWidget {
  final PlanDay day;
  final String date;
  const _DayHeader({required this.day, required this.date});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (done, total) = store.dayProgress(date, day);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Card(
        color: cs.primary,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(day.title.isEmpty ? 'Rest day' : day.title,
                style: TextStyle(color: cs.onPrimary, fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
            if (day.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(day.note, style: TextStyle(color: cs.onPrimary.withAlpha(230))),
            ],
            if (total > 0) ...[
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: done / total,
                      minHeight: 8,
                      color: cs.onPrimary,
                      backgroundColor: cs.onPrimary.withAlpha(60),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$done/$total sets', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text('Tap a set when you finish it. Press and hold a set to log weight and reps.',
                  style: TextStyle(color: cs.onPrimary.withAlpha(210), fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _DietSummary extends StatelessWidget {
  final VoidCallback onTap;
  const _DietSummary({required this.onTap});
  @override
  Widget build(BuildContext context) {
    final eaten = store.eatenTotals(dateKey(DateTime.now()));
    final target = store.profile.targetKcal;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.restaurant, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fmtNum(eaten.kcal)} / ${fmtNum(target)} kcal eaten today',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: target <= 0 ? 0 : (eaten.kcal / target).clamp(0.0, 1.0)),
                  const SizedBox(height: 4),
                  Text('Protein ${fmtNum(eaten.protein)} / ${fmtNum(store.profile.targetProtein)} g',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One exercise in today's workout with tappable set buttons.
class WorkoutItemCard extends StatelessWidget {
  final PlanItem item;
  final String date;
  const WorkoutItemCard({super.key, required this.item, required this.date});

  Future<void> _editSet(BuildContext context, SetLog s, int index, Exercise? ex) async {
    final w = TextEditingController(text: s.weight == null ? '' : fmtNum(s.weight!, 2));
    final r = TextEditingController(text: s.reps?.toString() ?? '');
    final last = ex == null ? null : store.lastLogFor(ex.id, date);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Set ${index + 1}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (last != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                  'Last time: ${last.weight == null ? '' : '${fmtNum(last.weight!, 2)} kg'}${last.weight != null && last.reps != null ? ' × ' : ''}${last.reps == null ? '' : '${last.reps} reps'}'),
            ),
          TextField(
            controller: w,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: r,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps done'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save set')),
        ],
      ),
    );
    if (ok == true) {
      s.weight = parseNum(w.text);
      s.reps = int.tryParse(r.text.trim());
      final wasDone = s.done;
      s.done = true;
      store.changed();
      if (!wasDone && item.rest > 0) restTimer.start(item.rest, ex?.name ?? 'Rest');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = store.exercise(item.exId);
    final sets = store.setsFor(date, item);
    final allDone = store.itemDone(date, item);
    final cs = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: allDone ? cs.primary : cs.outlineVariant, width: allDone ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: ex == null
              ? null
              : () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: ex, note: item.note))),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                ExerciseThumb(ex, size: 60),
                if (allDone)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: CircleAvatar(radius: 13, backgroundColor: cs.primary, child: Icon(Icons.check, size: 16, color: cs.onPrimary)),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ex?.name ?? 'Missing exercise', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    '${item.sets > 1 ? '${item.sets} × ' : ''}${item.reps}${item.rest > 0 ? ' · rest ${item.rest}s' : ''}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < item.sets; i++)
              _SetButton(
                label: item.sets == 1 ? 'Done' : 'Set ${i + 1}',
                log: sets[i],
                onTap: () {
                  HapticFeedback.lightImpact();
                  final s = sets[i];
                  s.done = !s.done;
                  store.changed();
                  if (s.done && item.rest > 0) restTimer.start(item.rest, ex?.name ?? 'Rest');
                },
                onLongPress: () => _editSet(context, sets[i], i, ex),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _SetButton extends StatelessWidget {
  final String label;
  final SetLog log;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _SetButton({required this.label, required this.log, required this.onTap, required this.onLongPress});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final detail = [
      if (log.weight != null) '${fmtNum(log.weight!, 2)}kg',
      if (log.reps != null) '×${log.reps}',
    ].join(' ');
    return Material(
      color: log.done ? cs.primary : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: log.done ? cs.onPrimary : cs.onSurface)),
            if (detail.isNotEmpty)
              Text(detail, style: TextStyle(fontSize: 11, color: log.done ? cs.onPrimary : cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
