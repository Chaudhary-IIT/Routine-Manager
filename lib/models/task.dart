import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  List<String> weekdays;

  @HiveField(3)
  List<String> manualDates;

  @HiveField(4)
  bool active;

  @HiveField(5)
  String? effectiveFrom;

  Task({
    required this.id,
    required this.name,
    required this.weekdays,
    required this.manualDates,
    this.active = true,
    String? effectiveFrom,
  }) : effectiveFrom = effectiveFrom ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
}