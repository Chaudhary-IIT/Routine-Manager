import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class StatusService {
  // Use the new box name that Analytics & TaskCard are listening to
  static Box get _box => Hive.box('task_statuses');

  // Helper to generate consistent keys: "taskId_yyyy-MM-dd"
  static String _getKey(String taskId, DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    return "${taskId}_$dateStr";
  }

  static String getStatus(String taskId, DateTime date) {
    final key = _getKey(taskId, date);
    // Returns 'done', 'postponed', or '' (empty string if nothing found)
    return _box.get(key) as String? ?? ''; 
  }

  static void setStatus(String taskId, DateTime date, String status) {
    final key = _getKey(taskId, date);
    
    // If the status is empty or 'undone', remove the entry to save space
    if (status.isEmpty || status == 'undone') {
      _box.delete(key);
    } else {
      _box.put(key, status);
    }
  }
}