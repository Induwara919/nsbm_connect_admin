import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchDashboardData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));

          final data = snapshot.data!;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("System Overview"),
                const SizedBox(height: 16),
                _buildTopMetricsGrid(data),
                
                const SizedBox(height: 32),
                _buildSectionHeader("Academic Distribution"),
                const SizedBox(height: 16),
                _buildDataAnalysisSection(
                  title: "Faculty Breakdown",
                  badgeText: "Total Degrees: ${data['faculty_degrees'].values.fold(0, (a, b) => a + (b as int))}",
                  dataMap: data['faculty_degrees'],
                ),
                
                const SizedBox(height: 32),
                _buildSectionHeader("Community Hub Analysis"),
                const SizedBox(height: 16),
                _buildDataAnalysisSection(
                  title: "Post Categories",
                  badgeText: "Total Posts: ${data['category_counts'].values.fold(0, (a, b) => a + (b as int))}",
                  dataMap: data['category_counts'],
                ),
                
                const SizedBox(height: 32),
                _buildSectionHeader("Communication & Updates"),
                const SizedBox(height: 16),
                _buildBottomMetricsGrid(data),
                
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  Widget _buildTopMetricsGrid(Map<String, dynamic> data) {
    int totalFaculties = (data['faculty_degrees'] as Map).length;
    int totalDegrees = (data['faculty_degrees'] as Map).values.fold(0, (a, b) => a + (b as int));

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: [
        _metricCard("Total Students", data['users'], Icons.people, Colors.blue),
        _metricCard("Total Faculties", totalFaculties, Icons.account_balance, Colors.indigo),
        _metricCard("Total Degrees", totalDegrees, Icons.workspace_premium, Colors.teal),
        _metricCard("Lecturers", data['lecturers'], Icons.co_present, Colors.pink),
        _metricCard("Batches", data['batches'], Icons.grid_view_rounded, Colors.orange),
        _metricCard("Modules", data['subjects'], Icons.book, Colors.cyan), 
      ],
    );
  }

  Widget _buildBottomMetricsGrid(Map<String, dynamic> data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      children: [
        _metricCard("Announcements", data['announcements'], Icons.campaign, Colors.redAccent),
        _metricCard("News Published", data['news'], Icons.newspaper, Colors.green),
        _metricCard("Event Posts", data['events'], Icons.event_available, Colors.purple),
      ],
    );
  }

  Widget _metricCard(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 35),
          const SizedBox(width: 20),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Color.fromARGB(255, 74, 74, 74), fontSize: 14)),
              Text("$value", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDataAnalysisSection({
    required String title, 
    required String badgeText, 
    required Map<String, int> dataMap
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    _totalBadge(badgeText),
                  ],
                ),
                const SizedBox(height: 20),
                ...dataMap.entries.map((e) {
                  int index = dataMap.keys.toList().indexOf(e.key);
                  Color indicatorColor = Colors.primaries[index % Colors.primaries.length];
                  return _identifiedRow(e.key, "${e.value}", indicatorColor);
                }).toList(),
              ],
            ),
          ),
          const SizedBox(width: 40),
          Expanded(flex: 1, child: _pieChartWrapper(dataMap)),
        ],
      ),
    );
  }

  Widget _identifiedRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15, color: Colors.black87)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _totalBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
    );
  }

  Widget _pieChartWrapper(Map<String, int> dataMap) {
    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          centerSpaceRadius: 50,
          sectionsSpace: 2,
          sections: dataMap.entries.map((e) {
            int index = dataMap.keys.toList().indexOf(e.key);
            return PieChartSectionData(
              color: Colors.primaries[index % Colors.primaries.length],
              value: e.value.toDouble(),
              title: '${e.value}',
              radius: 55,
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final List<dynamic> results = await Future.wait([
      _db.collection('users').count().get(),
      _db.collection('batches').count().get(),
      _db.collection('subjects').count().get(), 
      _db.collection('lecturers').count().get(),
      _db.collection('posts').get(),
      _db.collection('degrees').get(),
      _db.collection('news_updates').count().get(),
      _db.collection('events').count().get(),
      _db.collection('announcements').count().get(),
    ]);

    Map<String, int> categoryCounts = {};
    for (var doc in (results[4] as QuerySnapshot).docs) {
      String cat = doc.get('category') ?? 'General';
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }

    Map<String, int> facultyDegrees = {};
    for (var doc in (results[5] as QuerySnapshot).docs) {
      String facultyName = doc.get('faculty') ?? 'Other';
      facultyDegrees[facultyName] = (facultyDegrees[facultyName] ?? 0) + 1;
    }

    return {
      'users': (results[0] as AggregateQuerySnapshot).count ?? 0,
      'batches': (results[1] as AggregateQuerySnapshot).count ?? 0,
      'subjects': (results[2] as AggregateQuerySnapshot).count ?? 0,
      'lecturers': (results[3] as AggregateQuerySnapshot).count ?? 0,
      'category_counts': categoryCounts,
      'faculty_degrees': facultyDegrees,
      'news': (results[6] as AggregateQuerySnapshot).count ?? 0,
      'events': (results[7] as AggregateQuerySnapshot).count ?? 0,
      'announcements': (results[8] as AggregateQuerySnapshot).count ?? 0,
    };
  }
}
