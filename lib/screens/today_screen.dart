import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/task.dart';
import '../services/task_service.dart';
import '../services/status_service.dart';
import '../services/postpone_service.dart';
import '../widgets/task_card.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _selectedDate = DateTime.now();
  late List<Task> _currentTasks;
  final ScrollController _dateScrollController = ScrollController();
  
  final List<DateTime> _allDates = List.generate(
    730, 
    (index) => DateTime.now().subtract(const Duration(days: 365)).add(Duration(days: index)),
  );

  @override
  void initState() {
    super.initState();
    _loadTasks();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToDate(_selectedDate);
    });
  }

  void _loadTasks() {
    setState(() {
      _currentTasks = TaskService.tasksForToday(_selectedDate);
    });
  }

  void _scrollToDate(DateTime date) {
    try {
      final index = _allDates.indexWhere((d) => 
        d.year == date.year && d.month == date.month && d.day == date.day
      );
      if (index != -1) {
        const double itemWidth = 72.0;
        final screenWidth = MediaQuery.of(context).size.width;
        final offset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
        _dateScrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    } catch (e) {
      debugPrint("Error scrolling: $e");
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => 
      a.year == b.year && a.month == b.month && a.day == b.day;

  Color _getStatusColor(String status) {
    switch (status) {
      case 'done': return const Color(0xFF34C759);
      case 'postponed': return const Color(0xFFFF9F0A);
      default: return const Color(0xFF636366);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Key forces rebuild on date change so animations re-run properly
    final String listKey = _selectedDate.toIso8601String();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Routines",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                          letterSpacing: -1.5,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.2),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('MMMM d, yyyy').format(_selectedDate).toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.6),
                          letterSpacing: 2.0,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),
                    ],
                  ),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                        builder: (context, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: Color(0xFF6366F1),
                              onPrimary: Colors.white,
                              surface: Color(0xFF1E1E1E),
                            ),
                          ),
                          child: child!,
                        ),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadTasks();
                        _scrollToDate(picked);
                      }
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
                    ).animate().scale(delay: 300.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // DATE TIMELINE
            SizedBox(
              height: 85,
              child: ListView.separated(
                controller: _dateScrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                scrollDirection: Axis.horizontal,
                itemCount: _allDates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final date = _allDates[index];
                  final isSelected = _isSameDay(date, _selectedDate);
                  final isToday = _isSameDay(date, DateTime.now());
                  final accentColor = const Color(0xFF6366F1);

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedDate = date);
                      _loadTasks();
                      _scrollToDate(date);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 60,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? accentColor 
                            : (isToday ? const Color(0xFF2C2C2E) : Colors.transparent),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : Colors.white10,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.5),
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('d').format(date),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('E').format(date).toUpperCase(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white.withOpacity(0.9) : Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * (index % 10)).ms).slideX(begin: 0.5); 
                },
              ),
            ),
            const SizedBox(height: 24),

            // 3. TASKS LIST
            Expanded(
              key: ValueKey(listKey), 
              child: _currentTasks.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.done_all_rounded, size: 64, color: Colors.grey[800])
                              .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
                          const SizedBox(height: 16),
                          Text(
                            "All Caught Up",
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey[400],
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(delay: 300.ms),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 120),
                      itemCount: _currentTasks.length,
                      itemBuilder: (context, index) {
                        final task = _currentTasks[index];
                        final status = StatusService.getStatus(task.id, _selectedDate);
                        final statusColor = _getStatusColor(status);
                        final isLast = index == _currentTasks.length - 1;

                        // THE FIX: Use Stack instead of IntrinsicHeight
                        return Stack(
                          children: [
                            // 1. The Timeline Line (Behind everything)
                            if (!isLast)
                              Positioned(
                                left: 9, // Centered under the 20px wide dot area (10 - 1)
                                top: 30, // Start below the dot
                                bottom: 0, // Stretch to bottom of cell
                                child: Container(
                                  width: 2,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                              
                            // 2. The Content (Dot + Card)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 0), // Spacing handled by Card margin
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // DOT COLUMN
                                  Padding(
                                    padding: const EdgeInsets.only(top: 20, right: 16),
                                    child: Container(
                                      width: 20,
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: statusColor.withOpacity(0.8),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  // CARD
                                  Expanded(
                                    child: TaskCard(
                                      task: task,
                                      status: status,
                                      onDone: () {
                                        StatusService.setStatus(task.id, _selectedDate, 'done');
                                        setState(() {}); 
                                      },
                                      onPostpone: () {
                                        StatusService.setStatus(task.id, _selectedDate, 'postponed');
                                        final nextDate = PostponeService.nextValidDate(task, _selectedDate);
                                        if (!task.manualDates.contains(nextDate)) {
                                          task.manualDates.add(nextDate);
                                          task.save();
                                        }
                                        _loadTasks();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 400.ms, delay: (100 * index).ms)
                        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutQuart);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}