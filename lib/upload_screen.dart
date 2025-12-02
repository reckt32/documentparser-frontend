import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

enum DocumentType { bankStatement, itr, insurance, mutualFundCAS }

String documentTypeToString(DocumentType type) {
  switch (type) {
    case DocumentType.bankStatement:
      return 'Bank statement';
    case DocumentType.itr:
      return 'ITR';
    case DocumentType.insurance:
      return 'Insurance document';
    case DocumentType.mutualFundCAS:
      return 'Mutual fund CAS (Consolidated Account Statement)';
  }
}

class UploadDocument {
  final String fileName;
  final Uint8List? fileBytes; // For web
  final File? file; // For non-web
  DocumentType? type;
  String? displayName; // user-provided name

  UploadDocument({
    required this.fileName,
    this.fileBytes,
    this.file,
    this.type,
    this.displayName,
  });
}

class UploadScreen extends StatefulWidget {
  final int? questionnaireId;
  const UploadScreen({Key? key, this.questionnaireId}) : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<UploadDocument> _documents = [];
  bool _isLoading = false;
  String _message = '';
  String? _downloadUrl;
  int? _questionnaireId;

  final String _backendUrl = 'http://127.0.0.1:5000';

  @override
  void initState() {
    super.initState();
    _questionnaireId = widget.questionnaireId;
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      String fileName = result.files.first.name;
      if (kIsWeb) {
        Uint8List? fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          _showTypeDialog(
            UploadDocument(fileName: fileName, fileBytes: fileBytes),
          );
        }
      } else {
        File file = File(result.files.single.path!);
        _showTypeDialog(UploadDocument(fileName: fileName, file: file));
      }
    }
  }

  void _showTypeDialog(UploadDocument doc) async {
    DocumentType? selectedType;
    final nameCtrl = TextEditingController(text: doc.fileName);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Document Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DocumentType>(
                value: selectedType,
                items: DocumentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(documentTypeToString(type)),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  selectedType = type;
                },
                decoration: const InputDecoration(
                  labelText: 'Document Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Document Name',
                  hintText: 'e.g., HDFC Jan 2025 Statement',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedType != null) {
                  setState(() {
                    _documents.add(
                      UploadDocument(
                        fileName: doc.fileName,
                        fileBytes: doc.fileBytes,
                        file: doc.file,
                        type: selectedType,
                        displayName: nameCtrl.text.trim().isEmpty ? doc.fileName : nameCtrl.text.trim(),
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAll() async {
    if (_documents.isEmpty) {
      setState(() {
        _message = 'Please add at least one document.';
      });
      return;
    }
    if (_documents.any((doc) => doc.type == null)) {
      setState(() {
        _message = 'Please select a type for all documents.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Uploading documents...';
      _downloadUrl = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/upload'),
      );

      // Attach questionnaireId if present
      if (_questionnaireId != null) {
        request.fields['questionnaireId'] = _questionnaireId.toString();
      }

      for (int i = 0; i < _documents.length; i++) {
        final doc = _documents[i];
        final fieldName = 'file$i';
        final typeField = 'type$i';
        if (kIsWeb) {
          request.files.add(
            http.MultipartFile.fromBytes(
              fieldName,
              doc.fileBytes!,
              filename: doc.fileName,
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              fieldName,
              doc.file!.path,
              filename: doc.fileName,
            ),
          );
        }
        request.fields[typeField] = documentTypeToString(doc.type!);
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final data = jsonDecode(responseBody);
        setState(() {
          _downloadUrl = data['summary_pdf_url'];
          _message = 'Documents uploaded successfully. PDF ready for download.';
        });
      } else {
        final errorBody = await response.stream.bytesToString();
        setState(() {
          _message = 'Upload failed: ${response.statusCode} - $errorBody';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error uploading documents: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPdf() async {
    if (_downloadUrl == null) {
      setState(() {
        _message = 'No PDF available for download.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _message = 'Downloading PDF...';
    });

    try {
      if (kIsWeb) {
        await launchUrl(
          Uri.parse(_downloadUrl!),
          mode: LaunchMode.externalApplication,
        );
        setState(() {
          _message = 'PDF download initiated in browser.';
        });
      } else {
        final response = await http.get(Uri.parse(_downloadUrl!));

        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/downloaded_summary.pdf';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            _message = 'PDF downloaded to: $filePath';
          });

          await OpenFilex.open(filePath);
        } else {
          setState(() {
            _message = 'Failed to download PDF: ${response.statusCode}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _message = 'Error downloading PDF: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Document Uploader'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.upload_file, size: 80, color: Colors.deepPurple),
              const SizedBox(height: 20),
              Text(
                'Upload Multiple Financial Documents',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Select and categorize each document before submitting all together.',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickFile,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_documents.isNotEmpty)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(
                          Icons.picture_as_pdf,
                          color: Colors.red,
                        ),
                        title: Text(doc.displayName ?? doc.fileName),
                        subtitle: Text(
                          doc.type != null
                              ? documentTypeToString(doc.type!)
                              : 'No type selected',
                          style: TextStyle(
                            color: doc.type != null ? Colors.black : Colors.red,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed:
                              _isLoading ? null : () => _removeDocument(index),
                        ),
                      ),
                    );
                  },
                ),
              if (_documents.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Text(
                    'No documents added yet.',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                  ),
                ),
              const SizedBox(height: 30),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _documents.isNotEmpty ? _submitAll : null,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Submit All Documents'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (_downloadUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _downloadPdf,
                    icon: const Icon(Icons.download),
                    label: const Text('Download Summary PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              if (_message.isNotEmpty)
                Text(
                  _message,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color:
                        _message.contains('Error') ? Colors.red : Colors.green,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
