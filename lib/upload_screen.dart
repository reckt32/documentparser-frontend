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
import 'package:frontend/constants.dart';
import 'package:frontend/app_theme.dart';

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
  final void Function(int? questionnaireId, Map<String, dynamic>? prefill)?
  onUploaded;
  const UploadScreen({Key? key, this.questionnaireId, this.onUploaded})
    : super(key: key);

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final List<UploadDocument> _documents = [];
  bool _isLoading = false;
  String _message = '';
  String? _downloadUrl;
  String? _cachedPdfPath;
  int? _questionnaireId;

  @override
  void initState() {
    super.initState();
    _questionnaireId = widget.questionnaireId;
  }

  Future<void> _ensureQuestionnaireStarted() async {
    if (_questionnaireId != null) return;
    setState(() {
      _isLoading = true;
      _message = 'Starting questionnaire...';
    });
    try {
      final resp = await http.post(
        Uri.parse('$kBackendUrl/questionnaire/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': 'user'}),
      );
      if (resp.statusCode == 201) {
        final data = jsonDecode(resp.body);
        final id = data['questionnaire_id'] as int;
        setState(() {
          _questionnaireId = id;
          _message = 'Questionnaire started (ID $id). Proceed to upload.';
        });
      } else {
        setState(() {
          _message = 'Failed to start questionnaire: ${resp.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error starting questionnaire: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                items:
                    DocumentType.values
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
                        displayName:
                            nameCtrl.text.trim().isEmpty
                                ? doc.fileName
                                : nameCtrl.text.trim(),
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
    // Ensure a questionnaire is started so uploads link correctly and prefill is computed
    if (_questionnaireId == null) {
      await _ensureQuestionnaireStarted();
      if (_questionnaireId == null) {
        // Starting questionnaire failed; abort to avoid orphan uploads
        return;
      }
    }
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
      _cachedPdfPath = null;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$kBackendUrl/upload'),
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
        // Try to forward prefill to questionnaire if available (when questionnaireId was attached)
        final int? returnedQid =
            (data['questionnaire_id'] is int)
                ? data['questionnaire_id'] as int
                : _questionnaireId;
        // Prefer backend-provided prefill (contains lifestyle/allocation/insurance)
        // Fallback to analysis/docInsights only if prefill is absent.
        final Map<String, dynamic>? prefill =
            (data['prefill'] is Map<String, dynamic>)
                ? (data['prefill'] as Map<String, dynamic>)
                : {
                  if (data['analysis'] != null) 'analysis': data['analysis'],
                  if (data['docInsights'] != null)
                    'docInsights': data['docInsights'],
                };
        // Update local UI state
        setState(() {
          _downloadUrl = data['summary_pdf_url'];
          _message = 'Documents uploaded successfully. PDF ready for download.';
          _questionnaireId = returnedQid ?? _questionnaireId;
        });
        // Notify parent to navigate to Questionnaire with prefill
        if (widget.onUploaded != null) {
          widget.onUploaded!(returnedQid, prefill);
        }
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

    // If we have a cached PDF, open it directly
    if (_cachedPdfPath != null && !kIsWeb) {
      final cachedFile = File(_cachedPdfPath!);
      if (await cachedFile.exists()) {
        setState(() {
          _message = 'Opening cached PDF...';
        });
        await OpenFilex.open(_cachedPdfPath!);
        setState(() {
          _message = 'PDF opened from cache.';
        });
        return;
      } else {
        // Cache file was deleted, clear the cached path
        setState(() {
          _cachedPdfPath = null;
        });
      }
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
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filePath = '${directory.path}/summary_$timestamp.pdf';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          setState(() {
            _cachedPdfPath = filePath;
            _message = 'PDF downloaded to: $filePath';
          });

          await OpenFilex.open(filePath);
        } else if (response.statusCode == 404) {
          setState(() {
            _downloadUrl = null;
            _message =
                'PDF no longer available. Please upload documents again to generate a new PDF.';
          });
        } else {
          setState(() {
            _message =
                'Failed to download PDF: ${response.statusCode}, ${response.reasonPhrase}';
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
      backgroundColor: AppTheme.backgroundCream,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header section
            _buildHeader(context),
            // Content section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_documents.isEmpty) _buildEmptyState(context),
                  if (_documents.isNotEmpty) _buildDocumentList(context),
                  const SizedBox(height: 32),
                  _buildActionButtons(context),
                  if (_message.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildStatusMessage(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DOCUMENT UPLOAD',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppTheme.accentGold,
                  letterSpacing: 2.0,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload Financial Documents',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppTheme.primaryNavy,
                ),
          ),
          const SizedBox(height: 8),
          AppTheme.goldAccentBar(width: 80, height: 2),
          const SizedBox(height: 16),
          Text(
            'Select and categorize each document before submitting all together.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(60),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppTheme.borderLight.withValues(alpha: 0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          // Outlined icon box
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.accentGold,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(
              Icons.upload_file_outlined,
              size: 48,
              color: AppTheme.accentGold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No documents added yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.primaryNavy,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'Click the button below to add financial documents',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textLight,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList(BuildContext context) {
    return Column(
      children: [
        for (int index = 0; index < _documents.length; index++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: AppTheme.borderLight.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: AppTheme.errorRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _documents[index].displayName ?? _documents[index].fileName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.primaryNavy,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _documents[index].type != null
                            ? documentTypeToString(_documents[index].type!)
                            : 'No type selected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _documents[index].type != null
                                  ? AppTheme.textLight
                                  : AppTheme.errorRed,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.textLight,
                  onPressed: _isLoading ? null : () => _removeDocument(index),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _pickFile,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Document'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primaryNavy,
              side: BorderSide(
                color: AppTheme.borderLight.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primaryNavy.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _documents.isNotEmpty ? _submitAll : null,
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: const Text('Submit All Documents'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        if (_downloadUrl != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _downloadPdf,
              icon: Icon(
                _cachedPdfPath != null ? Icons.open_in_new : Icons.download,
                size: 20,
              ),
              label: Text(
                _cachedPdfPath != null ? 'Open Summary PDF' : 'Download Summary PDF',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentGold,
                foregroundColor: AppTheme.primaryNavy,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusMessage(BuildContext context) {
    final isError = _message.contains('Error') || _message.contains('Failed');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isError ? AppTheme.errorRed : AppTheme.successGreen)
            .withValues(alpha: 0.1),
        border: Border(
          left: BorderSide(
            color: isError ? AppTheme.errorRed : AppTheme.successGreen,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppTheme.errorRed : AppTheme.successGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isError ? AppTheme.errorRed : AppTheme.successGreen,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
