import "package:flow/entity/_base.dart";
import "package:flow/utils/json/utc_datetime_converter.dart";
import "package:isar/isar.dart"; 
import "package:json_annotation/json_annotation.dart";
import "package:uuid/uuid.dart";

part "profile.g.dart";

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