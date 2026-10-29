import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';


import 'models.dart';
import 'platform/platform.dart' as platform;

/// Holds all app data and saves it to a JSON file on the phone.
class Store extends ChangeNotifier {
  bool ready = false;

  // Built-in data (from assets, never saved)
  List<Exercise> libraryExercises = [];
  List<Food> libraryFoods = [];

  // User data (saved)
  List<Exercise> customExercises = [];
  List<Food> customFoods = [];
  List<WorkoutPlan> plans = [];
  String activePlanId = '';
  List<DietPlan> dietPlans = [];
  String activeDietId = '';
  Profile profile = Profile();
  bool profileSet = false;
  Map<String, Map<String, List<SetLog>>> workoutLog = {}; // date -> planItemId -> sets
  Map<String, DietDay> dietLog = {}; // date -> day

  final Map<String, Exercise> _exMap = {};
  final Map<String, Food> _foodMap = {};
  Timer? _saveTimer;
  bool _canSave = false;

  /// Set when the last save failed (for example browser storage is full).
  String? saveError;

  Future<void> load() async {
    final exJson = jsonDecode(await rootBundle.loadString('assets/data/exercises.json')) as List;
    libraryExercises = [for (final e in exJson) Exercise.fromLibrary(e as Map<String, dynamic>)];
    final foodJson = jsonDecode(await rootBundle.loadString('assets/data/foods.json')) as List;
    libraryFoods = [for (final e in foodJson) Food.fromLibrary(e as Map<String, dynamic>)];

    var loaded = false;
    try {
      final saved = await platform.loadData();
      if (saved != null) {
        _apply(jsonDecode(saved) as Map<String, dynamic>);
        loaded = true;
      }
    } catch (e) {
      debugPrint('Could not read saved data: $e');
    }
    _canSave = true;
    if (!loaded || plans.isEmpty) {
      final p = jsonDecode(await rootBundle.loadString('assets/data/plans.json')) as List;
      plans = [for (final e in p) WorkoutPlan.fromJson(e as Map<String, dynamic>)];
      activePlanId = plans.first.id;
    }
    if (!loaded || dietPlans.isEmpty) {
      final d = jsonDecode(await rootBundle.loadString('assets/data/diets.json')) as List;
      dietPlans = [for (final e in d) DietPlan.fromJson(e as Map<String, dynamic>)];
      activeDietId = dietPlans.first.id;
    }
    _reindex();
    ready = true;
    notifyListeners();
  }

  void _apply(Map<String, dynamic> j) {
    customExercises = [for (final e in (j['customExercises'] as List? ?? const [])) Exercise.fromJson(e as Map<String, dynamic>)];
    customFoods = [for (final e in (j['customFoods'] as List? ?? const [])) Food.fromJson(e as Map<String, dynamic>)];
    plans = [for (final e in (j['plans'] as List? ?? const [])) WorkoutPlan.fromJson(e as Map<String, dynamic>)];
    activePlanId = (j['activePlanId'] ?? '') as String;
    dietPlans = [for (final e in (j['dietPlans'] as List? ?? const [])) DietPlan.fromJson(e as Map<String, dynamic>)];
    activeDietId = (j['activeDietId'] ?? '') as String;
    if (j['profile'] != null) {
      profile = Profile.fromJson(j['profile'] as Map<String, dynamic>);
      profileSet = j['profileSet'] == true;
    }
    workoutLog = {};
    final wl = j['workoutLog'] as Map<String, dynamic>? ?? const {};
    wl.forEach((date, v) {
      final m = <String, List<SetLog>>{};
      (v as Map<String, dynamic>).forEach((k, sets) {
        m[k] = [for (final s in sets as List) SetLog.fromJson(s as Map<String, dynamic>)];
      });
      workoutLog[date] = m;
    });
    dietLog = {};
    final dl = j['dietLog'] as Map<String, dynamic>? ?? const {};
    dl.forEach((date, v) => dietLog[date] = DietDay.fromJson(v as Map<String, dynamic>));
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'customExercises': customExercises.map((e) => e.toJson()).toList(),
        'customFoods': customFoods.map((e) => e.toJson()).toList(),
        'plans': plans.map((e) => e.toJson()).toList(),
        'activePlanId': activePlanId,
        'dietPlans': dietPlans.map((e) => e.toJson()).toList(),
        'activeDietId': activeDietId,
        'profile': profile.toJson(),
        'profileSet': profileSet,
        'workoutLog': workoutLog.map((d, m) => MapEntry(d, m.map((k, v) => MapEntry(k, v.map((s) => s.toJson()).toList())))),
        'dietLog': dietLog.map((d, v) => MapEntry(d, v.toJson())),
      };

  void _reindex() {
    _exMap
      ..clear()
      ..addEntries(libraryExercises.map((e) => MapEntry(e.id, e)))
      ..addEntries(customExercises.map((e) => MapEntry(e.id, e)));
    _foodMap
      ..clear()
      ..addEntries(libraryFoods.map((e) => MapEntry(e.id, e)))
      ..addEntries(customFoods.map((e) => MapEntry(e.id, e)));
  }

