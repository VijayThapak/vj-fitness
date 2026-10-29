import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models.dart';
import '../platform/platform.dart' as platform;
import '../store.dart';
import '../widgets.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Workouts', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(tabs: [Tab(text: 'My plans'), Tab(text: 'Exercise library')]),
        ),
        body: const TabBarView(children: [PlansTab(), ExerciseLibrary()]),
      ),
    );
  }
}

// ======================= Plans =======================

class PlansTab extends StatelessWidget {
  const PlansTab({super.key});

  Future<void> _newPlan(BuildContext context) async {
    final name = await askText(context, 'New workout plan', label: 'Plan name');
    if (name == null) return;
    final p = WorkoutPlan(name: name);
    store.plans.add(p);
    store.changed();
    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: p)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'newplan',
            onPressed: () => _newPlan(context),
            icon: const Icon(Icons.add),
            label: const Text('New plan'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('The active plan shows on the Today tab. Tap a plan to change its days and exercises.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final p in store.plans) ...[
                _PlanCard(plan: p),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final WorkoutPlan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = store.activePlan?.id == plan.id;
    final trainDays = plan.days.where((d) => d.items.isNotEmpty).length;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? cs.primary : cs.outlineVariant, width: active ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlanEditorScreen(plan: plan))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(plan.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                  if (active) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Active'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: cs.primary,
                      labelStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ]),
                const SizedBox(height: 4),
                Text('$trainDays day${trainDays == 1 ? '' : 's'} a week'),
                const SizedBox(height: 4),
                Text(
                  [for (var i = 0; i < 7; i++) if (plan.days[i].items.isNotEmpty) '${weekdayShort[i]}: ${plan.days[i].title}'].join('  ·  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'active') {
                  store.activePlanId = plan.id;
                  store.changed();
                } else if (v == 'rename') {
                  final n = await askText(context, 'Rename plan', initial: plan.name, label: 'Plan name');
                  if (n != null) {
                    plan.name = n;
                    store.changed();
                  }
                } else if (v == 'copy') {
                  store.plans.add(plan.copy('${plan.name} (copy)'));
                  store.changed();
                } else if (v == 'delete') {
                  if (store.plans.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need at least one plan. Create another plan first.')));
                    return;
                  }
                  if (await confirm(context, 'Delete "${plan.name}"?', 'This removes the plan. Your past workout logs stay.')) {
                    store.plans.remove(plan);
                    if (store.activePlanId == plan.id) store.activePlanId = store.plans.first.id;
                    store.changed();
                  }
                }
              },
              itemBuilder: (_) => [
                if (!active) const PopupMenuItem(value: 'active', child: Text('Use this plan')),
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                const PopupMenuItem(value: 'copy', child: Text('Duplicate')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class PlanEditorScreen extends StatefulWidget {
  final WorkoutPlan plan;
  const PlanEditorScreen({super.key, required this.plan});
  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 7, vsync: this, initialIndex: DateTime.now().weekday - 1);

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> _add(PlanDay day) async {
    final ex = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Pick an exercise')), body: ExerciseLibrary(onPick: (e) => Navigator.pop(context, e)))),
    );
    if (ex == null) return;
    final item = defaultItemFor(ex);
    day.items.add(item);
    store.changed();
    if (mounted) await editItemSheet(context, day, item);
  }

  Future<void> _copyFrom(PlanDay target) async {
    final src = await showDialog<int>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Copy exercises from'),
        children: [
          for (var i = 0; i < 7; i++)
            if (widget.plan.days[i] != target && widget.plan.days[i].items.isNotEmpty)
              SimpleDialogOption(onPressed: () => Navigator.pop(c, i), child: Text('${weekdayLong[i]} · ${widget.plan.days[i].title}')),
        ],
      ),
    );
    if (src == null) return;
    final s = widget.plan.days[src];
    target.title = s.title;
    target.note = s.note;
    target.items = s.items.map((e) => e.copy()).toList();
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final plan = widget.plan;
        return Scaffold(
          appBar: AppBar(
            title: Text(plan.name),
            actions: [
              IconButton(
                tooltip: 'Rename plan',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final n = await askText(context, 'Rename plan', initial: plan.name, label: 'Plan name');
                  if (n != null) {
                    plan.name = n;
                    store.changed();
                  }
                },
              ),
            ],
            bottom: TabBar(
              controller: tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (var i = 0; i < 7; i++) Tab(text: weekdayShort[i])],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addex',
            onPressed: () => _add(plan.days[tabs.index]),
            icon: const Icon(Icons.add),
            label: const Text('Add exercise'),
          ),
          body: TabBarView(
            controller: tabs,
            children: [for (var i = 0; i < 7; i++) _dayEditor(plan.days[i], i)],
          ),
        );
      },
    );
  }

  Widget _dayEditor(PlanDay day, int index) {
    final cs = Theme.of(context).colorScheme;
    return ReorderableListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(day.title.isEmpty ? 'Rest day' : day.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            tooltip: 'Rename day',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final n = await askText(context, '${weekdayLong[index]} name', initial: day.title, label: 'For example: Chest & Abs');
              if (n != null) {
                day.title = n;
                store.changed();
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'note') {
                final n = await askText(context, 'Notes for ${weekdayLong[index]}', initial: day.note, label: 'Notes');
                day.note = n ?? '';
                store.changed();
              } else if (v == 'copy') {
                await _copyFrom(day);
              } else if (v == 'clear') {
                if (await confirm(context, 'Make ${weekdayLong[index]} a rest day?', 'This removes all exercises from this day.', action: 'Clear')) {
                  day.items.clear();
                  day.title = 'Rest day';
                  day.note = '';
                  store.changed();
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'note', child: Text('Edit notes')),
              PopupMenuItem(value: 'copy', child: Text('Copy from another day')),
              PopupMenuItem(value: 'clear', child: Text('Make rest day')),
            ],
          ),
        ]),
        if (day.note.isNotEmpty) Text(day.note, style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text(day.items.isEmpty ? 'No exercises yet. Tap "Add exercise".' : 'Tap to change sets and reps. Hold and drag to reorder.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 8),
      ]),
      onReorder: (a, b) {
        if (b > a) b--;
        final it = day.items.removeAt(a);
        day.items.insert(b, it);
        store.changed();
      },
      children: [
        for (final it in day.items)
          Padding(
            key: ValueKey(it.id),
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                leading: ExerciseThumb(store.exercise(it.exId), size: 48),
                title: Text(store.exercise(it.exId)?.name ?? 'Missing exercise', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${phaseName(it.phase)} · ${it.sets} × ${it.reps}${it.rest > 0 ? ' · rest ${it.rest}s' : ''}'),
                trailing: const Icon(Icons.drag_handle),
                onTap: () => editItemSheet(context, day, it),
              ),
            ),
          ),
      ],
    );
  }
}

