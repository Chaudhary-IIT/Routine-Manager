import '../models/task.dart';
import '../utils/date_utils.dart';

class PostponeService {
    static String nextValidDate(Task task, DateTime from) {
        DateTime d = from.add(const Duration(days: 1));

        for (int i = 0; i < 30; i++) {
        final weekdayMatch = task.weekdays.contains(d.weekday);
        final dateStr = todayKey(d);

        if (weekdayMatch) {
            return dateStr;
        }

        d = d.add(const Duration(days: 1));
        }

        // fallback: tomorrow
        return todayKey(from.add(const Duration(days: 1)));
    }
}
