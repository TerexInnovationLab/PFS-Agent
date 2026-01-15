import 'package:flutter/material.dart';

import 'dashboardpage.dart';// Adjust path if needed

class CustomerOnboardingPage extends StatefulWidget {
  const CustomerOnboardingPage({super.key});

  @override
  State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
}

class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final Color orange = const Color(0xFFFF6600);

  // Simulated OCR fields
  String fullName = '';
  String idNumber = '';
  String employer = '';
  String salary = '';
  String contact = '';
  bool consentGiven = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Onboarding'),
        backgroundColor: orange,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white), // back arrow
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('1. ID Capture'),
              _photoCaptureRow('Front of ID'),
              _photoCaptureRow('Back of ID'),

              const SizedBox(height: 16),
              _sectionTitle('2. Selfie & Liveness Detection'),
              _photoCaptureRow('Take Selfie'),

              const SizedBox(height: 16),
              _sectionTitle('3. Personal Details (Auto-filled from OCR)'),
              _textField('Full Name', (val) => fullName = val),
              _textField('ID Number', (val) => idNumber = val),

              const SizedBox(height: 16),
              _sectionTitle('4. Employment & Contact Info'),
              _textField('Employer', (val) => employer = val),
              _textField('Monthly Salary', (val) => salary = val),
              _textField('Phone Number', (val) => contact = val),

              const SizedBox(height: 16),
              _sectionTitle('5. Consent & E-Signature'),
              CheckboxListTile(
                value: consentGiven,
                onChanged: (val) => setState(() => consentGiven = val ?? false),
                title: const Text('I consent to KYC and bureau check'),
              ),
              _signaturePlaceholder(),

              const SizedBox(height: 16),
              _sectionTitle('6. Geo-tag & Offline Save'),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green),
                  const SizedBox(width: 8),
                  const Text('Geo-tag captured'),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Save Offline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate() && consentGiven) {
                      // Submit logic here
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  child: const Text('Submit Onboarding'),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DashboardPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.dashboard),
                  label: const Text('Back to Dashboard'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
              
              SizedBox(height: 50,)
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _photoCaptureRow(String label) {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.camera_alt),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: orange,
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        const Text('Not captured', style: TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _textField(String label, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _signaturePlaceholder() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        color: Colors.grey[100],
      ),
      child: const Center(child: Text('E-Signature Pad Placeholder')),
    );
  }
}




// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:signature/signature.dart';
// import 'package:pfs_agent/dashboardpage.dart';

// class CustomerOnboardingPage extends StatefulWidget {
//   const CustomerOnboardingPage({super.key});

//   @override
//   State<CustomerOnboardingPage> createState() => _CustomerOnboardingPageState();
// }

// class _CustomerOnboardingPageState extends State<CustomerOnboardingPage> {
//   final _formKey = GlobalKey<FormState>();
//   final Color orange = const Color(0xFFFF6600);

//   String fullName = '';
//   String idNumber = '';
//   String employer = '';
//   String salary = '';
//   String contact = '';
//   bool consentGiven = false;

//   final Map<String, String?> _uploadedFiles = {
//     'Front of ID': null,
//     'Back of ID': null,
//     'Take Selfie': null,
//     'Document Upload': null,
//   };

//   final SignatureController _signatureController = SignatureController(
//     penStrokeWidth: 2,
//     penColor: Colors.black,
//     exportBackgroundColor: Colors.white,
//   );

//   @override
//   void dispose() {
//     _signatureController.dispose();
//     super.dispose();
//   }

//   Future<void> _pickImage(String label, {bool fromCamera = false}) async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(
//       source: fromCamera ? ImageSource.camera : ImageSource.gallery,
//     );
//     if (pickedFile != null) {
//       setState(() {
//         _uploadedFiles[label] = pickedFile.name;
//       });
//     }
//   }

//   Future<void> _pickDocument(String label) async {
//     final result = await FilePicker.platform.pickFiles(type: FileType.any);
//     if (result != null && result.files.isNotEmpty) {
//       setState(() {
//         _uploadedFiles[label] = result.files.single.name;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Customer Onboarding'),
//         backgroundColor: orange,
//         centerTitle: true,
//         iconTheme: const IconThemeData(color: Colors.white),
//         titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _formKey,
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _sectionTitle('1. ID Capture'),
//               _photoCaptureRow('Front of ID', fromCamera: true),
//               _photoCaptureRow('Back of ID', fromCamera: true),

//               const SizedBox(height: 16),
//               _sectionTitle('2. Selfie & Liveness Detection'),
//               _photoCaptureRow('Take Selfie', fromCamera: true),

