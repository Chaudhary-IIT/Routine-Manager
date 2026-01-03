import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskService {
  static Box<Task> getBox() => Hive.box<Task>('tasks');

  // Helper to ensure consistent date formatting (yyyy-MM-dd)
  static String todayKey(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static List<Task> tasksForToday(DateTime date) {
    final box = getBox();
    final dateKey = todayKey(date);
    
    // Get weekday name (e.g., "Monday") to match your Task model's format
    final weekday = DateFormat('EEEE').format(date); 

    return box.values.where((task) {
      // 1. Basic Active Check
      if (!task.active) return false;

      // 2. EFFECTIVE DATE CHECK (Crucial for Edit History)
      // If the task is effective from "2026-01-20" and we are looking at "2026-01-10",
      // it should NOT show up yet.
      if (task.effectiveFrom != null) {
        // String comparison works for ISO dates (yyyy-MM-dd)
        // If effectiveFrom is "greater" (later) than today, hide it.
        if (task.effectiveFrom!.compareTo(dateKey) > 0) {
          return false;
        }
      }

      // 3. Weekday & Manual Date Logic
      final matchesWeekday = task.weekdays.contains(weekday);
      final isManualDate = task.manualDates.contains(dateKey);
      
      return matchesWeekday || isManualDate;
    }).toList();
  }
}