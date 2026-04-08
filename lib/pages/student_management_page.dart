import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nsbm_connect_admin/theme.dart';

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _isEditing = false; 

  void _showStatus(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        width: 400,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Registered Students",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(
              width: 350,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search by ID, Name or NIC...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Error loading data"));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var docs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                String query = _searchQuery.toLowerCase();
                return (data['student_id']?.toString().toLowerCase() ?? "").contains(query) ||
                    (data['first_name']?.toString().toLowerCase() ?? "").contains(query) ||
                    (data['last_name']?.toString().toLowerCase() ?? "").contains(query) ||
                    (data['surname']?.toString().toLowerCase() ?? "").contains(query) ||
                    (data['nic']?.toString().toLowerCase() ?? "").contains(query);
              }).toList();

              return Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                    columns: const [
                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Faculty', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Degree', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: docs.map((doc) {
                      var data = doc.data() as Map<String, dynamic>;
                      String fullName = "${data['initials'] ?? ''} ${data['first_name'] ?? ''} ${data['last_name'] ?? ''} ${data['surname'] ?? ''}";

                      return DataRow(cells: [
                        DataCell(Text(data['student_id'] ?? "N/A")),
                        DataCell(Text(fullName)),
                        DataCell(Text(data['batch'] ?? "N/A")),
                        DataCell(Text(data['faculty'] ?? "N/A")),
                        DataCell(Text(data['degree'] ?? "N/A")),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, color: Colors.blue),
                                tooltip: 'View Profile',
                                onPressed: () => _viewDetails(doc.id, data),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                tooltip: 'Delete Student',
                                onPressed: () => _deleteStudent(doc.id),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _viewDetails(String docId, Map<String, dynamic> data) {
    _isEditing = false;
    final Map<String, TextEditingController> controllers = {};

    final excludedKeys = ['email', 'created_at', 'updated_at', 'saved_posts', 'profile_pic'];

    data.forEach((key, value) {
      if (!excludedKeys.contains(key)) {
        controllers[key] = TextEditingController(text: value?.toString() ?? "");
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setPopupState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 800,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: (data['profile_pic'] != null && data['profile_pic'].isNotEmpty)
                                ? NetworkImage(data['profile_pic'])
                                : null,
                            child: (data['profile_pic'] == null || data['profile_pic'].isEmpty)
                                ? const Icon(Icons.person, size: 50, color: Colors.grey)
                                : null,
                          ),
                          if (_isEditing && data['profile_pic'] != null && data['profile_pic'].isNotEmpty)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                backgroundColor: Colors.red,
                                radius: 18,
                                child: IconButton(
                                  icon: const Icon(Icons.no_photography, size: 16, color: Colors.white),
                                  onPressed: () async {
                                    await FirebaseFirestore.instance.collection('users').doc(docId).update({'profile_pic': ""});
                                    setPopupState(() => data['profile_pic'] = "");
                                    _showStatus("Profile picture removed");
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${data['first_name'] ?? ''} ${data['last_name'] ?? ''}",
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            Text("Student ID: ${data['student_id'] ?? ''}", style: const TextStyle(color: Colors.grey)),
                            Text("Email: ${data['email'] ?? ''}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                    ],
                  ),
                  const Divider(height: 40),
                  _buildSectionTitle("Personal Information"),
                  _buildDetailGrid([
                    _editableItem("Initials", "initials", controllers),
                    _editableItem("First Name", "first_name", controllers),
                    _editableItem("Last Name", "last_name", controllers),
                    _editableItem("Surname", "surname", controllers),
                    _editableItem("Student ID", "student_id", controllers),
                    _editableItem("Birthday", "birthday", controllers),
                    _editableItem("Nationality", "nationality", controllers),
                    _editableItem("Religion", "religion", controllers),
                    _editableItem("Phone", "phone", controllers),
                    _editableItem("NIC", "nic", controllers),
                    _editableItem("Address", "address", controllers),
                  ]),
                  const Divider(height: 40),
                  _buildSectionTitle("Academic Details"),
                  _buildDetailGrid([
                    _editableItem("Faculty", "faculty", controllers),
                    _editableItem("Degree", "degree", controllers),
                    _editableItem("Batch", "batch", controllers),
                  ]),
                  const Divider(height: 40),
                  _buildSectionTitle("Family & Guardian Details"),
                  _buildDetailGrid([
                    _editableItem("Father's Name", "father_name", controllers),
                    _editableItem("Mother's Name", "mother_name", controllers),
                    _editableItem("Guardian's Name", "guardian_name", controllers),
                    _editableItem("Guardian Phone 1", "guardian_phone1", controllers),
                    _editableItem("Guardian Phone 2", "guardian_phone2", controllers),
                  ]),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!_isEditing)
                        OutlinedButton.icon(
                          onPressed: () => setPopupState(() => _isEditing = true),
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit Student Data"),
                        )
                      else ...[
                        TextButton(
                          onPressed: () => setPopupState(() => _isEditing = false),
                          child: const Text("Cancel"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          onPressed: () async {
                            try {
                              Map<String, dynamic> updates = {};
                              controllers.forEach((key, controller) => updates[key] = controller.text);
                              await FirebaseFirestore.instance.collection('users').doc(docId).set(updates, SetOptions(merge: true));
                              if (mounted) Navigator.pop(context);
                              _showStatus("Student Data Updated Successfully!");
                            } catch (e) {
                              _showStatus("Update Failed: $e", isError: true);
                            }
                          },
                          child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
                        ),
                      ]
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
    );
  }

  Widget _buildDetailGrid(List<Widget> children) {
    return Wrap(
      spacing: 40,
      runSpacing: 20,
      children: children,
    );
  }

  Widget _editableItem(String label, String key, Map<String, TextEditingController> controllers) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          _isEditing
              ? TextField(
                  controller: controllers[key],
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                )
              : Text(controllers[key]?.text ?? "N/A", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _deleteStudent(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to permanently remove this student? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('users').doc(docId).delete();
                if (mounted) Navigator.pop(context);
                _showStatus("Student record deleted successfully");
              } catch (e) {
                _showStatus("Delete failed: $e", isError: true);
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
