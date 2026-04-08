import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:nsbm_connect_admin/theme.dart';

class TimeTablePage extends StatefulWidget {
  const TimeTablePage({super.key});

  @override
  State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  
  String? selectedBatch;
  String? selectedDegree;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  bool showTable = false;

  String _formatDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopFilterBar(),
        const Divider(),
        if (showTable)
          Expanded(
            child: Row(
              children: [
                
                Expanded(
                  flex: 2,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(15)),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      calendarStyle: const CalendarStyle(
                        selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Schedule for ${DateFormat('EEE, MMM dd').format(_selectedDay)}",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _showAddEntryDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text("Add Lecture"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary, 
                                foregroundColor: Colors.white,      
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10), 
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Expanded(child: _buildLectureList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          const Expanded(child: Center(child: Text("Select Batch & Degree to view Timetable"))),
      ],
    );
  }

  Widget _buildTopFilterBar() {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        children: [
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('batches').snapshots(),
              builder: (context, snap) {
                return DropdownButtonFormField<String>(
                  value: selectedBatch,
                  hint: const Text("Select Batch"),
                  items: snap.data?.docs.map((doc) => DropdownMenuItem(value: doc['name'] as String, child: Text(doc['name']))).toList(),
                  onChanged: (v) => setState(() => selectedBatch = v),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('degrees').snapshots(),
              builder: (context, snap) {
                return DropdownButtonFormField<String>(
                  value: selectedDegree,
                  hint: const Text("Select Degree"),
                  items: snap.data?.docs.map((doc) => DropdownMenuItem(value: doc['name'] as String, child: Text(doc['name']))).toList(),
                  onChanged: (v) => setState(() => selectedDegree = v),
                );
              },
            ),
          ),
          const SizedBox(width: 20),
          ElevatedButton(
            onPressed: () {
              if (selectedBatch != null && selectedDegree != null) {
                setState(() => showTable = true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, 
              foregroundColor: Colors.white,    
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10), 
            ),
            child: const Text(
              "Show Timetable",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLectureList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('timetable')
          .where('batch', isEqualTo: selectedBatch)
          .where('degree', isEqualTo: selectedDegree)
          .where('date', isEqualTo: _formatDate(_selectedDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No lectures scheduled."));

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            var data = doc.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(data['subject'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['start_time']} - ${data['end_time']}\nLec: ${data['lecturer']} | Hall: ${data['lecture_hall']}"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEntryDialog(existingDoc: doc)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddEntryDialog({DocumentSnapshot? existingDoc}) async {
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      Map<String, dynamic>? data = existingDoc?.data() as Map<String, dynamic>?;
      
      final startCtrl = TextEditingController(text: data?['start_time'] ?? "");
      final endCtrl = TextEditingController(text: data?['end_time'] ?? "");
      final notesCtrl = TextEditingController(text: data?['notes'] ?? "");
      String? selSub = data?['subject'];
      String? selLec = data?['lecturer'];
      String? selHall = data?['lecture_hall'];

      
      final storageRef = FirebaseStorage.instance.ref().child('metadata/map_navigation.json');
      final bytes = await storageRef.getData();
      
      List<DropdownMenuItem<String>> hallItems = [];

      if (bytes != null) {
        final String jsonString = utf8.decode(bytes);
        final Map<String, dynamic> fullData = json.decode(jsonString);
        
        List<dynamic> floors = fullData['floors'] ?? [];
        Map<String, dynamic> nodes = fullData['nodes'] ?? {};

        for (var floor in floors) {
          
          hallItems.add(DropdownMenuItem(
            enabled: false,
            child: Text(
              floor['name'].toString().toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
            ),
          ));

          var rooms = nodes.keys.where((k) {
            var label = nodes[k]['label'].toString().toLowerCase();
            return nodes[k]['floor'] == floor['id'] && !label.startsWith('p');
          }).toList()..sort();

          for (var roomId in rooms) {
            hallItems.add(DropdownMenuItem(
              value: nodes[roomId]['label'].toString(), 
              child: Text("  ${nodes[roomId]['label']}"),
            ));
          }
        }
      }

      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(existingDoc == null ? "Add Lecture" : "Edit Lecture"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStreamDropdown("subjects", "Select Subject", selSub, (v) => selSub = v),
                  const SizedBox(height: 10),
                  _buildStreamDropdown("lecturers", "Select Lecturer", selLec, (v) => selLec = v),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selHall,
                    hint: const Text("Select Lecture Hall"),
                    items: hallItems,
                    onChanged: (v) => selHall = v,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                  TextField(controller: startCtrl, decoration: const InputDecoration(labelText: "Start Time (e.g. 09:00 AM)")),
                  TextField(controller: endCtrl, decoration: const InputDecoration(labelText: "End Time")),
                  TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: "Lecturer Notes")),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  Map<String, dynamic> entry = {
                    'batch': selectedBatch,
                    'degree': selectedDegree,
                    'date': _formatDate(_selectedDay),
                    'subject': selSub,
                    'lecturer': selLec,
                    'lecture_hall': selHall,
                    'start_time': startCtrl.text,
                    'end_time': endCtrl.text,
                    'notes': notesCtrl.text,
                  };
                  if (existingDoc == null) {
                    await FirebaseFirestore.instance.collection('timetable').add(entry);
                  } else {
                    await existingDoc.reference.update(entry);
                  }
                  if (mounted) Navigator.pop(c);
                },
                child: const Text("Save"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, 
                  foregroundColor: Colors.white,      
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10), 
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error loading hall data: $e")),
      );
    }
  }

  Widget _buildStreamDropdown(String col, String hint, String? val, Function(String?) onChange) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection(col).orderBy('name').snapshots(),
      builder: (context, snap) {
        return DropdownButtonFormField<String>(
          value: val,
          hint: Text(hint),
          items: snap.data?.docs.map((d) => DropdownMenuItem(value: d['name'] as String, child: Text(d['name']))).toList(),
          onChanged: onChange,
        );
      },
    );
  }
}
