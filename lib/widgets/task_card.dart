import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../screens/task_form_screen.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final String status;
  final VoidCallback onDone;
  final VoidCallback onPostpone;

  const TaskCard({
    super.key,
    required this.task,
    required this.status,
    required this.onDone,
    required this.onPostpone,
  });

  @override
  State<TaskCard> createState() => TaskCardState();
}

class TaskCardState extends State<TaskCard> {
  bool expanded = false;
  bool _isPressed = false;

  bool get isDone => widget.status == 'done';

  // --- SCORE CALCULATION LOGIC ---
  int _consistencyScore = 0;

  @override
  void initState() {
    super.initState();
    _calculateConsistency();
  }

  // Recalculate if the task or status updates
  @override
  void didUpdateWidget(TaskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || oldWidget.task != widget.task) {
      _calculateConsistency();
    }
  }

  void _calculateConsistency() {
    // 1. Look back 30 days
    final now = DateTime.now();
    final statusBox = Hive.box('task_statuses'); // Ensure this box is open in main.dart!
    
    int scheduledCount = 0;
    int doneCount = 0;

    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final weekday = DateFormat('EEEE').format(date);

      // 2. Check if task was scheduled for this day
      // (Matches weekday OR is a manual date)
      // AND checks effective date (Time Travel logic)
      bool isEffective = true;
      if (widget.task.effectiveFrom != null) {
        if (widget.task.effectiveFrom!.compareTo(dateKey) > 0) isEffective = false;
      }

      if (isEffective) {
        final isScheduled = widget.task.weekdays.contains(weekday) || 
                            widget.task.manualDates.contains(dateKey);
        
        if (isScheduled) {
          scheduledCount++;
          
          // 3. Check status
          final key = "${widget.task.id}_$dateKey";
          final status = statusBox.get(key);
          if (status == 'done') {
            doneCount++;
          }
        }
      }
    }

    // 4. Calculate Percentage
    if (scheduledCount == 0) {
      _consistencyScore = 0; 
    } else {
      _consistencyScore = ((doneCount / scheduledCount) * 100).round();
    }
  }

  Color get _scoreColor {
    if (_consistencyScore >= 75) return const Color(0xFF34C759); // Green
    if (_consistencyScore < 40) return const Color(0xFFFF453A); // Red
    return const Color(0xFFFF9F0A); // Orange/Yellow
  }

  // --- END LOGIC ---

  static const greenGradient = LinearGradient(
    colors: [Color(0xFF34C759), Color(0xFF30D158)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const orangeGradient = LinearGradient(
    colors: [Color(0xFFFF9F0A), Color(0xFFFFB340)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  Future<void> _handleRename() async {
    final TextEditingController ctrl = TextEditingController(text: widget.task.name);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Rename Routine', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter new name",
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty && newName != widget.task.name) {
      final box = Hive.box<Task>('tasks');
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      widget.task.active = false;
      widget.task.save();

      box.add(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: newName.trim(),
        weekdays: widget.task.weekdays,
        manualDates: widget.task.manualDates,
        effectiveFrom: todayStr,
        active: true,
      ));

      setState(() {});
    }
  }

  void _handleDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text("Delete Routine?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This will stop the routine from appearing in the future. Past history will be kept.",
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              widget.task.active = false;
              widget.task.save();
              Navigator.pop(ctx);
              setState(() {}); 
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 500),
      opacity: isDone ? 0.5 : 1.0,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastLinearToSlowEaseIn,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDone ? [] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: CustomPaint(
              painter: _GradientBorderPainter(
                strokeWidth: 1.5,
                radius: 24,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _isPressed 
                      ? const Color(0xFF1C1C1E).withOpacity(0.8) 
                      : const Color(0xFF1C1C1E).withOpacity(0.6), 
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    // HEADER
                    GestureDetector(
                      onTapDown: (_) => setState(() => _isPressed = true),
                      onTapUp: (_) {
                        setState(() => _isPressed = false);
                        HapticFeedback.lightImpact();
                        setState(() => expanded = !expanded);
                      },
                      onTapCancel: () => setState(() => _isPressed = false),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onDoubleTap: _handleRename,
                                child: Text(
                                  widget.task.name,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    decorationColor: Colors.white.withOpacity(0.5),
                                    color: isDone ? Colors.white.withOpacity(0.5) : Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.fastLinearToSlowEaseIn,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // EXPANDABLE AREA
                    AnimatedSize(
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.fastLinearToSlowEaseIn,
                      alignment: Alignment.topCenter,
                      child: expanded
                          ? Container(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // PRIMARY ACTIONS
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _VibrantActionButton(
                                          label: 'Done',
                                          icon: Icons.check,
                                          gradient: greenGradient,
                                          shadowColor: const Color(0xFF34C759),
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            widget.onDone();
                                            _calculateConsistency(); // Update score immediately
                                            setState((){});
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _VibrantActionButton(
                                          label: 'Postpone',
                                          icon: Icons.access_time_rounded,
                                          gradient: orangeGradient,
                                          shadowColor: const Color(0xFFFF9F0A),
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            widget.onPostpone();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  const SizedBox(height: 16),

                                  // --- BOTTOM ROW: Score (Left) + Actions (Right) ---
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween, // Push to edges
                                    children: [
                                      
                                      // 1. CONSISTENCY SCORE (New)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _scoreColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _scoreColor.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.trending_up, color: _scoreColor, size: 16),
                                            const SizedBox(width: 6),
                                            Text(
                                              "$_consistencyScore%",
                                              style: TextStyle(
                                                color: _scoreColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 2. EDIT / DELETE BUTTONS
                                      Row(
                                        children: [
                                          _GlassIconButton(
                                            icon: Icons.edit_calendar_rounded,
                                            onTap: () async {
                                              HapticFeedback.selectionClick();
                                              final result = await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => TaskFormScreen(
                                                    existingTask: widget.task,
                                                    isEdit: true,
                                                  ),
                                                ),
                                              );
                                              if (result == true) {
                                                setState(() {});
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 12),
                                          _GlassIconButton(
                                            icon: Icons.delete_outline_rounded,
                                            color: Colors.redAccent,
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              _handleDelete();
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ... Keep existing Helper Classes (_GlassIconButton, _GradientBorderPainter, _VibrantActionButton) ...
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _GlassIconButton({required this.icon, required this.onTap, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: color.withOpacity(0.8), size: 20),
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;
  final Gradient gradient;

  _GradientBorderPainter({required this.strokeWidth, required this.radius, required this.gradient});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(strokeWidth/2, strokeWidth/2, size.width-strokeWidth, size.height-strokeWidth);
    final RRect rRect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final Paint paint = Paint()..style = PaintingStyle.stroke..strokeWidth = strokeWidth..shader = gradient.createShader(rect);
    canvas.drawRRect(rRect, paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class _VibrantActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color shadowColor;
  final VoidCallback onTap;

  const _VibrantActionButton({required this.label, required this.icon, required this.gradient, required this.shadowColor, required this.onTap});

  @override
  State<_VibrantActionButton> createState() => _VibrantActionButtonState();
}

class _VibrantActionButtonState extends State<_VibrantActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) { setState(() => _isPressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 54,
        transform: _isPressed ? Matrix4.identity().scaled(0.96) : Matrix4.identity(),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: widget.shadowColor.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(widget.icon, color: Colors.black, size: 20),
                const SizedBox(width: 8),
                Text(widget.label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
          ),
        ),
      ),
    );
  }
}