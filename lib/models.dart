// Data models for VJ Fit. Everything is stored as JSON on the phone.

int _idCounter = 0;
String newId() {
  _idCounter++;
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}$_idCounter';
}

List<String> _strList(dynamic v) =>
    v == null ? <String>[] : List<String>.from((v as List).map((e) => e.toString()));

double _d(dynamic v, [double def = 0]) => v == null ? def : (v as num).toDouble();
int _i(dynamic v, [int def = 0]) => v == null ? def : (v as num).toInt();

String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------- Exercises ----------------

class Exercise {
  final String id;
  String name;
  List<String> primary;
  List<String> secondary;
  String equipment;
  String level;
  String category;
  List<String> steps;
  List<String> images; // asset paths (assets/...) or files on the phone
  bool custom;

  Exercise({
    required this.id,
    required this.name,
    List<String>? primary,
    List<String>? secondary,
    this.equipment = 'body only',
    this.level = 'beginner',
    this.category = 'strength',
    List<String>? steps,
    List<String>? images,
    this.custom = false,
  })  : primary = primary ?? <String>[],
        secondary = secondary ?? <String>[],
        steps = steps ?? <String>[],
        images = images ?? <String>[];

  /// Built-in library format (compact keys).
  factory Exercise.fromLibrary(Map<String, dynamic> j) {
    final id = j['id'] as String;
    final count = _i(j['img']);
    return Exercise(
      id: id,
      name: j['n'] as String,
      primary: _strList(j['pm']),
      secondary: _strList(j['sm']),
      equipment: (j['eq'] ?? 'none') as String,
      level: (j['lv'] ?? 'beginner') as String,
      category: (j['cat'] ?? 'strength') as String,
      steps: _strList(j['st']),
      images: [for (var k = 0; k < count; k++) 'assets/ex/$id-$k.webp'],
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id'] as String,
        name: j['name'] as String,
        primary: _strList(j['primary']),
        secondary: _strList(j['secondary']),
        equipment: (j['equipment'] ?? 'body only') as String,
        level: (j['level'] ?? 'beginner') as String,
        category: (j['category'] ?? 'strength') as String,
        steps: _strList(j['steps']),
        images: _strList(j['images']),
        custom: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'primary': primary,
        'secondary': secondary,
        'equipment': equipment,
        'level': level,
        'category': category,
        'steps': steps,
        'images': images,
      };

  String get mainMuscle => primary.isEmpty ? 'other' : primary.first;
}

const muscleList = [
  'chest', 'shoulders', 'triceps', 'biceps', 'forearms', 'lats', 'middle back', 'traps',
  'lower back', 'abdominals', 'quadriceps', 'hamstrings', 'glutes', 'calves', 'adductors',
  'abductors', 'neck',
];
const equipmentList = [
  'barbell', 'dumbbell', 'cable', 'machine', 'body only', 'kettlebells', 'bands',
  'e-z curl bar', 'medicine ball', 'exercise ball', 'foam roll', 'other', 'none',
];
const categoryList = [
  'strength', 'stretching', 'cardio', 'plyometrics', 'powerlifting', 'olympic weightlifting',
  'strongman',
];
const levelList = ['beginner', 'intermediate', 'expert'];

// ---------------- Workout plans ----------------

class PlanItem {
  final String id;
  String exId;
  int sets;
  String reps;
  int rest; // seconds
  String phase; // warm, main, cool
  String note;

  PlanItem({
    String? id,
    required this.exId,
    this.sets = 3,
    this.reps = '10-12',
    this.rest = 60,
    this.phase = 'main',
    this.note = '',
  }) : id = id ?? newId();

