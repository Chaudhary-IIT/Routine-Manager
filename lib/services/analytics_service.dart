import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class AnalyticsService {
  // Use the new box consistent with other services
  static Box get _statusBox => Hive.box('task_statuses');

  // UPDATED: Accepts the full Task object to calculate strict schedule accuracy
  static Map<String, dynamic> taskStats(Task task) {
    // Safety check: Return zeros if box isn't ready
    if (!Hive.isBoxOpen('task_statuses')) {
      return {'done': 0, 'postponed': 0, 'completion': 0.0};
    }

    final now = DateTime.now();
    int done = 0;
    int postponed = 0;
    int scheduledCount = 0;

    // Analyze the last 30 days
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final weekday = DateFormat('EEEE').format(date); // e.g., "Monday"

      // 1. Check if task was "Effective" (Time Travel Logic)
      // If task started yesterday, don't count 30 days ago against it.
      bool isEffective = true;
      if (task.effectiveFrom != null) {
        if (task.effectiveFrom!.compareTo(dateKey) > 0) isEffective = false;
      }

      if (isEffective) {
        // 2. Was it actually scheduled for this day?
        final isScheduled = task.weekdays.contains(weekday) || 
                            task.manualDates.contains(dateKey);

        if (isScheduled) {
          scheduledCount++;

          // 3. Check status in DB
          final key = "${task.id}_$dateKey";
          final status = _statusBox.get(key);

          if (status == 'done') done++;
          if (status == 'postponed') postponed++;
        }
      }
    }

    // prevent division by zero
    double completion = scheduledCount == 0 ? 0.0 : (done / scheduledCount);
    
    return {
      'done': done,
      'postponed': postponed,
      'completion': completion,
      'scheduled': scheduledCount, // Added for debugging if needed
    };
  }

  static int currentStreak(String taskId) {
    if (!Hive.isBoxOpen('task_statuses')) return 0;

    final now = DateTime.now();
    int streak = 0;

    // Check up to 365 days back
    for (int i = 0; i < 365; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final key = "${taskId}_$dateKey";
      
      final status = _statusBox.get(key);

      if (status == 'done') {
        streak++;
      } else if (i == 0 && status == null) {
        // If today is empty, don't break streak yet (you might do it later today)
        continue;
      } else {
        // Streak broken
        break;
      }
    }
    return streak;
  }
}