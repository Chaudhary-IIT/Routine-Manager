import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task.dart';
import '../services/analytics_service.dart';

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

  // --- VIEW 1: PERFORMANCE (Bar Chart) ---
  Widget _buildBarChart(List<_TaskStat> stats) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        final total = stat.done + stat.postponed;
        if (total == 0) return const SizedBox.shrink();

        final doneFlex = (stat.done / total * 100).round();
        final postponedFlex = (stat.postponed / total * 100).round();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(stat.task.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text("$total activities", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF1C1C1E),
                ),
                child: Row(
                  children: [
                    if (doneFlex > 0)
                      Expanded(flex: doneFlex, child: Container(decoration: const BoxDecoration(color: Color(0xFF34C759), borderRadius: BorderRadius.horizontal(left: Radius.circular(6))))),
                    if (postponedFlex > 0)
                      Expanded(flex: postponedFlex, child: Container(decoration: const BoxDecoration(color: Color(0xFFFF9F0A), borderRadius: BorderRadius.horizontal(right: Radius.circular(6))))),
                  ],
                ),
              ).animate().scaleX(duration: 600.ms, alignment: Alignment.centerLeft, curve: Curves.easeOutQuart),
            ],
          ),
        );
      },
    );
  }

  // --- VIEW 2: DISTRIBUTION (Individual Pie Charts) ---
  Widget _buildPieChart(List<_TaskStat> stats) {
    // Show charts for all tasks, but empty ones will look "empty"
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        return _TaskDistributionCard(stat: stats[index])
            .animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1);
      },
    );
  }

  // --- VIEW 3: INSIGHTS LIST ---
  Widget _buildInsightsList(List<_TaskStat> stats) {
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Text(stat.task.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2C2C2E), borderRadius: BorderRadius.circular(8)),
                child: Text("${(stat.completion * 100).toStringAsFixed(0)}%", style: const TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.bold)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _InsightMetric("Done", "${stat.done}", const Color(0xFF34C759)),
                      _InsightMetric("Postponed", "${stat.postponed}", const Color(0xFFFF9F0A)),
                      _InsightMetric("Streak", "${stat.streak}", Colors.white),
                    ],
                  ),
                )
              ],
            ),
          ),
        ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1);
      },
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

// --- NEW COMPONENT: INDIVIDUAL TASK PIE CARD ---
class _TaskDistributionCard extends StatelessWidget {
  final _TaskStat stat;

  const _TaskDistributionCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    final total = stat.done + stat.postponed;
    final bool isEmpty = total == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Task Name
          Text(
            stat.task.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            "$total activities total",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 20),

          // 2. Row: Pie Chart (Left) vs Stats (Right)
          SizedBox(
            height: 120,
            child: Row(
              children: [
                // PIE CHART
                Expanded(
                  flex: 1,
                  child: isEmpty
                      ? Center(
                          child: Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10, width: 8),
                            ),
                          ),
                        )
                      : PieChart(
                          PieChartData(
                            sectionsSpace: 4,
                            centerSpaceRadius: 25,
                            startDegreeOffset: 270,
                            sections: [
                              if (stat.done > 0)
                                PieChartSectionData(
                                  color: const Color(0xFF34C759), // Green
                                  value: stat.done.toDouble(),
                                  title: '',
                                  radius: 20,
                                ),
                              if (stat.postponed > 0)
                                PieChartSectionData(
                                  color: const Color(0xFFFF9F0A), // Orange
                                  value: stat.postponed.toDouble(),
                                  title: '',
                                  radius: 20,
                                ),
                            ],
                          ),
                        ),
                ),
                
                const SizedBox(width: 20),

                // LEGEND / NUMBERS
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatRow(
                        label: "Done",
                        count: stat.done,
                        color: const Color(0xFF34C759),
                        total: total,
                      ),
                      const SizedBox(height: 12),
                      _StatRow(
                        label: "Postponed",
                        count: stat.postponed,
                        color: const Color(0xFFFF9F0A),
                        total: total,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  const _GlassDropdown({required this.value, required this.items, required this.onChanged, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.1))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey[400]),
          dropdownColor: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600),
          items: items.map((String item) {
            return DropdownMenuItem<String>(value: item, child: Row(children: [Icon(icon, size: 18, color: Colors.grey[400]), const SizedBox(width: 8), Text(item)]));
          }).toList(),
          onChanged: onChanged,
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