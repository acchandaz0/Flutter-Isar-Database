import "dart:io";

import "package:flow/constants.dart";
import "package:flow/data/flow_icon.dart";
import "package:flow/data/setup/default_accounts.dart";
import "package:flow/data/setup/default_categories.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/profile.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/entity/transaction_filter_preset.dart";
import "package:flow/entity/user_preferences.dart";
import "package:isar/isar.dart"; 
import "package:logging/logging.dart";
import "package:material_symbols_icons/symbols.dart";
import "package:moment_dart/moment_dart.dart";
import "package:path/path.dart" as path;
import "package:path_provider/path_provider.dart";

final Logger _log = Logger("Isar-Flow"); 
class IsarStore { // Renamed from ObjectBox
  static IsarStore? _instance;
  static late Isar isar; 

  static late String appDataDirectory;
  static String get imagesDirectory => path.join(appDataDirectory, "images");
  static String kDebugDefaultSubdirectory = "__debug";
  static late final String? subdirectory;
  static late final String? customDirectory;

  factory IsarStore() {
    if (_instance == null) {
      _log.severe("Initialize IsarStore by calling initialize()");
      throw Exception("Initialize IsarStore by calling initialize()");
    }
    return _instance!;
  }

  IsarStore._internal(this.isar);

  static Future<IsarStore> initialize({
    String? customDirectory,
    String? subdirectory,
  }) async {
    if (subdirectory == null && flowDebugMode) {
      subdirectory = kDebugDefaultSubdirectory;
    }

    IsarStore.subdirectory = subdirectory;
    IsarStore.customDirectory = customDirectory;

    appDataDirectory = await _appDataDirectory();

    final dir = Directory(appDataDirectory);
    if (!dir.existsSync()) {
      _log.fine("Creating app data directory at ${dir.path}");
      await dir.create(recursive: true);
    }

    return _instance = IsarStore._internal(
      await Isar.open(
        [
          AccountSchema,
          CategorySchema,
          ProfileSchema,
          TransactionSchema,
          UserPreferencesSchema,
          TransactionFilterPresetSchema,
        ],
        directory: appDataDirectory,
        inspector: flowDebugMode, // Enable debug inspector
      ),
    );
  }

  static Future<String> _appDataDirectory() async {
    if (customDirectory != null) {
      return path.join(customDirectory!, subdirectory);
    }
    final appDataDir = await getApplicationSupportDirectory();
    return path.join(appDataDir.path, subdirectory);
  }

  Future<void> createAndPutDebugData() async {
    if ((await isar.accounts.count()) > 0 || 
        (await isar.categories.count()) > 0) {
      return;
    }

    final categories = await _putCategories();
    final accounts = await _putAccounts(categories);
    await _createTransactions(categories, accounts);
  }

  Future<List<Category>> _putCategories() async {
    final categories = getCategoryPresets().map((e) => e..id = null).toList();
    await isar.writeTxn(() => isar.categories.putAll(categories));
    return categories;
  }

  Future<List<Account>> _putAccounts(List<Category> categories) async {
    final accounts = getAccountPresets("USD").map((e) => e..id = null).toList();
    await isar.writeTxn(() => isar.accounts.putAll(accounts));
    return accounts;
  }

  Future<void> _createTransactions(
    List<Category> categories,
    List<Account> accounts,
  ) async {
    final services = categories.firstWhere(
      (e) => e.iconCode == const IconFlowIcon(Symbols.cloud_circle_rounded).toString(),
    );
    
    final mainAccount = accounts.first;
    
    await isar.writeTxn(() async {
      // Create transactions
      final transactions = [
        Transaction(
          amount: -1.99,
          title: "iCloud",
          category: services,
          account: mainAccount,
          transactionDate: DateTime.now() - const Duration(days: 4),
        // ... other transactions
      ];

      await isar.transactions.putAll(transactions);
      
      // Update account links
      mainAccount.transactions.addAll(transactions);
      await mainAccount.transactions.save();
    });
  }

  Future<void> eraseMainData() async {
    _log.severe("Erasing all data");
    
    await isar.writeTxn(() async {
      await Future.wait([
        isar.transactions.clear(),
        isar.categories.clear(),
        isar.accounts.clear(),
        isar.profiles.clear(),
        isar.userPreferences.clear(),
        isar.transactionFilterPresets.clear(),
      ]);
    });
  }
}