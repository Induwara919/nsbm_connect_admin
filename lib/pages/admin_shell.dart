import 'package:flutter/material.dart';
import 'package:nsbm_connect_admin/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'student_management_page.dart';
import 'event_calendar_page.dart';
import 'community_hub_page.dart';
import 'settings_management_page.dart';
import 'time_table_page.dart';
import 'announcements_page.dart';
import 'news_updates.dart';
import 'admin_dashboard.dart';

class AdminShell extends StatelessWidget {
  final int selectedIndex;
  const AdminShell({super.key, required this.selectedIndex});

  static const List<String> _pageTitles = [
    "Dashboard Overview",
    "Student Management",
    "Announcements",
    "Event Calendar",
    "Time Table",
    "Community Hub",
    "News Updates",
    "Data Management"
  ];

  static const List<String> _routes = [
    '/dashboard',
    '/students',
    '/announcements',
    '/calendar',
    '/timetable',
    '/community',
    '/news',
    '/management'
  ];

  Widget _getContentForIndex(int index) {
    switch (index) {
      case 0: return const AdminDashboard();
      case 1: return const StudentManagementPage();
      case 2: return const AnnouncementsPage();
      case 3: return const CalendarPage();
      case 4: return const TimeTablePage();
      case 5: return const CommunityHubPage();
      case 6: return const NewsUpdatesPage();
      case 7: return const SettingsManagementPage();
      default:
        return const Center(child: Text("Page not found"));
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text("Confirm Logout", style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to log out of the Admin Panel?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              },
              child: const Text("Logout", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isExtended = MediaQuery.of(context).size.width > 1200;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Row(
        children: [

          NavigationRail(
            extended: isExtended,
            backgroundColor: AppColors.primary,
           
            indicatorColor: Colors.transparent, 
            unselectedIconTheme: const IconThemeData(color: Colors.white60, size: 22),
            selectedIconTheme: const IconThemeData(color: Colors.white, size: 26),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white60, fontSize: 13),
            selectedLabelTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              Navigator.pushReplacementNamed(context, _routes[index]);
            },
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.6), 
                      blurRadius: 20,
                      spreadRadius: 30,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/nsbm_logo.png',
                  width: isExtended ? 120 : 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.grid_view_rounded), label: Text('Dashboard')),
              NavigationRailDestination(icon: Icon(Icons.group_outlined), label: Text('Students')),
              NavigationRailDestination(icon: Icon(Icons.notification_add_outlined), label: Text('Announcements')),
              NavigationRailDestination(icon: Icon(Icons.event_note_outlined), label: Text('Events')),
              NavigationRailDestination(icon: Icon(Icons.auto_stories_outlined), label: Text('Timetable')),
              NavigationRailDestination(icon: Icon(Icons.groups_2_outlined), label: Text('Community')),
              NavigationRailDestination(icon: Icon(Icons.newspaper_outlined), label: Text('News Updates')),
              NavigationRailDestination(icon: Icon(Icons.settings_suggest_outlined), label: Text('Management')),
            ],
          ),

          
          Expanded(
            child: Column(
              children: [
              
                Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        _pageTitles[selectedIndex],
                        style: TextStyle(
                            fontSize: 20, 
                            color: AppColors.secondary, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                        ),
                      ),
                      const Spacer(),
                     
                      TextButton.icon(
                        onPressed: () => _showLogoutDialog(context),
                        icon: const Icon(Icons.power_settings_new_rounded, color: Colors.redAccent, size: 18),
                        label: const Text("Sign Out", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          backgroundColor: Colors.red.shade50,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),

                
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(25),
                    
                    padding: const EdgeInsets.all(30), 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        )
                      ],
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: _getContentForIndex(selectedIndex),
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