String phaseName(String p) => p == 'warm' ? 'Warm-up' : p == 'cool' ? 'Cool-down' : 'Workout';

PlanItem defaultItemFor(Exercise ex) {
  switch (ex.category) {
    case 'stretching':
      return PlanItem(exId: ex.id, sets: 1, reps: '30 sec', rest: 0, phase: 'cool');
    case 'cardio':
      return PlanItem(exId: ex.id, sets: 1, reps: '10 min', rest: 0);
    case 'plyometrics':
      return PlanItem(exId: ex.id, sets: 3, reps: '8-10', rest: 60);
    case 'powerlifting':
    case 'olympic weightlifting':
      return PlanItem(exId: ex.id, sets: 4, reps: '5', rest: 150);
    default:
      return PlanItem(exId: ex.id, sets: 3, reps: '10-12', rest: 60);
  }
}

/// Bottom sheet to change sets/reps/rest/phase/note of a plan item.
Future<void> editItemSheet(BuildContext context, PlanDay day, PlanItem it) async {
  final reps = TextEditingController(text: it.reps);
  final note = TextEditingController(text: it.note);
  var sets = it.sets;
  var rest = it.rest;
  var phase = it.phase;
  final ex = store.exercise(it.exId);
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(c).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(ex?.name ?? 'Exercise', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'warm', label: Text('Warm-up')),
                ButtonSegment(value: 'main', label: Text('Workout')),
                ButtonSegment(value: 'cool', label: Text('Cool-down')),
              ],
              selected: {phase},
              onSelectionChanged: (s) => set(() => phase = s.first),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Sets', style: TextStyle(fontWeight: FontWeight.w700))),
              IconButton.filledTonal(onPressed: sets > 1 ? () => set(() => sets--) : null, icon: const Icon(Icons.remove)),
              SizedBox(width: 40, child: Text('$sets', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
              IconButton.filledTonal(onPressed: sets < 12 ? () => set(() => sets++) : null, icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 12),
            TextField(controller: reps, decoration: const InputDecoration(labelText: 'Reps or time (e.g. 10-12, 30 sec, 15 min)')),
            const SizedBox(height: 16),
            Text('Rest between sets: ${rest == 0 ? 'none' : '${rest}s'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Slider(value: rest.toDouble(), min: 0, max: 240, divisions: 16, label: '${rest}s', onChanged: (v) => set(() => rest = v.round())),
            TextField(controller: note, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: 'Notes (tips, weight to use…)')),
            const SizedBox(height: 16),
            Row(children: [
              TextButton.icon(
                onPressed: () => Navigator.pop(c, 'delete'),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
              const Spacer(),
              FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Save')),
            ]),
          ]),
        ),
      ),
    ),
  );
  if (result == 'save') {
    it.sets = sets;
    it.reps = reps.text.trim().isEmpty ? it.reps : reps.text.trim();
    it.rest = rest;
    it.phase = phase;
    it.note = note.text.trim();
    store.changed();
  } else if (result == 'delete') {
    day.items.remove(it);
    store.changed();
  }
}

