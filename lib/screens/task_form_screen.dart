import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; // Ensure this is imported
import '../models/task.dart';

class TaskFormScreen extends StatefulWidget {
  final Task? existingTask; // If null, it's a new task
  final bool isEdit;        // Flag to trigger "Edit Mode" logic

  const TaskFormScreen({
    super.key,
    this.existingTask,
    this.isEdit = false,
  });

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final TextEditingController _nameController = TextEditingController();
  
  // Updated to use String names to match your Task model
  final List<String> _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  
  final Set<String> _selectedWeekdays = {};
  final List<String> _manualDates = []; // Store yyyy-MM-dd strings

  @override
  void initState() {
    super.initState();
    // Pre-fill data if editing
    if (widget.isEdit && widget.existingTask != null) {
      _nameController.text = widget.existingTask!.name;
      _selectedWeekdays.addAll(widget.existingTask!.weekdays);
      _manualDates.addAll(widget.existingTask!.manualDates);
    }
  }

  String _todayKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1), // Premium accent color
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final dateStr = _todayKey(picked);
      if (!_manualDates.contains(dateStr)) {
        setState(() {
          _manualDates.add(dateStr);
        });
      }
    }
  }

  void _saveTask() {
    if (_nameController.text.trim().isEmpty) return;

    final box = Hive.box<Task>('tasks');
    final todayStr = _todayKey(DateTime.now());

    if (widget.isEdit && widget.existingTask != null) {
      // --- EDIT LOGIC (Time Travel) ---
      
      // 1. "Archive" the old task so it stops appearing from today
      widget.existingTask!.active = false;
      widget.existingTask!.save();

      // 2. Create NEW task taking effect today
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // New unique ID
        name: _nameController.text.trim(),
        weekdays: _selectedWeekdays.toList(),
        manualDates: _manualDates, 
        effectiveFrom: todayStr, // VALID FROM TODAY
        active: true,
      );
      
      box.add(newTask);
      
    } else {
      // --- CREATE LOGIC ---
      final newTask = Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        weekdays: _selectedWeekdays.toList(),
        manualDates: _manualDates,
        effectiveFrom: todayStr,
        active: true,
      );
      box.add(newTask);
    }

    Navigator.pop(context, true); // Return true to trigger refresh
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Routine' : 'New Routine', 
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. NAME INPUT
            TextField(
              controller: _nameController,
              style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Routine Name',
                labelStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1C1C1E),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 2. WEEKDAY SELECTOR
            Text("Repeat On", style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _weekdays.map((day) {
                final isSelected = _selectedWeekdays.contains(day);
                return FilterChip(
                  label: Text(day.substring(0, 3)), // Mon, Tue, etc.
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedWeekdays.add(day);
                      } else {
                        _selectedWeekdays.remove(day);
                      }
                    });
                  },
                  backgroundColor: const Color(0xFF1C1C1E),
                  selectedColor: const Color(0xFF6366F1), // Premium Purple/Blue
                  checkmarkColor: Colors.white,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? Colors.transparent : Colors.white10),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 32),

            // 3. MANUAL DATES
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Specific Dates", style: GoogleFonts.plusJakartaSans(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w600)),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 16, color: Color(0xFF6366F1)),
                        const SizedBox(width: 4),
                        Text("Add Date", style: GoogleFonts.plusJakartaSans(color: const Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_manualDates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text("No extra dates added.", style: TextStyle(color: Colors.grey[800], fontStyle: FontStyle.italic)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _manualDates.map((dateStr) {
                  // Format '2026-01-05' to 'Jan 5'
                  final date = DateTime.parse(dateStr);
                  final displayDate = DateFormat('MMM d').format(date);
                  
                  return Chip(
                    backgroundColor: const Color(0xFF2C2C2E),
                    label: Text(displayDate, style: const TextStyle(color: Colors.white)),
                    deleteIcon: const Icon(Icons.close, size: 16, color: Colors.grey),
                    onDeleted: () {
                      setState(() => _manualDates.remove(dateStr));
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                  );
                }).toList(),
              ),

            const SizedBox(height: 50),
            
            // 4. SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 5,
                  shadowColor: Colors.white.withOpacity(0.2),
                ),
                child: Text(
                  widget.isEdit ? 'Save Changes' : 'Create Routine',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 16
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}