  factory PlanItem.fromJson(Map<String, dynamic> j) => PlanItem(
        id: j['id'] as String?,
        exId: j['ex'] as String,
        sets: _i(j['sets'], 3),
        reps: (j['reps'] ?? '') as String,
        rest: _i(j['rest'], 60),
        phase: (j['phase'] ?? 'main') as String,
        note: (j['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'ex': exId, 'sets': sets, 'reps': reps, 'rest': rest, 'phase': phase, 'note': note};

  PlanItem copy() => PlanItem(exId: exId, sets: sets, reps: reps, rest: rest, phase: phase, note: note);
}

class PlanDay {
  String title;
  String note;
  List<PlanItem> items;
  PlanDay({this.title = 'Rest day', this.note = '', List<PlanItem>? items}) : items = items ?? <PlanItem>[];

  factory PlanDay.fromJson(Map<String, dynamic> j) => PlanDay(
        title: (j['title'] ?? '') as String,
        note: (j['note'] ?? '') as String,
        items: [for (final e in (j['items'] as List? ?? const [])) PlanItem.fromJson(e as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {'title': title, 'note': note, 'items': items.map((e) => e.toJson()).toList()};
  PlanDay copy() => PlanDay(title: title, note: note, items: items.map((e) => e.copy()).toList());
}

class WorkoutPlan {
  final String id;
  String name;
  List<PlanDay> days; // always 7, Monday first

  WorkoutPlan({String? id, required this.name, List<PlanDay>? days})
      : id = id ?? newId(),
        days = days ?? List.generate(7, (_) => PlanDay());

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) {
    final days = [for (final e in (j['days'] as List? ?? const [])) PlanDay.fromJson(e as Map<String, dynamic>)];
    while (days.length < 7) {
      days.add(PlanDay());
    }
    return WorkoutPlan(id: j['id'] as String?, name: j['name'] as String, days: days.sublist(0, 7));
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'days': days.map((e) => e.toJson()).toList()};
  WorkoutPlan copy(String newName) => WorkoutPlan(name: newName, days: days.map((d) => d.copy()).toList());
}

class SetLog {
  bool done;
  double? weight;
  int? reps;
  SetLog({this.done = false, this.weight, this.reps});
  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog(done: j['d'] == true, weight: j['w'] == null ? null : _d(j['w']), reps: j['r'] == null ? null : _i(j['r']));
  Map<String, dynamic> toJson() => {'d': done, if (weight != null) 'w': weight, if (reps != null) 'r': reps};
}

// ---------------- Diet ----------------

class Food {
  final String id;
  String name;
  String serving;
  double kcal, protein, carbs, fat;
  String category;
  bool custom;

  Food({
    required this.id,
    required this.name,
    this.serving = '1 serving',
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.category = 'My foods',
    this.custom = false,
  });

  factory Food.fromLibrary(Map<String, dynamic> j) => Food(
        id: j['id'] as String,
        name: j['n'] as String,
        serving: j['sv'] as String,
        kcal: _d(j['kcal']),
        protein: _d(j['p']),
        carbs: _d(j['c']),
        fat: _d(j['f']),
        category: j['cat'] as String,
      );

  factory Food.fromJson(Map<String, dynamic> j) => Food(
        id: j['id'] as String,
        name: j['name'] as String,
        serving: (j['serving'] ?? '1 serving') as String,
        kcal: _d(j['kcal']),
        protein: _d(j['protein']),
        carbs: _d(j['carbs']),
        fat: _d(j['fat']),
        category: (j['category'] ?? 'My foods') as String,
        custom: true,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'serving': serving, 'kcal': kcal, 'protein': protein,
        'carbs': carbs, 'fat': fat, 'category': category,
      };
}

class MealItem {
  final String id;
  String foodId;
  double qty; // number of servings
  MealItem({String? id, required this.foodId, this.qty = 1}) : id = id ?? newId();
  factory MealItem.fromJson(Map<String, dynamic> j) =>
      MealItem(id: j['id'] as String?, foodId: j['food'] as String, qty: _d(j['qty'], 1));
  Map<String, dynamic> toJson() => {'id': id, 'food': foodId, 'qty': qty};
  MealItem copy() => MealItem(foodId: foodId, qty: qty);
}

class Meal {
  String name;
  List<MealItem> items;
  Meal({required this.name, List<MealItem>? items}) : items = items ?? <MealItem>[];
  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
        name: j['name'] as String,
        items: [for (final e in (j['items'] as List? ?? const [])) MealItem.fromJson(e as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {'name': name, 'items': items.map((e) => e.toJson()).toList()};
  Meal copy() => Meal(name: name, items: items.map((e) => e.copy()).toList());
}

class DietPlan {
  final String id;
  String name;
  String note;
  List<Meal> meals;
  DietPlan({String? id, required this.name, this.note = '', List<Meal>? meals})
      : id = id ?? newId(),
        meals = meals ?? <Meal>[];
  factory DietPlan.fromJson(Map<String, dynamic> j) => DietPlan(
        id: j['id'] as String?,
        name: j['name'] as String,
        note: (j['note'] ?? '') as String,
        meals: [for (final e in (j['meals'] as List? ?? const [])) Meal.fromJson(e as Map<String, dynamic>)],
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'note': note, 'meals': meals.map((e) => e.toJson()).toList()};
  DietPlan copy(String newName) => DietPlan(name: newName, note: note, meals: meals.map((m) => m.copy()).toList());
}

class Macros {
  double kcal = 0, protein = 0, carbs = 0, fat = 0;
  void add(Food f, double qty) {
    kcal += f.kcal * qty;
    protein += f.protein * qty;
    carbs += f.carbs * qty;
    fat += f.fat * qty;
  }
}

/// Foods eaten outside the plan on a given day.
class ExtraFood {
  final String id;
  String foodId;
  double qty;
  String meal;
  ExtraFood({String? id, required this.foodId, this.qty = 1, this.meal = 'Extra'}) : id = id ?? newId();
  factory ExtraFood.fromJson(Map<String, dynamic> j) =>
      ExtraFood(id: j['id'] as String?, foodId: j['food'] as String, qty: _d(j['qty'], 1), meal: (j['meal'] ?? 'Extra') as String);
  Map<String, dynamic> toJson() => {'id': id, 'food': foodId, 'qty': qty, 'meal': meal};
}

class DietDay {
  Set<String> eaten; // MealItem ids ticked off
  List<ExtraFood> extras;
  int water; // glasses
  DietDay({Set<String>? eaten, List<ExtraFood>? extras, this.water = 0})
      : eaten = eaten ?? <String>{},
        extras = extras ?? <ExtraFood>[];
  factory DietDay.fromJson(Map<String, dynamic> j) => DietDay(
        eaten: Set<String>.from(_strList(j['eaten'])),
        extras: [for (final e in (j['extras'] as List? ?? const [])) ExtraFood.fromJson(e as Map<String, dynamic>)],
        water: _i(j['water']),
      );
  Map<String, dynamic> toJson() =>
      {'eaten': eaten.toList(), 'extras': extras.map((e) => e.toJson()).toList(), 'water': water};
}

// ---------------- Profile ----------------

class Profile {
  String name;
  String sex; // m / f
  int age;
  double heightCm;
  double weightKg;
  double activity; // multiplier
  String goal; // lose / maintain / gain

  Profile({
    this.name = '',
    this.sex = 'm',
    this.age = 25,
    this.heightCm = 170,
    this.weightKg = 70,
    this.activity = 1.55,
    this.goal = 'gain',
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        name: (j['name'] ?? '') as String,
        sex: (j['sex'] ?? 'm') as String,
        age: _i(j['age'], 25),
        heightCm: _d(j['height'], 170),
        weightKg: _d(j['weight'], 70),
        activity: _d(j['activity'], 1.55),
        goal: (j['goal'] ?? 'gain') as String,
      );
  Map<String, dynamic> toJson() => {
        'name': name, 'sex': sex, 'age': age, 'height': heightCm, 'weight': weightKg,
        'activity': activity, 'goal': goal,
      };

  /// Mifflin-St Jeor resting energy.
  double get bmr => 10 * weightKg + 6.25 * heightCm - 5 * age + (sex == 'f' ? -161 : 5);
  double get maintenance => bmr * activity;
  double get targetKcal => maintenance + (goal == 'lose' ? -450 : goal == 'gain' ? 300 : 0);
  double get targetProtein => weightKg * (goal == 'maintain' ? 1.4 : 1.8);
  double get targetFat => targetKcal * 0.25 / 9;
  double get targetCarbs {
    final c = (targetKcal - targetProtein * 4 - targetFat * 9) / 4;
    return c < 0 ? 0 : c;
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
}

final activityLevels = <double, String>{
  1.2: 'Little or no exercise',
  1.375: 'Light (1-3 days a week)',
  1.55: 'Moderate (3-5 days a week)',
  1.725: 'Hard (6-7 days a week)',
  1.9: 'Very hard (training twice a day)',
};
const goals = <String, String>{
  'lose': 'Lose fat',
  'maintain': 'Maintain',
  'gain': 'Build muscle',
};
