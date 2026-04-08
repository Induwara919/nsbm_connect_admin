import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:nsbm_connect_admin/theme.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<dynamic>> _events = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Converts DateTime to the "26/3/2026" string format used in your DB
  String _formatDate(DateTime date) => "${date.day}/${date.month}/${date.year}";

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _events = {};
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            String dateKey = data['date'] ?? "";
            if (_events[dateKey] == null) _events[dateKey] = [];
            // Add docId to data so we can edit/delete later
            data['docId'] = doc.id;
            _events[dateKey]!.add(data);
          }
        }

        return Row(
          children: [
            // LEFT SIDE: THE CALENDAR
            Expanded(
              flex: 2,
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey.shade200)),
                child: Column(
                  children: [
                    TableCalendar(
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
                      eventLoader: (day) => _events[_formatDate(day)] ?? [],
                      calendarStyle: CalendarStyle(
                        markerDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      ),
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddEventDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text("Add New Event"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // RIGHT SIDE: EVENT LIST
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Events for ${DateFormat('MMMM dd, yyyy').format(_selectedDay!)}",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _buildEventList(_formatDate(_selectedDay!)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEventList(String dateKey) {
    List<dynamic> dayEvents = _events[dateKey] ?? [];
    if (dayEvents.isEmpty) {
      return Center(child: Text("No events scheduled for this day.", style: TextStyle(color: Colors.grey.shade400)));
    }

    return ListView.builder(
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        var event = dayEvents[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(event['image'], width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image)),
            ),
            title: Text(event['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${event['start_time']} - ${event['location']}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showAddEventDialog(existingEvent: event)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteEvent(event['docId'], event['image'])),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- ADD / EDIT DIALOG ---
  void _showAddEventDialog({Map<String, dynamic>? existingEvent}) async {
    final titleCtrl = TextEditingController(text: existingEvent?['title'] ?? "");
    final descCtrl = TextEditingController(text: existingEvent?['description'] ?? "");
    final locCtrl = TextEditingController(text: existingEvent?['location'] ?? "");
    final startCtrl = TextEditingController(text: existingEvent?['start_time'] ?? "");
    final endCtrl = TextEditingController(text: existingEvent?['end_time'] ?? "");
    
    Uint8List? webImage;
    String? imageUrl = existingEvent?['image'];
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existingEvent == null ? "Schedule Event" : "Edit Event"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // IMAGE PREVIEW & PICKER (FIXED FOR WEB)
                  GestureDetector(
                    onTap: () async {
                        // 1. Initialize the picker outside the try/catch if possible, 
                        // or right at the top to ensure "User Activation" is fresh.
                        final ImagePicker picker = ImagePicker();
                        
                        try {
                          // 2. Immediate call to the browser's file system
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                          );

                          if (image == null) return; // User cancelled

                          // 3. Read bytes immediately
                          final Uint8List bytes = await image.readAsBytes();
                          
                          setDialogState(() {
                            webImage = bytes;
                          });
                        } catch (e) {
                          // This will tell us the EXACT error in the debug console
                          print("DEBUG: Image Picker Failed -> $e");
                          _showStatus("Gallery blocked by browser. Check console for details.", isError: true);
                        }
                      },
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[300]!)),
                      child: webImage != null 
                        ? Image.memory(webImage!, fit: BoxFit.cover) 
                        : (imageUrl != null ? Image.network(imageUrl!, fit: BoxFit.cover) : const Icon(Icons.add_a_photo, size: 40, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Event Title")),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
                  TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "Location")),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: startCtrl, decoration: const InputDecoration(labelText: "Start Time (e.g. 09:00 AM)"))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: endCtrl, decoration: const InputDecoration(labelText: "End Time"))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: isUploading ? null : () async {
                setDialogState(() => isUploading = true);
                try {
                  // 1. Upload image if new one selected (Using putData for Web)
                  if (webImage != null) {
                    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
                    Reference ref = FirebaseStorage.instance.ref().child('event_images/$fileName.jpg');
                    await ref.putData(webImage!);
                    imageUrl = await ref.getDownloadURL();
                  }

                  // 2. Prepare Data
                  Map<String, dynamic> eventData = {
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'location': locCtrl.text,
                    'start_time': startCtrl.text,
                    'end_time': endCtrl.text,
                    'date': _formatDate(_selectedDay!),
                    'image': imageUrl,
                  };

                  // 3. Save to Firestore
                  if (existingEvent == null) {
                    await FirebaseFirestore.instance.collection('events').add(eventData);
                  } else {
                    await FirebaseFirestore.instance.collection('events').doc(existingEvent['docId']).update(eventData);
                  }

                  Navigator.pop(context);
                  _showStatus("Event Saved Successfully!");
                } catch (e) {
                  setDialogState(() => isUploading = false);
                  _showStatus("Error: $e", isError: true);
                }
              },
              child: isUploading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)) : const Text("Save Event"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, // Button Background Color
                foregroundColor: Colors.white,      // Text and Icon Color
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // Optional: matches your admin panel style
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEvent(String docId, String imgUrl) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Event?"),
        content: const Text("This will permanently remove the event and its image."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("Delete")),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('events').doc(docId).delete();
      try { await FirebaseStorage.instance.refFromURL(imgUrl).delete(); } catch (_) {}
      _showStatus("Event deleted.");
    }
  }

  void _showStatus(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.red : AppColors.primary));
  }
}
