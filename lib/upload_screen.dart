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

String _docTypeLabel(DocumentType type) {
  switch (type) {
    case DocumentType.itr:
      return 'ITR';
    case DocumentType.bankStatement:
      return 'Bank\nStatement';
    case DocumentType.insurance:
      return 'Insurance\nDocument';
    case DocumentType.mutualFundCAS:
      return 'Mutual Fund\nCAS';
  }
}

String _docTypeSubtitle(DocumentType type) {
  switch (type) {
    case DocumentType.itr:
      return 'Income Tax Return';
    case DocumentType.bankStatement:
      return 'Recent 6-12 months';
    case DocumentType.insurance:
      return 'Life or Health policy';
    case DocumentType.mutualFundCAS:
      return 'Consolidated Account Statement';
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

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  // Each document type has an optional uploaded document
  final Map<DocumentType, UploadDocument?> _documents = {
    DocumentType.itr: null,
    DocumentType.bankStatement: null,
    DocumentType.insurance: null,
    DocumentType.mutualFundCAS: null,
  };

  bool _isLoading = false;
  String _message = '';
  String? _downloadUrl;
  String? _cachedPdfPath;
  int? _questionnaireId;
  bool _disclaimerShown = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _questionnaireId = widget.questionnaireId;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    // Show disclaimer popup after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disclaimerShown) {
        _showDisclaimerDialog();
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Disclaimer Dialog
  // ---------------------------------------------------------------------------

  void _showDisclaimerDialog() {
    _disclaimerShown = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          backgroundColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shield icon
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.tertiarySage.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        size: 32,
                        color: AppTheme.tertiarySage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Your Privacy Matters',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(child: AppTheme.goldAccentBar(width: 60, height: 2)),
                  const SizedBox(height: 24),

                  // Bullet points
                  _disclaimerBullet(
                    ctx,
                    Icons.lock_outline,
                    'Your documents are not stored by us.',
                  ),
                  const SizedBox(height: 12),
                  _disclaimerBullet(
                    ctx,
                    Icons.sync_outlined,
                    'They are processed once to extract financial data, then immediately deleted.',
                  ),
                  const SizedBox(height: 12),
                  _disclaimerBullet(
                    ctx,
                    Icons.check_circle_outline,
                    'You can skip any document type — just leave its slot empty.',
                  ),
                  const SizedBox(height: 12),
                  _disclaimerBullet(
                    ctx,
                    Icons.edit_note_outlined,
                    'You can also skip uploads entirely and fill in your details manually in the questionnaire.',
                  ),

                  const SizedBox(height: 32),

                  // Buttons
                  LayoutBuilder(
                    builder: (ctx2, constraints) {
                      final skipBtn = SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _skipUpload();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMedium,
                            side: BorderSide(
                              color: AppTheme.borderLight.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          child: const FittedBox(child: Text('Skip & Fill Manually')),
                        ),
                      );
                      final continueBtn = SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _animController.forward();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          child: const FittedBox(child: Text('Continue to Upload')),
                        ),
                      );

                      if (constraints.maxWidth < 360) {
                        return Column(
                          children: [
                            continueBtn,
                            const SizedBox(height: 12),
                            skipBtn,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: skipBtn),
                          const SizedBox(width: 16),
                          Expanded(child: continueBtn),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _disclaimerBullet(BuildContext ctx, IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.accentGold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              ctx,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Skip upload entirely
  // ---------------------------------------------------------------------------

  void _skipUpload() {
    if (widget.onUploaded != null) {
      widget.onUploaded!(null, null);
    }
  }

  // ---------------------------------------------------------------------------
  // Questionnaire start helper
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // File picking — picks a file for a specific document type slot
  // ---------------------------------------------------------------------------

  Future<void> _pickFileForType(DocumentType type) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.isNotEmpty) {
      String fileName = result.files.first.name;
      if (kIsWeb) {
        Uint8List? fileBytes = result.files.first.bytes;
        if (fileBytes != null) {
          setState(() {
            _documents[type] = UploadDocument(
              fileName: fileName,
              fileBytes: fileBytes,
              type: type,
              displayName: fileName,
            );
          });
        }
      } else {
        File file = File(result.files.single.path!);
        setState(() {
          _documents[type] = UploadDocument(
            fileName: fileName,
            file: file,
            type: type,
            displayName: fileName,
          );
        });
      }
    }
  }

  void _removeDocument(DocumentType type) {
    setState(() {
      _documents[type] = null;
    });
  }

  // ---------------------------------------------------------------------------
  // Submit all non-null documents
  // ---------------------------------------------------------------------------

  Future<void> _submitAll() async {
    if (_questionnaireId == null) {
      await _ensureQuestionnaireStarted();
      if (_questionnaireId == null) return;
    }

    final filledDocs =
        _documents.entries.where((e) => e.value != null).toList();
    if (filledDocs.isEmpty) {
      setState(() {
        _message = 'Please upload at least one document, or skip to fill manually.';
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

      if (_questionnaireId != null) {
        request.fields['questionnaireId'] = _questionnaireId.toString();
      }

      int idx = 0;
      for (final entry in filledDocs) {
        final doc = entry.value!;
        final fieldName = 'file$idx';
        final typeField = 'type$idx';
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
        idx++;
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        print('[UploadScreen] Upload response body: $responseBody');
        final data = jsonDecode(responseBody);
        final int? returnedQid =
            (data['questionnaire_id'] is int)
                ? data['questionnaire_id'] as int
                : _questionnaireId;
        print('[UploadScreen] Returned questionnaire ID: $returnedQid');
        final Map<String, dynamic>? prefill =
            (data['prefill'] is Map<String, dynamic>)
                ? (data['prefill'] as Map<String, dynamic>)
                : {
                  if (data['analysis'] != null) 'analysis': data['analysis'],
                  if (data['docInsights'] != null)
                    'docInsights': data['docInsights'],
                };
        print('[UploadScreen] Prefill data to pass: $prefill');
        print('[UploadScreen] Prefill keys: ${prefill?.keys.toList()}');
        setState(() {
          _downloadUrl = data['summary_pdf_url'];
          _message = 'Documents uploaded successfully. PDF ready for download.';
          _questionnaireId = returnedQid ?? _questionnaireId;
        });
        if (widget.onUploaded != null) {
          print(
            '[UploadScreen] Calling onUploaded callback with qid: $returnedQid, prefill: $prefill',
          );
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  int get _filledCount =>
      _documents.values.where((d) => d != null).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundCream,
      body: FadeTransition(
        opacity: _fadeIn,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDocumentGrid(context),
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
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

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
            'Upload the documents you have. You can skip any slot — only upload what\'s available.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2×2 Document Grid
  // ---------------------------------------------------------------------------

  Widget _buildDocumentGrid(BuildContext context) {
    final types = [
      DocumentType.itr,
      DocumentType.bankStatement,
      DocumentType.insurance,
      DocumentType.mutualFundCAS,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use 2 columns on wide screens, 1 column on narrow
        final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
        final spacing = 20.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
            crossAxisCount;
        final cardHeight = 200.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: types.map((type) {
            return SizedBox(
              width: crossAxisCount == 1
                  ? constraints.maxWidth
                  : cardWidth,
              height: cardHeight,
              child: _buildDocumentCard(context, type),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDocumentCard(BuildContext context, DocumentType type) {
    final doc = _documents[type];
    final isFilled = doc != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isFilled
              ? AppTheme.accentGold
              : AppTheme.borderLight.withValues(alpha: 0.4),
          width: isFilled ? 2 : 1,
        ),
        boxShadow: isFilled
            ? [
              BoxShadow(
                color: AppTheme.accentGold.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: _isLoading
              ? null
              : () {
                  if (isFilled) {
                    // Already has a file — show options
                    _showReplaceRemoveMenu(context, type);
                  } else {
                    _pickFileForType(type);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: isFilled
                ? _buildFilledCard(context, type, doc)
                : _buildEmptyCard(context, type),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, DocumentType type) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppTheme.backgroundCream,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppTheme.borderLight.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.add_rounded,
            size: 28,
            color: AppTheme.accentGold,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _docTypeLabel(type),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryNavy,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _docTypeSubtitle(type),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'TAP TO UPLOAD',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.accentGold,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFilledCard(
    BuildContext context,
    DocumentType type,
    UploadDocument doc,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Success icon
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.successGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 26,
            color: AppTheme.successGreen,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _docTypeLabel(type).replaceAll('\n', ' '),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppTheme.primaryNavy,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        // Filename
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 14,
              color: AppTheme.errorRed.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                doc.fileName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMedium,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Replace / Remove hint
        Text(
          'TAP TO REPLACE OR REMOVE',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppTheme.textLight,
            letterSpacing: 1.0,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  void _showReplaceRemoveMenu(BuildContext context, DocumentType type) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.swap_horiz,
                    color: AppTheme.primaryNavy,
                  ),
                  title: Text(
                    'Replace with a different file',
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickFileForType(type);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: AppTheme.errorRed.withValues(alpha: 0.8),
                  ),
                  title: Text(
                    'Remove this document',
                    style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.errorRed.withValues(alpha: 0.8),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeDocument(type);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Action Buttons
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Upload summary
        if (_filledCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '$_filledCount of 4 documents added — you can submit now or add more.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textLight,
              ),
            ),
          ),

        // Submit button
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
              onPressed: _filledCount > 0 ? _submitAll : null,
              icon: const Icon(Icons.cloud_upload, size: 20),
              label: Text(
                _filledCount > 0
                    ? 'Submit ${_filledCount == 1 ? "1 Document" : "$_filledCount Documents"}'
                    : 'Submit Documents',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Skip button
        SizedBox(
          height: 44,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _skipUpload,
            icon: const Icon(Icons.skip_next_outlined, size: 20),
            label: const Text('Skip & Fill Details Manually'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textLight,
            ),
          ),
        ),

        // Download PDF button (if available)
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
                _cachedPdfPath != null
                    ? 'Open Summary PDF'
                    : 'Download Summary PDF',
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

  // ---------------------------------------------------------------------------
  // Status message
  // ---------------------------------------------------------------------------

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
