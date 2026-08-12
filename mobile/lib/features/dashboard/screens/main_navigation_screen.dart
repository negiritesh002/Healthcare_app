import 'package:flutter/material.dart';
import 'dashboard_home_screen.dart';
import '../../patients/screens/patient_list_screen.dart';
import '../../appointments/screens/appointments_screen.dart';
import '../../more/screens/more_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;

  const MainNavigationScreen({super.key, this.initialIndex = 0});

  static void navigateToTab(BuildContext context, int tabIndex) {
    final state = context.findAncestorStateOfType<_MainNavigationScreenState>();
    if (state != null) {
      state.switchTab(tabIndex);
    }
  }

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = const [
    DashboardHomeScreen(),
    PatientListScreen(),
    AppointmentsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(
            top: BorderSide(color: Color(0xFFE2E8F0)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF00796B).withValues(alpha: 0.15),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.dashboard_rounded, color: Color(0xFF00796B)),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.people_rounded, color: Color(0xFF00796B)),
              label: 'Patients',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.calendar_month_rounded, color: Color(0xFF00796B)),
              label: 'Appointments',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, color: Color(0xFF64748B)),
              selectedIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF00796B)),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