// ======================= Library =======================

class ExerciseLibrary extends StatefulWidget {
  /// When set, tapping an exercise picks it instead of opening details.
  final void Function(Exercise)? onPick;
  const ExerciseLibrary({super.key, this.onPick});
  @override
  State<ExerciseLibrary> createState() => _ExerciseLibraryState();
}

class _ExerciseLibraryState extends State<ExerciseLibrary> {
  String query = '';
  String muscle = 'all';
  String equipment = 'all';
  String category = 'all';
  bool mineOnly = false;

  List<Exercise> get results {
    final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return store.allExercises.where((e) {
      if (mineOnly && !e.custom) return false;
      if (muscle != 'all' && !e.primary.contains(muscle)) return false;
      if (equipment != 'all' && e.equipment != equipment) return false;
      if (category != 'all' && e.category != category) return false;
      if (words.isEmpty) return true;
      final hay = '${e.name} ${e.equipment} ${e.primary.join(' ')} ${e.category}'.toLowerCase();
      return words.every(hay.contains);
    }).toList();
  }

  Future<void> _filters() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Equipment', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in ['all', ...equipmentList])
                ChoiceChip(
                  label: Text(e == 'all' ? 'Any' : cap(e)),
                  selected: equipment == e,
                  onSelected: (_) {
                    set(() => equipment = e);
                    setState(() {});
                  },
                ),
            ]),
            const SizedBox(height: 16),
            const Text('Type', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in ['all', ...categoryList])
                ChoiceChip(
                  label: Text(e == 'all' ? 'Any' : cap(e)),
                  selected: category == e,
                  onSelected: (_) {
                    set(() => category = e);
                    setState(() {});
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final res = results;
        final cs = Theme.of(context).colorScheme;
        final filtersOn = (equipment != 'all' ? 1 : 0) + (category != 'all' ? 1 : 0);
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: widget.onPick == null ? 'newex' : 'newexpick',
            onPressed: () async {
              final e = await Navigator.push<Exercise>(context, MaterialPageRoute(builder: (_) => const CustomExerciseForm()));
              if (e != null && widget.onPick != null) widget.onPick!(e);
            },
            icon: const Icon(Icons.add),
            label: const Text('My exercise'),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search: curl, squat, cable, stretch…',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: filtersOn > 0,
                  label: Text('$filtersOn'),
                  child: IconButton.filledTonal(onPressed: _filters, icon: const Icon(Icons.tune), tooltip: 'Filters'),
                ),
              ]),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(label: const Text('My exercises'), selected: mineOnly, onSelected: (v) => setState(() => mineOnly = v)),
                  ),
                  for (final m in ['all', ...muscleList])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(m == 'all' ? 'All muscles' : cap(m)),
                        selected: muscle == m,
                        onSelected: (_) => setState(() => muscle = m),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(res.isEmpty ? 'No exercises match. Try fewer words or clear a filter.' : '${res.length} exercises',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 96),
                itemCount: res.length,
                itemBuilder: (c, i) {
                  final e = res[i];
                  return ListTile(
                    leading: ExerciseThumb(e, size: 52),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${cap(e.mainMuscle)} · ${cap(e.equipment)} · ${cap(e.level)}${e.custom ? ' · mine' : ''}'),
                    trailing: widget.onPick != null
                        ? IconButton(
                            tooltip: 'See details',
                            icon: const Icon(Icons.info_outline),
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: e))),
                          )
                        : null,
                    onTap: () {
                      if (widget.onPick != null) {
                        widget.onPick!(e);
                      } else {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: e)));
                      }
                    },
                  );
                },
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ======================= Exercise details =======================

