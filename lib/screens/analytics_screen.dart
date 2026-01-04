import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task.dart';
import '../services/analytics_service.dart';

import 'dart:ui'; // Add this for ImageFilter


class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _currentView = 'Performance';
  final List<String> _views = ['Performance', 'Distribution', 'Insights'];
  final Set<String> _selectedTaskIds = {};

  late List<Task> _allTasks;
  late List<_TaskStat> _computedStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final box = Hive.box<Task>('tasks');
    _allTasks = box.values.where((t) => t.active).toList();
    
    _computedStats = _allTasks.map((task) {
      final stats = AnalyticsService.taskStats(task);
      final streak = AnalyticsService.currentStreak(task.id);
      return _TaskStat(
        task: task,
        done: stats['done'] as int,
        postponed: stats['postponed'] as int,
        completion: stats['completion'] as double,
        streak: streak,
      );
    }).toList();

    // Sort by Total Activity (Frequency) descending
    _computedStats.sort((a, b) {
      final totalA = a.done + a.postponed;
      final totalB = b.done + b.postponed;
      return totalB.compareTo(totalA);
    });
  }

  List<_TaskStat> get _filteredStats {
    if (_selectedTaskIds.isEmpty) return _computedStats;
    return _computedStats.where((s) => _selectedTaskIds.contains(s.task.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    _loadData(); 
    final displayStats = _filteredStats;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // HEADER & CONTROLS
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Analytics",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.2),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _GlassDropdown(
                          value: _currentView,
                          items: _views,
                          onChanged: (val) => setState(() => _currentView = val!),
                          icon: Icons.bar_chart_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () => _showFilterDialog(context),
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: _selectedTaskIds.isEmpty 
                                  ? const Color(0xFF1C1C1E) 
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.filter_list_rounded, 
                                  size: 20, 
                                  color: _selectedTaskIds.isEmpty ? Colors.white : Colors.black
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedTaskIds.isEmpty ? "All" : "${_selectedTaskIds.length}",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedTaskIds.isEmpty ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // MAIN CONTENT
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: KeyedSubtree(
                  key: ValueKey(_currentView),
                  child: _buildCurrentView(displayStats),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(List<_TaskStat> stats) {
    if (stats.isEmpty) {
      return Center(
        child: Text("No data available", style: TextStyle(color: Colors.grey[600])),
      );
    }

    switch (_currentView) {
      case 'Performance':
        return _buildBarChart(stats);
      case 'Distribution':
        return _buildPieChart(stats); // <--- UPDATED THIS
      case 'Insights':
      default:
        return _buildInsightsList(stats);
    }
  }
  

// --- VIEW 1: PERFORMANCE (Leaderboard Chart + Detailed Cards) ---
  Widget _buildBarChart(List<_TaskStat> stats) {
    // 1. Prepare Data: Sort by total activity (highest first)
    final sortedStats = List<_TaskStat>.from(stats);
    sortedStats.sort((a, b) => (b.done + b.postponed).compareTo(a.done + a.postponed));
    
    // Top 5 for the chart to prevent overcrowding
    final chartStats = sortedStats.take(5).toList();
    final double maxY = chartStats.isEmpty 
        ? 10 
        : (chartStats.first.done + chartStats.first.postponed).toDouble() * 1.2; // Add 20% headroom

    // 2. Define a Premium Color Palette
    final List<Color> barColors = [
      const Color(0xFF34C759), // Neon Green
      const Color(0xFF5E5CE6), // Indigo
      const Color(0xFFFF9F0A), // Orange
      const Color(0xFF30B0C7), // Teal
      const Color(0xFFFF375F), // Pink
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 120), // Bottom padding for dock
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECTION A: THE LEADERBOARD CHART ---
          Text(
            "Top Performers",
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Your most active routines this month",
            style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 30),

          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: const FlGridData(show: false), // Clean look
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= chartStats.length) return const SizedBox();
                        final name = chartStats[value.toInt()].task.name;
                        // Show first 3 letters capitalized
                        final label = name.length > 3 ? name.substring(0, 3).toUpperCase() : name.toUpperCase();
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            label,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey[400], 
                              fontWeight: FontWeight.bold, 
                              fontSize: 11
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2C2C2E),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        rod.toY.toInt().toString(),
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                barGroups: chartStats.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stat = entry.value;
                  final total = (stat.done + stat.postponed).toDouble();
                  final color = barColors[index % barColors.length];

                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: total == 0 ? 0.5 : total, // Ensure min height for visibility
                        color: color,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: Colors.white.withOpacity(0.03), // Faint track background
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ).animate().scaleY(alignment: Alignment.bottomCenter, duration: 600.ms, curve: Curves.easeOutQuart),

          const SizedBox(height: 40),

          // --- SECTION B: DETAILED BREAKDOWN LIST ---
          Text(
            "Breakdown",
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(), // Let the parent scroll
            itemCount: sortedStats.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final stat = sortedStats[index];
              final color = barColors[index % barColors.length];
              return _PerformanceCard(stat: stat, accentColor: color)
                  .animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.1);
            },
          ),
        ],
      ),
    );
  }

  // --- VIEW 2: DISTRIBUTION (Premium Glass + Hero Chart) ---
  Widget _buildPieChart(List<_TaskStat> stats) {
    return ListView.separated(
      // FIXED: Added 120 bottom padding to prevent Dock overlap
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return _TaskDistributionCard(stat: stats[index])
            .animate()
            .fadeIn(delay: (50 * index).ms)
            .slideY(begin: 0.1, curve: Curves.easeOutQuart);
      },
    );
  }

 // --- VIEW 3: INSIGHTS (The "Habit Coach" Dashboard) ---
  Widget _buildInsightsList(List<_TaskStat> stats) {
    // 1. Calculate Global Health
    int totalDone = stats.fold(0, (sum, item) => sum + item.done);
    int totalPostponed = stats.fold(0, (sum, item) => sum + item.postponed);
    int totalActivity = totalDone + totalPostponed;
    double globalHealth = totalActivity == 0 ? 0 : totalDone / totalActivity;

    // 2. Split Tasks into Categories
    final neglectedTasks = stats.where((s) => s.completion < 0.5).toList();
    final doingWellTasks = stats.where((s) => s.completion >= 0.5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. GLOBAL HEALTH SCORE CARD
          _GlobalHealthCard(healthScore: globalHealth),
          const SizedBox(height: 32),

          // B. "WHAT IS WRONG" SECTION (Neglected Tasks)
          if (neglectedTasks.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF375F), size: 20),
                const SizedBox(width: 8),
                Text(
                  "Needs Attention",
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFFFF375F), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "You are postponing these frequently.",
              style: GoogleFonts.plusJakartaSans(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...neglectedTasks.map((stat) => _DetailedInsightCard(stat: stat, isWarning: true)),
            const SizedBox(height: 32),
          ],

          // C. "ON TRACK" SECTION
          if (doingWellTasks.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF34C759), size: 20),
                const SizedBox(width: 8),
                Text(
                  "On Track",
                  style: GoogleFonts.plusJakartaSans(color: const Color(0xFF34C759), fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...doingWellTasks.map((stat) => _DetailedInsightCard(stat: stat, isWarning: false)),
          ]
        ],
      ),
    );
  }


  void _showFilterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Filter Routines", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(onPressed: () { setModalState(() => _selectedTaskIds.clear()); setState(() {}); }, child: const Text("Select All")),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done", style: TextStyle(color: Colors.white))),
                  ],
                ),
                const Divider(color: Colors.white10),
                SizedBox(
                  height: 300,
                  child: ListView(
                    children: _allTasks.map((task) {
                      return CheckboxListTile(
                        title: Text(task.name, style: const TextStyle(color: Colors.white)),
                        value: _selectedTaskIds.contains(task.id),
                        activeColor: const Color(0xFF6366F1),
                        checkColor: Colors.white,
                        onChanged: (bool? value) {
                          setModalState(() {
                            if (value == true) _selectedTaskIds.add(task.id);
                            else _selectedTaskIds.remove(task.id);
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _InsightGridCard extends StatelessWidget {
  final _TaskStat stat;

  const _InsightGridCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    // Determine Color based on completion rate
    Color statusColor;
    if (stat.completion >= 0.8) {
      statusColor = const Color(0xFF34C759); // Green
    } else if (stat.completion >= 0.5) {
      statusColor = const Color(0xFFFF9F0A); // Orange
    } else {
      statusColor = const Color(0xFFFF375F); // Red/Pink
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Header: Icon & Streak
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Initial Icon
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        stat.task.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Streak Badge (Only if active)
                  if (stat.streak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF9F0A).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFF9F0A).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department, color: Color(0xFFFF9F0A), size: 12),
                          const SizedBox(width: 2),
                          Text(
                            "${stat.streak}",
                            style: const TextStyle(
                              color: Color(0xFFFF9F0A), 
                              fontSize: 10, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // 2. Main Stat: Big Percentage
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stat.task.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "${(stat.completion * 100).toInt()}",
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 36, // Huge Hero Number
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "%",
                        style: GoogleFonts.plusJakartaSans(
                          color: statusColor, // Colored symbol
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // 3. Mini Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Completion", style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                      Text("${stat.done}/${stat.done + stat.postponed}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stat.completion,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

// 1. THE GLOBAL HEALTH SCORE (Top Card)
class _GlobalHealthCard extends StatelessWidget {
  final double healthScore; // 0.0 to 1.0

  const _GlobalHealthCard({required this.healthScore});

  @override
  Widget build(BuildContext context) {
    // Determine status text
    String statusTitle;
    String statusMsg;
    Color color;

    if (healthScore >= 0.8) {
      statusTitle = "Excellent";
      statusMsg = "You are crushing your goals.";
      color = const Color(0xFF34C759);
    } else if (healthScore >= 0.5) {
      statusTitle = "Good";
      statusMsg = "You are consistent, but room to improve.";
      color = const Color(0xFFFF9F0A);
    } else {
      statusTitle = "Off Track";
      statusMsg = "Focus is slipping. Let's get back to it.";
      color = const Color(0xFFFF375F);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.2), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Circular Percent Indicator
          SizedBox(
            height: 70, width: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: 1.0,
                  color: Colors.white.withOpacity(0.1),
                  strokeWidth: 6,
                ),
                CircularProgressIndicator(
                  value: healthScore,
                  color: color,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  "${(healthScore * 100).toInt()}%",
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                )
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Discipline Score", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                Text(statusTitle, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(statusMsg, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13, height: 1.2)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// 2. THE DETAILED INSIGHT CARD (Textual Analysis)
class _DetailedInsightCard extends StatelessWidget {
  final _TaskStat stat;
  final bool isWarning;

  const _DetailedInsightCard({required this.stat, required this.isWarning});

  @override
  Widget build(BuildContext context) {
    // Generate intelligent feedback based on stats
    String feedback;
    IconData feedbackIcon;
    
    if (isWarning) {
      if (stat.postponed > stat.done * 2) {
        feedback = "Procrastination Alert: You postpone this 2x more than you do it.";
        feedbackIcon = Icons.timelapse;
      } else {
        feedback = "Consistency is low. Try reducing the difficulty.";
        feedbackIcon = Icons.trending_down;
      }
    } else {
      if (stat.streak > 5) {
        feedback = "You are on a roll! Keep the streak alive.";
        feedbackIcon = Icons.whatshot;
      } else {
        feedback = "Steady progress. You are building a solid habit.";
        feedbackIcon = Icons.verified;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isWarning ? const Color(0xFFFF375F).withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stat.task.name,
                style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              _StatusBadge(completion: stat.completion),
            ],
          ),
          const SizedBox(height: 12),
          
          // The "Analysis" Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isWarning ? const Color(0xFFFF375F).withOpacity(0.1) : const Color(0xFF34C759).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(feedbackIcon, color: isWarning ? const Color(0xFFFF375F) : const Color(0xFF34C759), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    feedback,
                    style: TextStyle(
                      color: isWarning ? const Color(0xFFFFCEC0) : const Color(0xFFD0FFD6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          // Mini Stat Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Completed: ${stat.done}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              Text("Postponed: ${stat.postponed}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              Text("Streak: ${stat.streak}", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          )
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }
}

// 3. HELPER BADGE
class _StatusBadge extends StatelessWidget {
  final double completion;
  const _StatusBadge({required this.completion});

  @override
  Widget build(BuildContext context) {
    String text;
    Color color;
    if (completion < 0.5) {
      text = "Struggling";
      color = const Color(0xFFFF375F);
    } else if (completion < 0.8) {
      text = "Stable";
      color = const Color(0xFFFF9F0A);
    } else {
      text = "Mastered";
      color = const Color(0xFF34C759);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final _TaskStat stat;
  final Color accentColor;

  const _PerformanceCard({required this.stat, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final total = stat.done + stat.postponed;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              // 1. Task Icon / Initial
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
                ),
                child: Center(
                  child: Text(
                    stat.task.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: accentColor, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 20
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // 2. Name & Progress Bar
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          stat.task.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, 
                            fontWeight: FontWeight.w600, 
                            fontSize: 16
                          ),
                        ),
                        // Small "Streak" badge
                        if (stat.streak > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9F0A).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Color(0xFFFF9F0A), size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "${stat.streak}",
                                  style: const TextStyle(color: Color(0xFFFF9F0A), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // The Custom Progress Bar
                    Stack(
                      children: [
                        // Background Track
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Filled Bar
                        FractionallySizedBox(
                          widthFactor: stat.completion > 0 ? stat.completion : 0.0, // Safety check
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentColor.withOpacity(0.5), accentColor],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 2))
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              // 3. The "Hero" Number (Total Count)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$total",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 22
                    ),
                  ),
                  Text(
                    "acts",
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withOpacity(0.4), 
                      fontSize: 10,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskDistributionCard extends StatelessWidget {
  final _TaskStat stat;

  const _TaskDistributionCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final total = stat.done + stat.postponed;
    final double completionRate = total == 0 ? 0 : (stat.done / total);

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), // Glass effect
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E).withOpacity(0.6), // Translucent dark
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withOpacity(0.08), // Subtle border
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header: Name & Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    stat.task.name,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      "$total Activities",
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // The Hero Chart Layout
              SizedBox(
                height: 200, // Large canvas for the chart
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // The Chart
                    PieChart(
                      PieChartData(
                        startDegreeOffset: 270, // Start from top
                        sectionsSpace: 0,
                        centerSpaceRadius: 70, // Large hole
                        sections: [
                          // 1. DONE SECTION (Neon Gradient)
                          PieChartSectionData(
                            value: stat.done.toDouble(),
                            showTitle: false,
                            radius: 18, // Thinner stroke
                            gradient: const SweepGradient(
                              colors: [
                                Color(0xFF205E32), // Darker Forest Green start
                                Color(0xFF34C759), // Neon Green end
                              ],
                              stops: [0.0, 1.0],
                            ),
                            // strokeCap: StrokeCap.round, // Note: fl_chart applies this to ends of the whole chart if sectionsSpace > 0
                          ),
                          // 2. POSTPONED SECTION (Subtle Background)
                          PieChartSectionData(
                            value: stat.postponed.toDouble(),
                            showTitle: false,
                            radius: 18,
                            color: const Color(0xFF2C2C2E), // Dark Grey
                          ),
                          // 3. EMPTY STATE (If total is 0)
                          if (total == 0)
                            PieChartSectionData(
                              value: 1,
                              showTitle: false,
                              radius: 18,
                              color: Colors.white.withOpacity(0.05),
                            ),
                        ],
                      ),
                    ),
                    
                    // Center Text
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${(completionRate * 100).toInt()}%",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 32,
                            // FIXED: Maximum weight for "Apple Health" solidity
                            fontWeight: FontWeight.w900, 
                            letterSpacing: -1,
                          ),
                        ),
                        Text(
                          "Done",
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem("Done", const Color(0xFF34C759)),
                  const SizedBox(width: 24),
                  _buildLegendItem("Postponed", const Color(0xFFFF9F0A)), // Amber/Orange
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.6),
                blurRadius: 8,
                spreadRadius: 1,
              )
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}


class _StatRow extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final int total;

  const _StatRow({required this.label, required this.count, required this.color, required this.total});

  @override
  Widget build(BuildContext context) {
    final percentage = total == 0 ? 0 : ((count / total) * 100).round();
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
        Text(
          "$percentage%",
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}

// DATA & HELPERS (Keep these exactly as before)
class _TaskStat {
  final Task task;
  final int done;
  final int postponed;
  final double completion;
  final int streak;

  _TaskStat({required this.task, required this.done, required this.postponed, required this.completion, required this.streak});
}

class _GlassDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData icon;

  const _GlassDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08), // Lighter glass
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              icon: Icon(Icons.keyboard_arrow_down_rounded, 
                  color: Colors.white.withOpacity(0.8), size: 20),
              dropdownColor: const Color(0xFF2C2C2E), // Solid dark for menu
              borderRadius: BorderRadius.circular(20),
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.5,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: Colors.white70),
                      const SizedBox(width: 10),
                      Text(item),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InsightMetric(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12))]);
  }
}