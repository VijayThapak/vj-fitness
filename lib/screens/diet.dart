import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets.dart';

class DietScreen extends StatelessWidget {
  const DietScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diet', style: TextStyle(fontWeight: FontWeight.w900)),
          bottom: const TabBar(tabs: [Tab(text: 'Today'), Tab(text: 'Diet plans'), Tab(text: 'Foods')]),
        ),
        body: const TabBarView(children: [DietTodayTab(), DietPlansTab(), FoodList()]),
      ),
    );
  }
}

String kcalText(double v) => '${fmtNum(v)} kcal';

/// Ask how many servings. Returns null if cancelled.
Future<double?> askQty(BuildContext context, Food f, {double initial = 1, String action = 'Save'}) async {
  var q = initial;
  final ctrl = TextEditingController(text: fmtQty(q));
  return showDialog<double>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        void setQ(double v) {
          q = v < 0.25 ? 0.25 : v;
          ctrl.text = fmtQty(q);
          set(() {});
        }

        return AlertDialog(
          title: Text(f.name),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('1 serving = ${f.serving}'),
            const SizedBox(height: 12),
            Row(children: [
              IconButton.filledTonal(onPressed: () => setQ(q - 0.5), icon: const Icon(Icons.remove)),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Servings'),
                  onChanged: (v) {
                    final n = parseNum(v);
                    if (n != null && n > 0) set(() => q = n);
                  },
                ),
              ),
              IconButton.filledTonal(onPressed: () => setQ(q + 0.5), icon: const Icon(Icons.add)),
            ]),
            const SizedBox(height: 12),
            Text('${kcalText(f.kcal * q)} · P ${fmtNum(f.protein * q)}g · C ${fmtNum(f.carbs * q)}g · F ${fmtNum(f.fat * q)}g',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, q), child: Text(action)),
          ],
        );
      },
    ),
  );
}

Future<Food?> pickFood(BuildContext context) => Navigator.push<Food>(
      context,
      MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Pick a food')), body: FoodList(onPick: (f) => Navigator.pop(context, f)))),
    );

// ======================= Today =======================

class DietTodayTab extends StatefulWidget {
  const DietTodayTab({super.key});
  @override
  State<DietTodayTab> createState() => _DietTodayTabState();
}

class _DietTodayTabState extends State<DietTodayTab> {
  DateTime date = DateTime.now();

  bool get isToday => dateKey(date) == dateKey(DateTime.now());