class ExerciseDetailScreen extends StatelessWidget {
  final Exercise exercise;
  final String note;
  const ExerciseDetailScreen({super.key, required this.exercise, this.note = ''});

  Future<void> _addToPlan(BuildContext context) async {
    if (store.plans.isEmpty) return;
    var plan = store.activePlan!;
    var day = DateTime.now().weekday - 1;
    final item = defaultItemFor(exercise);
    var phase = item.phase;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add ${exercise.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            if (store.plans.length > 1) ...[
              DropdownButtonFormField<String>(
                value: plan.id,
                decoration: const InputDecoration(labelText: 'Plan'),
                items: [for (final p in store.plans) DropdownMenuItem(value: p.id, child: Text(p.name))],
                onChanged: (v) => set(() => plan = store.plans.firstWhere((p) => p.id == v)),
              ),
              const SizedBox(height: 16),
            ],
            const Text('Day', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var i = 0; i < 7; i++)
                ChoiceChip(label: Text(weekdayShort[i]), selected: day == i, onSelected: (_) => set(() => day = i)),
            ]),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'warm', label: Text('Warm-up')),
                ButtonSegment(value: 'main', label: Text('Workout')),
                ButtonSegment(value: 'cool', label: Text('Cool-down')),
              ],
              selected: {phase},
              onSelectionChanged: (s) => set(() => phase = s.first),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Add to plan')),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    item.phase = phase;
    final d = plan.days[day];
    if (d.items.isEmpty && (d.title.isEmpty || d.title == 'Rest day')) d.title = cap(exercise.mainMuscle);
    // keep warm-ups first and cool-downs last
    if (phase == 'warm') {
      final idx = d.items.indexWhere((i) => i.phase != 'warm');
      d.items.insert(idx < 0 ? d.items.length : idx, item);
    } else if (phase == 'main') {
      final idx = d.items.indexWhere((i) => i.phase == 'cool');
      d.items.insert(idx < 0 ? d.items.length : idx, item);
    } else {
      d.items.add(item);
    }
    store.changed();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${weekdayLong[day]} in ${plan.name}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final e = exercise;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(e.name),
            actions: [
              if (e.custom)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomExerciseForm(existing: e))),
                ),
              if (e.custom)
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final used = store.exerciseInUse(e.id);
                    if (await confirm(context, 'Delete ${e.name}?',
                        used ? 'It is used in a plan and will be removed from those days too.' : 'This exercise will be removed.')) {
                      for (final p in store.plans) {
                        for (final d in p.days) {
                          d.items.removeWhere((i) => i.exId == e.id);
                        }
                      }
                      store.customExercises.remove(e);
                      store.changed();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              if (e.images.isNotEmpty) PhotoDemo(e.images) else const SizedBox.shrink(),
              const SizedBox(height: 16),
              Text(e.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in [e.category, e.equipment, e.level])
                  Chip(avatar: null, label: Text(cap(t)), visualDensity: VisualDensity.compact),
              ]),
              const SizedBox(height: 16),
              const Text('MUSCLES WORKED', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
              const SizedBox(height: 8),
              MuscleChips(primary: e.primary, secondary: e.secondary),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 16),
                Card(
                  color: cs.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.tips_and_updates_outlined, color: cs.onSecondaryContainer),
                      const SizedBox(width: 10),
                      Expanded(child: Text(note, style: TextStyle(color: cs.onSecondaryContainer))),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('HOW TO DO IT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 12)),
              const SizedBox(height: 8),
              if (e.steps.isEmpty) const Text('No steps added yet.'),
              for (var i = 0; i < e.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(radius: 12, backgroundColor: cs.primary, child: Text('${i + 1}', style: TextStyle(fontSize: 12, color: cs.onPrimary, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.steps[i], style: const TextStyle(height: 1.4))),
                  ]),
                ),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE0262B), foregroundColor: Colors.white),
                  onPressed: () => openVideo(context, e.name),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Watch demo video'),
                ),
                OutlinedButton.icon(onPressed: () => _addToPlan(context), icon: const Icon(Icons.playlist_add), label: const Text('Add to plan')),
              ]),
            ],
          ),
        );
      },
    );
  }
}