//               const SizedBox(height: 16),
//               _sectionTitle('3. Personal Details (Auto-filled from OCR)'),
//               _textField('Full Name', (val) => fullName = val),
//               _textField('ID Number', (val) => idNumber = val),

//               const SizedBox(height: 16),
//               _sectionTitle('4. Employment & Contact Info'),
//               _textField('Employer', (val) => employer = val),
//               _textField('Monthly Salary', (val) => salary = val),
//               _textField('Phone Number', (val) => contact = val),

//               const SizedBox(height: 16),
//               _sectionTitle('5. Upload Supporting Document'),
//               _documentUploadRow('Document Upload'),

//               const SizedBox(height: 16),
//               _sectionTitle('6. Consent & E-Signature'),
//               CheckboxListTile(
//                 value: consentGiven,
//                 onChanged: (val) => setState(() => consentGiven = val ?? false),
//                 title: const Text('I consent to KYC and bureau check'),
//               ),
//               _signaturePad(),

//               const SizedBox(height: 16),
//               _sectionTitle('7. Geo-tag & Offline Save'),
//               Row(
//                 children: [
//                   const Icon(Icons.location_on, color: Colors.green),
//                   const SizedBox(width: 8),
//                   const Text('Geo-tag captured'),
//                   const Spacer(),
//                   ElevatedButton.icon(
//                     onPressed: () {},
//                     icon: const Icon(Icons.save_alt),
//                     label: const Text('Save Offline'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: orange,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 24),
//               Center(
//                 child: ElevatedButton(
//                   onPressed: () {
//                     if (_formKey.currentState!.validate() && consentGiven) {
//                       // Submit logic here
//                     }
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: orange,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
//                   ),
//                   child: const Text('Submit Onboarding'),
//                 ),
//               ),

//               const SizedBox(height: 16),
//               Center(
//                 child: ElevatedButton.icon(
//                   onPressed: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (context) => const DashboardPage()),
//                     );
//                   },
//                   icon: const Icon(Icons.dashboard),
//                   label: const Text('Back to Dashboard'),
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: orange,
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _sectionTitle(String title) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 8),
//       child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
//     );
//   }

//   Widget _photoCaptureRow(String label, {bool fromCamera = false}) {
//     final fileName = _uploadedFiles[label];
//     return Row(
//       children: [
//         ElevatedButton.icon(
//           onPressed: () => _pickImage(label, fromCamera: fromCamera),
//           icon: const Icon(Icons.camera_alt),
//           label: Text(fileName == null ? label : 'Change File'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: orange,
//             foregroundColor: Colors.white,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Text(
//             fileName ?? 'Not captured',
//             style: TextStyle(color: fileName == null ? Colors.grey : Colors.black),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _documentUploadRow(String label) {
//     final fileName = _uploadedFiles[label];
//     return Row(
//       children: [
//         ElevatedButton.icon(
//           onPressed: () => _pickDocument(label),
//           icon: const Icon(Icons.upload_file),
//           label: Text(fileName == null ? 'Upload Document' : 'Change File'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: orange,
//             foregroundColor: Colors.white,
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Text(
//             fileName ?? 'No document selected',
//             style: TextStyle(color: fileName == null ? Colors.grey : Colors.black),
//             overflow: TextOverflow.ellipsis,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _textField(String label, Function(String) onChanged) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 12),
//       child: TextFormField(
//         decoration: InputDecoration(
//           labelText: label,
//           border: const OutlineInputBorder(),
//         ),
//         onChanged: onChanged,
//         validator: (val) => val == null || val.isEmpty ? 'Required' : null,
//       ),
//     );
//   }

//   Widget _signaturePad() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           height: 100,
//           margin: const EdgeInsets.symmetric(vertical: 8),
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey),
//             color: Colors.grey[100],
//           ),
//           child: Signature(
//             controller: _signatureController,
//             backgroundColor: Colors.grey[100]!,
//           ),
//         ),
//         Row(
//           children: [
//             ElevatedButton(
//               onPressed: () => _signatureController.clear(),
//               child: const Text('Clear Signature'),
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.grey[400],
//                 foregroundColor: Colors.black,
//               ),
//             ),
//             const SizedBox(width: 12),
//             ElevatedButton(
//   onPressed: () async {
//     final Uint8List? data = await _signatureController.toPngBytes();
//     if (data != null) {
//       // You can now handle the signature image bytes
//       // For example: upload to server, save locally, or preview
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Signature saved successfully')),
//       );
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No signature to save')),
//       );
//     }
//   },
//   child: const Text('Save Signature'),
//   style: ElevatedButton.styleFrom(
//     backgroundColor: orange,
//     foregroundColor: Colors.white,
//   ),
//    ), 
//    ],
//     ), 
//     ],
//      );
//       }
//        }