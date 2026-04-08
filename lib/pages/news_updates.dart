import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../theme.dart';

class NewsUpdatesPage extends StatefulWidget {
  const NewsUpdatesPage({super.key});

  @override
  State<NewsUpdatesPage> createState() => _NewsUpdatesPageState();
}

class _NewsUpdatesPageState extends State<NewsUpdatesPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('news_updates').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No news updates found."));

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 450,
                    mainAxisExtent: 420,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) => _buildNewsCard(docs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Colors.black12))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("News Articles", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: () => _showEditDialog(context),
            icon: const Icon(Icons.add),
            label: const Text("Add News Update"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewsCard(DocumentSnapshot doc) {
    var data = doc.data() as Map<String, dynamic>;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              data['image_url'], 
              fit: BoxFit.cover,
              cacheWidth: 800, 
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20), maxLines: 1),
                const SizedBox(height: 10),
                Text(data['description'], style: TextStyle(color: Colors.grey[700], fontSize: 14), maxLines: 3),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(context, docId: doc.id, existingData: data),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      onPressed: () => _confirmDelete(doc.id, data['image_url']),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) async {
    final titleController = TextEditingController(text: existingData?['title'] ?? "");
    final descController = TextEditingController(text: existingData?['description'] ?? "");
    final cropController = CropController();
    
    Uint8List? rawBytes;   
    Uint8List? finalBytes; 
    bool isCroppingMode = false;
    bool isProcessing = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(docId == null ? "Create Update" : "Edit Update"),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isCroppingMode && rawBytes != null)
                    Column(
                      children: [
                        Container(
                          height: 350,
                          color: Colors.black,
                          child: Stack(
                            children: [
                              Crop(
                                image: rawBytes!,
                                controller: cropController,
                                aspectRatio: 16 / 9,
                                onCropped: (result) { 
                                  if (result is CropSuccess) {
                                    setDialogState(() {
                                      finalBytes = result.croppedImage;
                                      rawBytes = null; 
                                      isCroppingMode = false;
                                      isProcessing = false;
                                    });
                                  }
                                },
                              ),
                              if (isProcessing)
                                const Center(child: CircularProgressIndicator(color: Colors.white)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: isProcessing ? null : () {
                            setDialogState(() => isProcessing = true);
                            cropController.crop();
                          },
                          child: const Text("Apply Crop Selection"),
                        ),
                      ],
                    )
                  else
                    GestureDetector(
                      onTap: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.image, 
                          withData: true
                        );
                        if (result != null) {
                          setDialogState(() {
                            rawBytes = result.files.first.bytes;
                            isCroppingMode = true;
                          });
                        }
                      },
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200], 
                            borderRadius: BorderRadius.circular(12), 
                            border: Border.all(color: Colors.grey[400]!)
                          ),
                          child: finalBytes != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(finalBytes!, fit: BoxFit.cover))
                              : (existingData?['image_url'] != null
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(existingData!['image_url'], fit: BoxFit.cover))
                                  : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 50))),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController, 
                    maxLength: 30, 
                    decoration: const InputDecoration(labelText: "Headline", border: OutlineInputBorder())
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: descController, 
                    maxLength: 200, 
                    maxLines: 3, 
                    decoration: const InputDecoration(labelText: "Details", border: OutlineInputBorder())
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Cancel")
            ),
            ElevatedButton(
              onPressed: (isSaving || isCroppingMode) ? null : () async {
                if (titleController.text.isEmpty || descController.text.isEmpty) return;

                setDialogState(() => isSaving = true);
                try {
                  String finalUrl = existingData?['image_url'] ?? "";
                  
                  if (finalBytes != null) {
                    String name = "news_${DateTime.now().millisecondsSinceEpoch}.jpg";
                    Reference ref = FirebaseStorage.instance.ref().child('news_updates/$name');
                    await ref.putData(finalBytes!);
                    finalUrl = await ref.getDownloadURL();
                  }

                  final payload = {
                    'title': titleController.text, 
                    'description': descController.text, 
                    'image_url': finalUrl, 
                    'timestamp': FieldValue.serverTimestamp()
                  };
                  
                  if (docId == null) {
                    await _firestore.collection('news_updates').add(payload);
                  } else {
                    await _firestore.collection('news_updates').doc(docId).update(payload);
                  }
                  
                  Navigator.pop(context);
                } catch (e) { 
                  debugPrint(e.toString()); 
                } finally { 
                  if (mounted) setDialogState(() => isSaving = false); 
                }
              },
              child: isSaving 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String url) async {
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("Delete Post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _firestore.collection('news_updates').doc(id).delete();
              try { await FirebaseStorage.instance.refFromURL(url).delete(); } catch (_) {}
              Navigator.pop(context);
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red), 
            child: const Text("Delete", style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
  }
}
