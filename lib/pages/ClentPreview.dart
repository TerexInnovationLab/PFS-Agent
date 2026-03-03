import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import '../layouts/Colors.dart';
import 'full_image_page.dart';

class ClientPreview extends StatefulWidget {
  final Map<String, dynamic> client;
  final String? status;
  final String? reason;

  const ClientPreview({
    Key? key,
    required this.client,
    this.status,
    this.reason,
  }) : super(key: key);

  @override
  ClientPreviewState createState() => ClientPreviewState();
}

class ClientPreviewState extends State<ClientPreview> {
  late String _name;
  late String _status;
  Map<String, dynamic>? _formData;

  @override
  void initState() {
    super.initState();

    _name = (widget.client['information'] ?? '') as String;
    _status = (widget.status ?? widget.client['status'] ?? 'pending').toString();

    final formDataStr = widget.client['form_data'];
    if (formDataStr != null && formDataStr.toString().isNotEmpty) {
      try {
        _formData = json.decode(formDataStr) as Map<String, dynamic>;
      } catch (_) {
        _formData = null;
      }
    }

    if (_name.trim().isEmpty) {
      _name = _getField('full_name');
    }
  }

  Color get _statusColor {
    final s = _status.toLowerCase();
    switch (s) {
      case 'approved':
        return Colors.green;
      case 'denied':
        return Colors.red;
      case 'draft':
        return Colors.blueGrey;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String get _statusLabel {
    final s = _status.toLowerCase();
    switch (s) {
      case 'approved':
        return 'Approved';
      case 'bounced':
        return 'Bounced';
      case 'rejected':
        return 'rejected';
      case 'draft':
        return 'Draft';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  String _getField(String key) {
    if (_formData == null) return '';
    final v = _formData![key];
    return v == null ? '' : v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final idNumber = _getField('id_number');

    return Scaffold(
      appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Client', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
        backgroundColor: AppColors.primary,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Basic info card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name.isEmpty ? 'Unnamed client' : _name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (idNumber.isNotEmpty)
                      Text('ID Number: $idNumber'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          'Status: ',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 3, horizontal: 10),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.17),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _statusColor),
                          ),
                          child: Text(
                            _statusLabel,
                            style: TextStyle(
                              color: _statusColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            if ((_status.toLowerCase() == 'rejected' ||
                    _status.toLowerCase() == 'bounced' ||
                    _status.toLowerCase() == 'denied') &&
                widget.reason != null &&
                widget.reason!.trim().isNotEmpty)
              Card(
                color: const Color.fromARGB(255, 228, 208, 208),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.red[700],),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.reason!.trim(),
                           style: TextStyle(color: Colors.red[700],fontWeight: FontWeight.bold,),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Only show "Details" and images if we have extra data
            if (_formData != null) ...[
              const Text(
                'Images & Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              _imageTile('Front of ID', _getField('frontIdPath')),
              _imageTile('Back of ID', _getField('backIdPath')),
              _imageTile('Selfie (Agent & Client)', _getField('selfiePath')),
              _imageTile('Client Signature', _getField('signaturePath')),
              _imageTile('Customer Photo', _getField('customerPhotoPath')),
              _imageTile('Latest Payslip', _getField('payslipPath')),
              _imageTile('Bank Statement', _getField('bankStatementPath')),
              _imageTile('Employer Letter', _getField('employerLetterPath')),
              _imageTile('Application Form', _getField('applicationFormPath')),

              SizedBox(height: 40,)
            ] else ...[
              const SizedBox(height: 20),
              const Text(
                'No additional data available for this client.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Shows an image card only if [path] is not empty.
  Widget _imageTile(String label, String? path) {
    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final isRemote =
        path.startsWith('http://') || path.startsWith('https://');
    final file = File(path);
    final hasLocalFile = !isRemote && file.existsSync();

    if (!isRemote && !hasLocalFile) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (hasLocalFile) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullImagePage(imageFile: file),
                    ),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 160,
                  width: double.infinity,
                  child: isRemote
                      ? Image.network(
                          path,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      : Image.file(
                          file,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
