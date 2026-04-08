import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'dart:typed_data'; 
import '../theme.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

enum TargetMode { all, group, specific }

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  TargetMode _selectedMode = TargetMode.all;
  List<Map<String, dynamic>> _recipientsList = [];
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  List<String> _batches = [];
  List<String> _faculties = [];
  List<Map<String, dynamic>> _allDegreesRaw = []; 
  bool _isInitialLoading = true;

  String? _selectedBatch;
  String? _selectedFaculty;
  String? _selectedDegree;

  File? _imageFile; 
  Uint8List? _webImageBytes; 
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _recipientsList.add({'type': 'all', 'label': 'All Students'});
    _preloadData();
  }

  Future<void> _preloadData() async {
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('batches').orderBy('name').get(),
        FirebaseFirestore.instance.collection('faculties').orderBy('name').get(),
        FirebaseFirestore.instance.collection('degrees').orderBy('name').get(),
      ]);

      setState(() {
        _batches = results[0].docs.map((doc) => doc['name'].toString()).toList();
        _faculties = results[1].docs.map((doc) => doc['name'].toString()).toList();
        _allDegreesRaw = results[2].docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        _isInitialLoading = false;
      });
    } catch (e) {
      _showSnackBar("Error loading metadata: $e", Colors.red);
    }
  }

  void _changeMode(TargetMode? mode) {
    if (mode == null) return;
    setState(() {
      _selectedMode = mode;
      _recipientsList.clear();
      _selectedBatch = null;
      _selectedFaculty = null;
      _selectedDegree = null;
      if (mode == TargetMode.all) {
        _recipientsList.add({'type': 'all', 'label': 'All Students'});
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() => _webImageBytes = bytes);
      } else {
        setState(() => _imageFile = File(pickedFile.path));
      }
    }
  }

  void _addGroup() {
    if (_selectedBatch == null || _selectedFaculty == null) {
      _showSnackBar("Please select Batch and Faculty", Colors.orange);
      return;
    }

    String batchVal = _selectedBatch ?? "All Batches";
    String facultyVal = _selectedFaculty ?? "All Faculties";
    String degreeVal = _selectedDegree ?? "All Degrees";

    String label = "$batchVal - $facultyVal - $degreeVal";

    if (_recipientsList.any((item) => item['label'] == label)) return;

    setState(() {
      _recipientsList.add({
        'type': 'group',
        'batch': batchVal,
        'faculty': facultyVal,
        'degree': degreeVal, 
        'label': label,
      });
    });
  }

  Future<void> _sendAnnouncement() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty || _recipientsList.isEmpty) {
      _showSnackBar("Please fill all details and add recipients", Colors.red);
      return;
    }
    setState(() => _isSending = true);
    try {
      String? imageUrl;
      final storageRef = FirebaseStorage.instance.ref().child('announcements/${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (kIsWeb && _webImageBytes != null) {
        await storageRef.putData(_webImageBytes!);
        imageUrl = await storageRef.getDownloadURL();
      } else if (_imageFile != null) {
        await storageRef.putFile(_imageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }
      await FirebaseFirestore.instance.collection('announcements').add({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'image_url': imageUrl,
        'mode': _selectedMode.name,
        'recipients': _recipientsList,
        'timestamp': FieldValue.serverTimestamp(),
        'read_by': [],
      });
      _showSnackBar("Announcement Sent Successfully", Colors.green);
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _imageFile = null;
        _webImageBytes = null;
        _changeMode(TargetMode.all);
      });
    } catch (e) {
      _showSnackBar("Error: $e", Colors.red);
    }
    setState(() => _isSending = false);
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildModeSelector(),
            const SizedBox(height: 20),
            _buildTargetingInterface(),
            const SizedBox(height: 20),
            _buildRecipientsPreview(),
            const Divider(height: 40),
            _buildMessageComposer(),
            const SizedBox(height: 30),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Column(
      children: [
        RadioListTile<TargetMode>(
          title: const Text("Send to All Students"),
          value: TargetMode.all,
          groupValue: _selectedMode,
          onChanged: _changeMode,
          activeColor: AppColors.primary,
        ),
        RadioListTile<TargetMode>(
          title: const Text("Send to Specific Groups"),
          value: TargetMode.group,
          groupValue: _selectedMode,
          onChanged: _changeMode,
          activeColor: AppColors.primary,
        ),
        RadioListTile<TargetMode>(
          title: const Text("Send to Specific Individuals"),
          value: TargetMode.specific,
          groupValue: _selectedMode,
          onChanged: _changeMode,
          activeColor: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildTargetingInterface() {
    if (_selectedMode == TargetMode.all) return const SizedBox();

    if (_selectedMode == TargetMode.group) {
      List<String> filteredDegrees = _allDegreesRaw
          .where((d) => d['faculty'] == _selectedFaculty)
          .map((d) => d['name'].toString())
          .toList();

      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              hint: const Text("Select Batch"),
              value: _selectedBatch,
              items: ["All Batches", ..._batches].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
              onChanged: (v) => setState(() => _selectedBatch = v),
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              hint: const Text("Select Faculty"),
              value: _selectedFaculty,
              items: ["All Faculties", ..._faculties].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (v) => setState(() {
                _selectedFaculty = v;
                _selectedDegree = "All Degrees"; 
              }),
              decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedFaculty), 
              hint: const Text("Select Degree"),
              value: _selectedDegree,
              items: (_selectedFaculty == null || _selectedFaculty == "All Faculties")
                ? [const DropdownMenuItem(value: "All Degrees", child: Text("All Degrees"))]
                : ["All Degrees", ...filteredDegrees].map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
              onChanged: (v) => setState(() => _selectedDegree = v),
              decoration: const InputDecoration(
                border: OutlineInputBorder(), 
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.group_add),
              label: const Text("Add Group to Recipients"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            )
          ],
        ),
      );
    }

    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: "Search Student by Name or ID...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_searchController.text.isNotEmpty) _buildSearchResults(),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Container(
      height: 250,
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final query = _searchController.text.toLowerCase();
          final results = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final fullName = "${data['first_name'] ?? ''} ${data['last_name'] ?? ''}".toLowerCase();
            final studentId = (data['student_id'] ?? "").toString().toLowerCase();
            return fullName.contains(query) || studentId.contains(query);
          }).toList();
          if (results.isEmpty) return const Center(child: Text("No students found"));
          return ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, index) {
              var user = results[index].data() as Map<String, dynamic>;
              String sid = user['student_id'].toString();
              return ListTile(
                title: Text("${user['first_name']} ${user['last_name']}"),
                subtitle: Text("ID: $sid"),
                trailing: ElevatedButton(
                  onPressed: () {
                    if (!_recipientsList.any((r) => r['label'] == sid)) {
                      setState(() => _recipientsList.add({'type': 'individual', 'uid': results[index].id, 'label': sid}));
                    }
                  },
                  child: const Text("Add"),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRecipientsPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Recipient List:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: _recipientsList.map((item) => InputChip(
            label: Text(item['label']),
            onDeleted: _selectedMode == TargetMode.all ? null : () => setState(() => _recipientsList.remove(item)),
            deleteIconColor: Colors.red,
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildMessageComposer() {
    return Column(
      children: [
        TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Announcement Title", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        TextField(controller: _bodyController, maxLines: 5, decoration: const InputDecoration(labelText: "Message Body", border: OutlineInputBorder())),
        const SizedBox(height: 15),
        Row(
          children: [
            OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.image), label: const Text("Attach Image")),
            const SizedBox(width: 15),
            if (kIsWeb ? _webImageBytes != null : _imageFile != null) 
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb 
                      ? Image.memory(_webImageBytes!, width: 60, height: 60, fit: BoxFit.cover)
                      : Image.file(_imageFile!, width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  Positioned(right: -5, top: -5, child: GestureDetector(onTap: () => setState(() { _imageFile = null; _webImageBytes = null; }), child: const Icon(Icons.cancel, color: Colors.red, size: 22))),
                ],
              )
          ],
        )
      ],
    );
  }

  Widget _buildSendButton() {
    return ElevatedButton(
      onPressed: _isSending ? null : _sendAnnouncement,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSending ? const CircularProgressIndicator(color: Colors.white) : const Text("SEND ANNOUNCEMENT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
