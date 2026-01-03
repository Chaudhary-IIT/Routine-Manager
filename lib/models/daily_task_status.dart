import 'package:hive/hive.dart';

part 'daily_task_status.g.dart';

@HiveType(typeId: 1)
class DailyTaskStatus extends HiveObject {
    @HiveField(0)
    String taskId;

    @HiveField(1)
    String date; // yyyy-mm-dd

    @HiveField(2)
    String status; // done / undone / postponed

    DailyTaskStatus({
        required this.taskId,
        required this.date,
        required this.status,
    });
}
