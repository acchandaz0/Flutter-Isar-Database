This project is forked from [flow](https://github.com/flow-mn/flow), a personal finance expense tracker built with flutter. It previously used ObjectBox as its main database, providing local and offline access to storage.  

I have changed it from using ObjectBox to Isar, a high performance, cross-platform NoSQL database that features ACID compliance, full-text search, and static typing.

A project setup consists of:
### 1. Migrating dependencies
Run these commands to add a few packages to `pubspec.yaml`
```
flutter pub remove objectbox objectbox_flutter_libs:any
flutter pub remove --dev objectbox_generator:any

flutter pub add isar isar_flutter_libs path_provider
flutter pub add -d isar_generator build_runner

flutter clean
flutter pub get
```
---
### 2. Model Conversion  
Do this to make sure that Isar knows which entity to configure. You can do so by changing the `@Entity` tag into the `@collection` tag to a class and choosing an `Id` field. For example:
#### *Original Expense Model* (lib/entity/profile.dart)
```dart
@Entity()
@JsonSerializable(explicitToJson: true, converters: [UTCDateTimeConverter()])
class Profile implements EntityBase {
  @JsonKey(includeFromJson: false, includeToJson: false)
  int id;

  @override
  @Unique()
  String uuid;

  static const int maxNameLength = 96;

  String name;

  @Property(type: PropertyType.date)
  DateTime createdDate;

  @Transient()
  String get imagePath => "$uuid.png";

  Profile({this.id = 0, DateTime? createdDate, required this.name})
    : createdDate = createdDate ?? DateTime.now(),
      uuid = const Uuid().v4();

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  static void createDefaultProfile() {
    ObjectBox().box<Profile>().put(Profile(name: "Default Profile"));
  }
}
```

#### *Convert to Isar*:
```dart
@collection 
@JsonSerializable(explicitToJson: true, converters: [UTCDateTimeConverter()])
class Profile implements EntityBase {
  @JsonKey(includeFromJson: false, includeToJson: false)
  Id id = Isar.autoIncrement; 

  @override
  @Index(unique: true) 
  late String uuid; 

  static const int maxNameLength = 96;

  late String name;

  @Index() 
  DateTime createdDate; 


  String get imagePath => "$uuid.png";

  Profile({
    this.id = Isar.autoIncrement, 
    DateTime? createdDate,
    required this.name,
  }) : createdDate = createdDate ?? DateTime.now(),
       uuid = const Uuid().v4();

  factory Profile.fromJson(Map<String, dynamic> json) => _$ProfileFromJson(json);
  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  static Future<void> createDefaultProfile() async {
    final profile = Profile(name: "Default Profile");
    await IsarStore.instance.writeTxn(() async {
      await IsarStore.instance.profiles.put(profile);
    });
  }
}
```
---
### 3. Run code generator
Start up the build runner with this code
```
dart run build_runner build
```
---
### 4. Open Isar instance
Start up a new instance and pass all collection schemas.
```dart
// Old ObjectBox code
class Store {
    static late final Store _instance;
    final Store store;
// ...
}

// New Isar implementation
class IsarStore {
    static late Isar instance;
    
    static Future<void> initialize() async {
        final dir = await getApplicationDocumentsDirectory();
        instance = await Isar.open(
        [ExpenseSchema, CategorySchema],
        directory: dir.path,
        inspector: true,
        );
    }
}

// Initialize in main.dart
void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await IsarStore.initialize();
    runApp(const FlowApp());
}

```
---
### 5. Change UI Layer
*Update expense list widget* (views/home/expense_list.dart):
```dart
// Original
final expenses = ref.watch(expenseProvider);

// New reactive version
final expensesAsync = ref.watch(expenseRepositoryProvider).watchExpenses();

return expensesAsync.when(
  data: (expenses) => ListView.builder(
    itemCount: expenses.length,
    itemBuilder: (_, i) => ExpenseTile(expenses[i]),
  ),
  // ... error/loading states
);
```

