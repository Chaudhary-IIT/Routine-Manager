import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'today_screen.dart';
import 'analytics_screen.dart';
import 'task_form_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int currentIndex = 0;

  final pages = const [
    TodayScreen(),
    AnalyticsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: pages,
          ),
          
          // Bottom Dock
          Positioned(
            left: 24,
            right: 24,
            bottom: 30,
            child: _UnifiedGlassDock(
              currentIndex: currentIndex,
              onTabChanged: (index) {
                if (currentIndex != index) {
                   HapticFeedback.selectionClick();
                   setState(() => currentIndex = index);
                }
              },
              onAddPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TaskFormScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedGlassDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onAddPressed;

  const _UnifiedGlassDock({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    const double height = 80;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withOpacity(0.85),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. HOME BUTTON
                _DockItem(
                  // Logic: Filled when active, Outlined when inactive
                  icon: currentIndex == 0 
                      ? Icons.home_rounded 
                      : Icons.home_outlined, 
                  isSelected: currentIndex == 0,
                  onTap: () => onTabChanged(0),
                ),

                // 2. CENTER ADD BUTTON
                GestureDetector(
                  onTap: onAddPressed,
                  child: Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34C759), Color(0xFF32D74B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF34C759).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 32),
                  ),
                ),

                // 3. ANALYTICS BUTTON
                _DockItem(
                  // Logic: Filled Bar Chart when active, Outlined when inactive
                  icon: currentIndex == 1 
                      ? Icons.bar_chart_rounded 
                      : Icons.bar_chart_outlined, 
                  isSelected: currentIndex == 1,
                  onTap: () => onTabChanged(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DockItem({
    super.key,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 52, // Fixed width for circle
        height: 52, // Fixed height for circle
        decoration: BoxDecoration(
          // Active: White Circle. Inactive: Transparent.
          color: isSelected ? Colors.white : Colors.transparent,
          shape: BoxShape.circle,
          boxShadow: isSelected 
            ? [
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] 
            : [],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            // This transition handles the smooth icon swap
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(
              icon,
              key: ValueKey(icon), // Key ensures AnimatedSwitcher detects change
              size: 28,
              // Active: Black Icon (on white). Inactive: Grey Icon (on dark).
              color: isSelected ? Colors.black : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}