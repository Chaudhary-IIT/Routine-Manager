import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; // For Blur
import '../models/task.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? existingTask;
  final bool isEdit;

  const TaskFormScreen({super.key, this.existingTask, this.isEdit = false});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  final List<String> _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final Set<String> _selectedWeekdays = {};
  final List<String> _manualDates = [];
  
  // New: Theme Colors
  int _selectedColorIndex = 0;
  final List<Color> _neonColors = [
    const Color(0xFF34C759), // Green
    const Color(0xFF5E5CE6), // Indigo
    const Color(0xFFFF9F0A), // Orange
    const Color(0xFFFF375F), // Pink
    const Color(0xFF30B0C7), // Teal
    const Color(0xFFFFD60A), // Yellow
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.existingTask != null) {
      _nameController.text = widget.existingTask!.name;
      _selectedWeekdays.addAll(widget.existingTask!.weekdays);
      _manualDates.addAll(widget.existingTask!.manualDates);
      // If you saved color index in Hive, load it here. Defaulting to 0.
    }
  }

  // ... (Keep your existing _pickDate and _saveTask logic here) ...
  // Ensure _saveTask saves the 'colorIndex' if you update your Task model!

  void _saveTask() {
      if (_nameController.text.trim().isEmpty) return;

      final box = Hive.box<Task>('tasks');
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Note: You should update your Task model to accept 'colorIndex' or 'hexColor'
      // For now, this just saves the basic data as before.
      
      final newTask = Task(
        id: widget.isEdit && widget.existingTask != null 
            ? DateTime.now().millisecondsSinceEpoch.toString() 
            : DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        weekdays: _selectedWeekdays.toList(),
        manualDates: _manualDates,
        effectiveFrom: todayStr,
        active: true,
      );

      if (widget.isEdit && widget.existingTask != null) {
        widget.existingTask!.active = false; // Archive old
        widget.existingTask!.save();
      }
      
      box.add(newTask);
      Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
     // ... (Your existing DatePicker logic) ...
      final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: _neonColors[_selectedColorIndex], onPrimary: Colors.black, surface: const Color(0xFF1E1E1E)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      if (!_manualDates.contains(dateStr)) setState(() => _manualDates.add(dateStr));
    }
  }


  @override
  Widget build(BuildContext context) {
    // Determine the active accent color
    final accentColor = _neonColors[_selectedColorIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      // Custom "Floaty" AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          widget.isEdit ? 'Edit Routine' : 'New Routine',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO INPUT FIELD (Massive & Glowing)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _nameController.text.isNotEmpty ? accentColor.withOpacity(0.5) : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: _nameController.text.isNotEmpty ? [
                  BoxShadow(color: accentColor.withOpacity(0.2), blurRadius: 12, spreadRadius: -2)
                ] : [],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: TextField(
                controller: _nameController,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                cursorColor: accentColor,
                onChanged: (_) => setState(() {}), // Trigger rebuild for glow
                decoration: InputDecoration.collapsed(
                  hintText: "What's the habit?",
                  hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey[700], fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // 2. NEON COLOR PICKER
            Text("Theme Color", style: _labelStyle()),
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _neonColors.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final isSelected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedColorIndex = index);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _neonColors[index],
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        boxShadow: isSelected ? [BoxShadow(color: _neonColors[index].withOpacity(0.6), blurRadius: 10)] : [],
                      ),
                      child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // 3. WEEKDAY SELECTOR (iOS Style)
            Text("Frequency", style: _labelStyle()),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10, runSpacing: 10,
              children: _weekdays.map((day) {
                final isSelected = _selectedWeekdays.contains(day);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      isSelected ? _selectedWeekdays.remove(day) : _selectedWeekdays.add(day);
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? accentColor.withOpacity(0.2) : const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? accentColor : Colors.transparent),
                    ),
                    child: Text(
                      day.substring(0, 3),
                      style: GoogleFonts.plusJakartaSans(
                        color: isSelected ? accentColor : Colors.grey[400],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // 4. MANUAL DATES (Pill Style)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Specific Dates", style: _labelStyle()),
                TextButton.icon(
                  onPressed: _pickDate,
                  icon: Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
                  label: Text("Add", style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(backgroundColor: accentColor.withOpacity(0.1)),
                )
              ],
            ),
             if (_manualDates.isNotEmpty) ...[
               const SizedBox(height: 12),
               Wrap(
                 spacing: 8, runSpacing: 8,
                 children: _manualDates.map((dateStr) {
                   final date = DateTime.parse(dateStr);
                   return Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                     child: Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(DateFormat('MMM d').format(date), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                         const SizedBox(width: 8),
                         GestureDetector(
                           onTap: () => setState(() => _manualDates.remove(dateStr)),
                           child: const Icon(Icons.close, size: 14, color: Colors.grey),
                         )
                       ],
                     ),
                   );
                 }).toList(),
               ),
             ],

            const SizedBox(height: 60),

            // 5. THE "GLOW" ACTION BUTTON
            Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();
                  _saveTask();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.isEdit ? "Update Routine" : "Create Routine",
                      style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  TextStyle _labelStyle() => GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1);
}