  /// Call after any change. Saves shortly after, so rapid taps write once.
  void changed() {
    _reindex();
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), saveNow);
  }

  Future<void> saveNow() async {
    if (!_canSave) return;
    final hadError = saveError != null;
    try {
      await platform.saveData(jsonEncode(toJson()));
      saveError = null;
    } catch (e) {
      debugPrint('Save failed: $e');
      saveError = platform.isWeb
          ? 'Your latest changes could not be saved. Browser storage may be full or blocked. Back up your data from the Me tab.'
          : 'Your latest changes could not be saved. Check that your phone has free space.';
    }
    if (hadError != (saveError != null)) notifyListeners();
  }

  String exportBackup() => const JsonEncoder.withIndent(' ').convert(toJson());

  /// Replaces all user data with a backup. Throws FormatException if the file is not a VJ Fit backup.
  void importBackup(String text) {
    final j = jsonDecode(text);
    if (j is! Map<String, dynamic> || j['plans'] == null) {
      throw const FormatException('This file is not a VJ Fit backup.');
    }
    _apply(j);
    if (plans.isEmpty) plans = [WorkoutPlan(name: 'My plan')];
    if (activePlan == null) activePlanId = plans.first.id;
    changed();
  }

  // ---------- lookups ----------
  List<Exercise> get allExercises => [...customExercises, ...libraryExercises];
  List<Food> get allFoods => [...customFoods, ...libraryFoods];
  Exercise? exercise(String id) => _exMap[id];
  Food? food(String id) => _foodMap[id];

  WorkoutPlan? get activePlan {
    for (final p in plans) {
      if (p.id == activePlanId) return p;
    }
    return plans.isEmpty ? null : plans.first;
  }

  DietPlan? get activeDiet {
    for (final p in dietPlans) {
      if (p.id == activeDietId) return p;
    }
    return dietPlans.isEmpty ? null : dietPlans.first;
  }

  // ---------- workout log ----------
  List<SetLog> setsFor(String date, PlanItem item) {
    final day = workoutLog.putIfAbsent(date, () => {});
    final list = day.putIfAbsent(item.id, () => []);
    while (list.length < item.sets) {
      list.add(SetLog());
    }
    return list;
  }

  bool itemDone(String date, PlanItem item) {
    final list = workoutLog[date]?[item.id];
    if (list == null || list.length < item.sets) return false;
    for (var i = 0; i < item.sets; i++) {
      if (!list[i].done) return false;
    }
    return true;
  }

  (int done, int total) dayProgress(String date, PlanDay day) {
    var done = 0, total = 0;
    for (final it in day.items) {
      total += it.sets;
      final list = workoutLog[date]?[it.id];
      if (list != null) {
        for (var i = 0; i < it.sets && i < list.length; i++) {
          if (list[i].done) done++;
        }
      }
    }
    return (done, total);
  }

  /// Last weight/reps logged for an exercise before [date], for "last time" hints.
  SetLog? lastLogFor(String exId, String beforeDate) {
    final ids = <String>{};
    for (final p in plans) {
      for (final d in p.days) {
        for (final it in d.items) {
          if (it.exId == exId) ids.add(it.id);
        }
      }
    }
    final dates = workoutLog.keys.where((d) => d.compareTo(beforeDate) < 0).toList()..sort();
    for (final d in dates.reversed) {
      for (final id in ids) {
        final sets = workoutLog[d]![id];
        if (sets == null) continue;
        for (final s in sets.reversed) {
          if (s.done && (s.weight != null || s.reps != null)) return s;
        }
      }
    }
    return null;
  }

  // ---------- diet log ----------
  DietDay dietDay(String date) => dietLog.putIfAbsent(date, () => DietDay());

  Macros planTotals(DietPlan plan) {
    final m = Macros();
    for (final meal in plan.meals) {
      for (final it in meal.items) {
        final f = food(it.foodId);
        if (f != null) m.add(f, it.qty);
      }
    }
    return m;
  }

  Macros eatenTotals(String date) {
    final m = Macros();
    final day = dietLog[date];
    if (day == null) return m;
    final plan = activeDiet;
    if (plan != null) {
      for (final meal in plan.meals) {
        for (final it in meal.items) {
          if (!day.eaten.contains(it.id)) continue;
          final f = food(it.foodId);
          if (f != null) m.add(f, it.qty);
        }
      }
    }
    for (final e in day.extras) {
      final f = food(e.foodId);
      if (f != null) m.add(f, e.qty);
    }
    return m;
  }

  /// Is this exercise used in any plan? (so we warn before deleting)
  bool exerciseInUse(String exId) =>
      plans.any((p) => p.days.any((d) => d.items.any((i) => i.exId == exId)));
  bool foodInUse(String foodId) =>
      dietPlans.any((p) => p.meals.any((m) => m.items.any((i) => i.foodId == foodId)));
}

final store = Store();
