import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/task.dart';
import 'models/daily_task_status.dart'; // Keeping for legacy safety
import 'screens/root_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 1. Register Adapters
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(DailyTaskStatusAdapter());

  // 2. Open ALL Boxes required by the app
  await Hive.openBox<Task>('tasks');
  await Hive.openBox<DailyTaskStatus>('daily_status'); // Legacy
  await Hive.openBox('task_statuses'); 

  runApp(const RoutineApp());
}

class RoutineApp extends StatelessWidget {
  const RoutineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Routine Tracker',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: const RootShell(),
    );
  }
}