  Future<void> _addExtra(List<String> mealNames) async {
    final f = await pickFood(context);
    if (f == null || !mounted) return;
    final q = await askQty(context, f, action: 'Add');
    if (q == null || !mounted) return;
    var meal = 'Extra';
    if (mealNames.isNotEmpty) {
      final m = await showDialog<String>(
        context: context,
        builder: (c) => SimpleDialog(
          title: const Text('Which meal?'),
          children: [for (final n in [...mealNames, 'Extra']) SimpleDialogOption(onPressed: () => Navigator.pop(c, n), child: Text(n))],
        ),
      );
      if (m == null) return;
      meal = m;
    }
    store.dietDay(dateKey(date)).extras.add(ExtraFood(foodId: f.id, qty: q, meal: meal));
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final key = dateKey(date);
        final day = store.dietDay(key);
        final plan = store.activeDiet;
        final eaten = store.eatenTotals(key);
        final p = store.profile;
        final cs = Theme.of(context).colorScheme;
        final mealNames = plan?.meals.map((m) => m.name).toList() ?? <String>[];
        final extrasOnly = day.extras.where((e) => !mealNames.contains(e.meal)).toList();
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addfood',
            onPressed: () => _addExtra(mealNames),
            icon: const Icon(Icons.add),
            label: const Text('Add food'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Row(children: [
                IconButton(onPressed: () => setState(() => date = date.subtract(const Duration(days: 1))), icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(
                    isToday ? 'Today' : '${weekdayLong[date.weekday - 1]}, ${date.day}/${date.month}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                IconButton(
                  onPressed: isToday ? null : () => setState(() => date = date.add(const Duration(days: 1))),
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      Row(children: [
                        SizedBox(
                          width: 92,
                          height: 92,
                          child: Stack(fit: StackFit.expand, children: [
                            CircularProgressIndicator(
                              value: p.targetKcal <= 0 ? 0 : (eaten.kcal / p.targetKcal).clamp(0.0, 1.0),
                              strokeWidth: 9,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                            Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(fmtNum(eaten.kcal), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                                Text('of ${fmtNum(p.targetKcal)}', style: const TextStyle(fontSize: 11)),
                              ]),
                            ),
                          ]),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(children: [
                            _MacroBar('Protein', eaten.protein, p.targetProtein, const Color(0xFF2E8B57)),
                            _MacroBar('Carbs', eaten.carbs, p.targetCarbs, const Color(0xFFE8A20A)),
                            _MacroBar('Fat', eaten.fat, p.targetFat, const Color(0xFFD7263D)),
                          ]),
                        ),
                      ]),
                      if (!store.profileSet)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text('Targets are estimates. Add your age, height and weight in the Me tab for your own numbers.',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ),
                      const Divider(height: 24),
                      Row(children: [
                        Icon(Icons.water_drop_outlined, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Water: ${day.water} of 10 glasses', style: const TextStyle(fontWeight: FontWeight.w700))),
                        IconButton(
                          onPressed: day.water > 0
                              ? () {
                                  day.water--;
                                  store.changed();
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: () {
                            day.water++;
                            store.changed();
                          },
                          icon: const Icon(Icons.add_circle),
                          color: cs.primary,
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
              if (plan == null)
                const Padding(padding: EdgeInsets.all(24), child: Text('Create a diet plan in the Diet plans tab.'))
              else ...[
                SectionTitle(plan.name,
                    trailing: TextButton(
                      onPressed: () => DefaultTabController.of(context).animateTo(1),
                      child: const Text('Change'),
                    )),
                for (var mi = 0; mi < plan.meals.length; mi++) _mealCard(plan.meals[mi], day),
              ],
              if (extrasOnly.isNotEmpty) ...[
                const SectionTitle('Extra food'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(child: Column(children: [for (final e in extrasOnly) _extraTile(e, day)])),
                ),
              ],
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text('Tick foods as you eat them. Calories and macros are approximate home-cooked values.', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _extraTile(ExtraFood e, DietDay day) {
    final f = store.food(e.foodId);
    return ListTile(
      leading: const Icon(Icons.add_task),
      title: Text(f?.name ?? 'Missing food'),
      subtitle: Text('${fmtQty(e.qty)} × ${f?.serving ?? ''}'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(kcalText((f?.kcal ?? 0) * e.qty)),
        IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close),
          onPressed: () {
            day.extras.remove(e);
            store.changed();
          },
        ),
      ]),
    );
  }

  Widget _mealCard(Meal meal, DietDay day) {
    final cs = Theme.of(context).colorScheme;
    final total = Macros();
    for (final it in meal.items) {
      final f = store.food(it.foodId);
      if (f != null) total.add(f, it.qty);
    }
    final allEaten = meal.items.isNotEmpty && meal.items.every((i) => day.eaten.contains(i.id));
    final extras = day.extras.where((e) => e.meal == meal.name).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 0),
            child: Row(children: [
              Expanded(child: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              Text(kcalText(total.kcal), style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: meal.items.isEmpty
                    ? null
                    : () {
                        for (final i in meal.items) {
                          allEaten ? day.eaten.remove(i.id) : day.eaten.add(i.id);
                        }
                        store.changed();
                      },
                child: Text(allEaten ? 'Undo' : 'Ate all'),
              ),
            ]),
          ),
          for (final it in meal.items)
            Builder(builder: (c) {
              final f = store.food(it.foodId);
              final on = day.eaten.contains(it.id);
              return CheckboxListTile(
                value: on,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(f?.name ?? 'Missing food', style: TextStyle(decoration: on ? TextDecoration.lineThrough : null)),
                subtitle: Text('${fmtQty(it.qty)} × ${f?.serving ?? ''}'),
                secondary: Text(kcalText((f?.kcal ?? 0) * it.qty)),
                onChanged: (v) {
                  v == true ? day.eaten.add(it.id) : day.eaten.remove(it.id);
                  store.changed();
                },
              );
            }),
          for (final e in extras) _extraTile(e, day),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  final String label;
  final double value, target;
  final Color color;
  const _MacroBar(this.label, this.value, this.target, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
          Text('${fmtNum(value)} / ${fmtNum(target)} g', style: const TextStyle(fontSize: 12)),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: target <= 0 ? 0 : (value / target).clamp(0.0, 1.0),
            minHeight: 6,
            color: color,
            backgroundColor: color.withAlpha(40),
          ),
        ),
      ]),
    );
  }
}

// ======================= Diet plans =======================

class DietPlansTab extends StatelessWidget {
  const DietPlansTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final target = store.profile.targetKcal;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'newdiet',
            onPressed: () async {
              final n = await askText(context, 'New diet plan', label: 'Plan name');
              if (n == null) return;
              final d = DietPlan(name: n, meals: [
                for (final m in const ['Breakfast', 'Mid-morning', 'Lunch', 'Evening snack', 'Dinner']) Meal(name: m),
              ]);
              store.dietPlans.add(d);
              store.changed();
              if (context.mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => DietPlanEditor(plan: d)));
            },
            icon: const Icon(Icons.add),
            label: const Text('New diet'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Text('Your daily target is about ${kcalText(target)} and ${fmtNum(store.profile.targetProtein)} g protein. The active plan shows on the Today tab.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final d in store.dietPlans) ...[
                _DietCard(plan: d),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DietCard extends StatelessWidget {
  final DietPlan plan;
  const _DietCard({required this.plan});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = store.activeDiet?.id == plan.id;
    final t = store.planTotals(plan);
    final diff = t.kcal - store.profile.targetKcal;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? cs.primary : cs.outlineVariant, width: active ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DietPlanEditor(plan: plan))),
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
                if (plan.note.isNotEmpty) Text(plan.note, style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('${kcalText(t.kcal)} · P ${fmtNum(t.protein)}g · C ${fmtNum(t.carbs)}g · F ${fmtNum(t.fat)}g',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  diff.abs() < 150
                      ? 'Close to your target'
                      : diff > 0
                          ? '${fmtNum(diff)} kcal above your target'
                          : '${fmtNum(-diff)} kcal below your target',
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'active') {
                  store.activeDietId = plan.id;
                  store.changed();
                } else if (v == 'rename') {
                  final n = await askText(context, 'Rename diet', initial: plan.name, label: 'Plan name');
                  if (n != null) {
                    plan.name = n;
                    store.changed();
                  }
                } else if (v == 'copy') {
                  store.dietPlans.add(plan.copy('${plan.name} (copy)'));
                  store.changed();
                } else if (v == 'delete') {
                  if (store.dietPlans.length == 1) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need at least one diet plan. Create another first.')));
                    return;
                  }
                  if (await confirm(context, 'Delete "${plan.name}"?', 'This removes the diet plan.')) {
                    store.dietPlans.remove(plan);
                    if (store.activeDietId == plan.id) store.activeDietId = store.dietPlans.first.id;
                    store.changed();
                  }
                }
              },
              itemBuilder: (_) => [
                if (!active) const PopupMenuItem(value: 'active', child: Text('Use this diet')),
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

class DietPlanEditor extends StatelessWidget {
  final DietPlan plan;
  const DietPlanEditor({super.key, required this.plan});

  Future<void> _addFood(BuildContext context, Meal meal) async {
    final f = await pickFood(context);
    if (f == null || !context.mounted) return;
    final q = await askQty(context, f, action: 'Add');
    if (q == null) return;
    meal.items.add(MealItem(foodId: f.id, qty: q));
    store.changed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final t = store.planTotals(plan);
        final p = store.profile;
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: Text(plan.name),
            actions: [
              IconButton(
                tooltip: 'Rename and notes',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () async {
                  final n = await askText(context, 'Rename diet', initial: plan.name, label: 'Plan name');
                  if (n != null) plan.name = n;
                  if (!context.mounted) return;
                  final note = await askText(context, 'Notes', initial: plan.note, label: 'Short description');
                  plan.note = note ?? plan.note;
                  store.changed();
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addmeal',
            onPressed: () async {
              final n = await askText(context, 'New meal', label: 'For example: Pre-workout');
              if (n == null) return;
              plan.meals.add(Meal(name: n));
              store.changed();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add meal'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily total: ${kcalText(t.kcal)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: cs.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text('Protein ${fmtNum(t.protein)} g · Carbs ${fmtNum(t.carbs)} g · Fat ${fmtNum(t.fat)} g',
                        style: TextStyle(color: cs.onPrimaryContainer)),
                    const SizedBox(height: 4),
                    Text('Your target: ${kcalText(p.targetKcal)} · protein ${fmtNum(p.targetProtein)} g',
                        style: TextStyle(color: cs.onPrimaryContainer, fontSize: 12)),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              for (var mi = 0; mi < plan.meals.length; mi++) ...[
                _mealEditor(context, plan.meals[mi], mi),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _mealEditor(BuildContext context, Meal meal, int index) {
    final total = Macros();
    for (final it in meal.items) {
      final f = store.food(it.foodId);
      if (f != null) total.add(f, it.qty);
    }
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
          child: Row(children: [
            Expanded(child: Text(meal.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(kcalText(total.kcal)),
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'rename') {
                  final n = await askText(context, 'Rename meal', initial: meal.name);
                  if (n != null) {
                    meal.name = n;
                    store.changed();
                  }
                } else if (v == 'up' && index > 0) {
                  plan.meals.insert(index - 1, plan.meals.removeAt(index));
                  store.changed();
                } else if (v == 'down' && index < plan.meals.length - 1) {
                  plan.meals.insert(index + 1, plan.meals.removeAt(index));
                  store.changed();
                } else if (v == 'delete') {
                  if (await confirm(context, 'Delete ${meal.name}?', 'All foods in this meal will be removed.')) {
                    plan.meals.remove(meal);
                    store.changed();
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                if (index < plan.meals.length - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                const PopupMenuItem(value: 'delete', child: Text('Delete meal')),
              ],
            ),
          ]),
        ),
        for (final it in meal.items)
          Builder(builder: (c) {
            final f = store.food(it.foodId);
            return ListTile(
              dense: true,
              title: Text(f?.name ?? 'Missing food'),
              subtitle: Text('${fmtQty(it.qty)} × ${f?.serving ?? ''}  ·  P ${fmtNum((f?.protein ?? 0) * it.qty)}g'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(kcalText((f?.kcal ?? 0) * it.qty)),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    meal.items.remove(it);
                    store.changed();
                  },
                ),
              ]),
              onTap: f == null
                  ? null
                  : () async {
                      final q = await askQty(context, f, initial: it.qty);
                      if (q != null) {
                        it.qty = q;
                        store.changed();
                      }
                    },
            );
          }),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: TextButton.icon(onPressed: () => _addFood(context, meal), icon: const Icon(Icons.add), label: const Text('Add food')),
          ),
        ),
      ]),
    );
  }
}

// ======================= Foods =======================

class FoodList extends StatefulWidget {
  final void Function(Food)? onPick;
  const FoodList({super.key, this.onPick});
  @override
  State<FoodList> createState() => _FoodListState();
}

class _FoodListState extends State<FoodList> {
  String query = '';
  String cat = 'All';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cats = <String>['All'];
        for (final f in store.allFoods) {
          if (!cats.contains(f.category)) cats.add(f.category);
        }
        final words = query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        final res = store.allFoods.where((f) {
          if (cat != 'All' && f.category != cat) return false;
          final hay = '${f.name} ${f.category}'.toLowerCase();
          return words.every(hay.contains);
        }).toList();
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: widget.onPick == null ? 'newfood' : 'newfoodpick',
            onPressed: () async {
              final f = await Navigator.push<Food>(context, MaterialPageRoute(builder: (_) => const FoodForm()));
              if (f != null && widget.onPick != null) widget.onPick!(f);
            },
            icon: const Icon(Icons.add),
            label: const Text('My food'),
          ),
          body: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search: paneer, dal, roti…', isDense: true),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: res.isEmpty
                  ? const Center(child: Text('No foods match. Add it with "My food".'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: res.length,
                      itemBuilder: (c, i) {
                        final f = res[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: f.custom ? cs.tertiaryContainer : cs.secondaryContainer,
                            child: Text(f.name[0].toUpperCase()),
                          ),
                          title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text('${f.serving} · P ${fmtNum(f.protein, 1)}g C ${fmtNum(f.carbs, 1)}g F ${fmtNum(f.fat, 1)}g${f.custom ? ' · mine' : ''}'),
                          trailing: Text(kcalText(f.kcal), style: const TextStyle(fontWeight: FontWeight.w700)),
                          onTap: () {
                            if (widget.onPick != null) {
                              widget.onPick!(f);
                            } else if (f.custom) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => FoodForm(existing: f)));
                            } else {
                              _showFood(context, f);
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

  void _showFood(BuildContext context, Food f) {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(f.name),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Serving: ${f.serving}'),
          const SizedBox(height: 8),
          Text('Calories: ${kcalText(f.kcal)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('Protein: ${fmtNum(f.protein, 1)} g'),
          Text('Carbs: ${fmtNum(f.carbs, 1)} g'),
          Text('Fat: ${fmtNum(f.fat, 1)} g'),
          const SizedBox(height: 8),
          const Text('Approximate values for a home-cooked serving.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              final copy = Food(
                id: 'f_${newId()}',
                name: '${f.name} (my version)',
                serving: f.serving,
                kcal: f.kcal,
                protein: f.protein,
                carbs: f.carbs,
                fat: f.fat,
                category: f.category,
                custom: true,
              );
              Navigator.push(context, MaterialPageRoute(builder: (_) => FoodForm(existing: copy, isNew: true)));
            },
            child: const Text('Make my version'),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }
}

class FoodForm extends StatefulWidget {
  final Food? existing;
  final bool isNew;
  const FoodForm({super.key, this.existing, this.isNew = false});
  @override
  State<FoodForm> createState() => _FoodFormState();
}

class _FoodFormState extends State<FoodForm> {
  late final name = TextEditingController(text: widget.existing?.name ?? '');
  late final serving = TextEditingController(text: widget.existing?.serving ?? '1 katori (150 g)');
  late final p = TextEditingController(text: widget.existing == null ? '' : fmtNum(widget.existing!.protein, 1));
  late final c = TextEditingController(text: widget.existing == null ? '' : fmtNum(widget.existing!.carbs, 1));
  late final f = TextEditingController(text: widget.existing == null ? '' : fmtNum(widget.existing!.fat, 1));
  late final kcal = TextEditingController(text: widget.existing == null ? '' : fmtNum(widget.existing!.kcal));
  late String category = widget.existing?.category ?? 'My foods';
  bool kcalEdited = false;

  bool get editing => widget.existing != null && !widget.isNew;

  void _autoKcal() {
    if (kcalEdited) return;
    final v = (parseNum(p.text) ?? 0) * 4 + (parseNum(c.text) ?? 0) * 4 + (parseNum(f.text) ?? 0) * 9;
    kcal.text = v == 0 ? '' : fmtNum(v);
  }

  void _save() {
    final n = name.text.trim();
    final k = parseNum(kcal.text);
    if (n.isEmpty || k == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a name and the calories per serving.')));
      return;
    }
    final food = widget.existing ?? Food(id: 'f_${newId()}', name: n, custom: true);
    food
      ..name = n
      ..serving = serving.text.trim().isEmpty ? '1 serving' : serving.text.trim()
      ..kcal = k
      ..protein = parseNum(p.text) ?? 0
      ..carbs = parseNum(c.text) ?? 0
      ..fat = parseNum(f.text) ?? 0
      ..category = category
      ..custom = true;
    if (!editing) store.customFoods.insert(0, food);
    store.changed();
    Navigator.pop(context, food);
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>{'My foods', ...store.libraryFoods.map((e) => e.category)}.toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit food' : 'New food'),
        actions: [
          if (editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final fd = widget.existing!;
                final used = store.foodInUse(fd.id);
                if (await confirm(context, 'Delete ${fd.name}?', used ? 'It will also be removed from your diet plans.' : 'This food will be removed.')) {
                  for (final d in store.dietPlans) {
                    for (final m in d.meals) {
                      m.items.removeWhere((i) => i.foodId == fd.id);
                    }
                  }
                  store.customFoods.remove(fd);
                  store.changed();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Food name')),
          const SizedBox(height: 12),
          TextField(controller: serving, decoration: const InputDecoration(labelText: 'Serving size (e.g. 1 bowl, 100 g)')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: cats.contains(category) ? category : 'My foods',
            decoration: const InputDecoration(labelText: 'Category'),
            items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
            onChanged: (v) => setState(() => category = v ?? category),
          ),
          const SizedBox(height: 16),
          const Text('Per serving', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _num(p, 'Protein (g)')),
            const SizedBox(width: 8),
            Expanded(child: _num(c, 'Carbs (g)')),
            const SizedBox(width: 8),
            Expanded(child: _num(f, 'Fat (g)')),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: kcal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Calories (kcal)', helperText: 'Filled in from protein, carbs and fat. You can change it.'),
            onChanged: (_) => kcalEdited = true,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save food')),
        ],
      ),
    );
  }

  Widget _num(TextEditingController ctrl, String label) => TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(_autoKcal),
      );
}