// ======================= Custom exercise form =======================

class CustomExerciseForm extends StatefulWidget {
  final Exercise? existing;
  const CustomExerciseForm({super.key, this.existing});
  @override
  State<CustomExerciseForm> createState() => _CustomExerciseFormState();
}

class _CustomExerciseFormState extends State<CustomExerciseForm> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final steps = TextEditingController(text: widget.existing?.steps.join('\n') ?? '');
  late String primary = widget.existing?.mainMuscle ?? 'chest';
  late Set<String> secondary = {...?widget.existing?.secondary};
  late String equipment = widget.existing?.equipment ?? 'dumbbell';
  late String category = widget.existing?.category ?? 'strength';
  late String level = widget.existing?.level ?? 'beginner';
  late List<String> images = [...?widget.existing?.images];

  Future<void> _pickPhoto(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
          source: src, maxWidth: platform.isWeb ? 640 : 1000, imageQuality: platform.isWeb ? 70 : 80);
      if (x == null) return;
      final dest = await platform.keepPhoto(x, newId());
      if (!mounted) return;
      setState(() => images.add(dest));
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add the photo. Allow camera or photo access and try again.')));
      }
    }
  }

  void _save() {
    final n = name.text.trim();
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give the exercise a name.')));
      return;
    }
    final stepList = steps.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final e = widget.existing ?? Exercise(id: 'c_${newId()}', name: n, custom: true);
    e
      ..name = n
      ..primary = [primary]
      ..secondary = secondary.where((m) => m != primary).toList()
      ..equipment = equipment
      ..category = category
      ..level = level
      ..steps = stepList
      ..images = images;
    if (widget.existing == null) store.customExercises.insert(0, e);
    store.changed();
    Navigator.pop(context, e);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New exercise' : 'Edit exercise'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Exercise name')),
          const SizedBox(height: 16),
          const Text('Photos (first = start position, second = finish)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView(scrollDirection: Axis.horizontal, children: [
              for (final p in images)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 120, height: 96, child: AppImage(p))),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: IconButton.filled(
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => images.remove(p)),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ]),
                ),
              if (images.length < 4) ...[
                _PhotoButton(icon: Icons.photo_camera_outlined, label: 'Camera', onTap: () => _pickPhoto(ImageSource.camera)),
                const SizedBox(width: 8),
                _PhotoButton(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: () => _pickPhoto(ImageSource.gallery)),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: primary,
            decoration: const InputDecoration(labelText: 'Main muscle'),
            items: [for (final m in muscleList) DropdownMenuItem(value: m, child: Text(cap(m)))],
            onChanged: (v) => setState(() => primary = v ?? primary),
          ),
          const SizedBox(height: 12),
          const Text('Other muscles', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in muscleList.where((m) => m != primary))
              FilterChip(
                label: Text(cap(m)),
                selected: secondary.contains(m),
                onSelected: (v) => setState(() => v ? secondary.add(m) : secondary.remove(m)),
              ),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: equipment,
            decoration: const InputDecoration(labelText: 'Equipment'),
            items: [for (final m in equipmentList) DropdownMenuItem(value: m, child: Text(cap(m)))],
            onChanged: (v) => setState(() => equipment = v ?? equipment),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final m in categoryList) DropdownMenuItem(value: m, child: Text(cap(m)))],
            onChanged: (v) => setState(() => category = v ?? category),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: level,
            decoration: const InputDecoration(labelText: 'Level'),
            items: [for (final m in levelList) DropdownMenuItem(value: m, child: Text(cap(m)))],
            onChanged: (v) => setState(() => level = v ?? level),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: steps,
            minLines: 4,
            maxLines: 10,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'How to do it (one step per line)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save exercise')),
        ],
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PhotoButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(border: Border.all(color: cs.outline), borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(height: 4), Text(label)]),
      ),
    );
  }
}
