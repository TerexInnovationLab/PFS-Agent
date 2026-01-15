import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pfs_agent/config/api_config.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../layouts/Colors.dart';
import 'full_image_page.dart';
import 'database_helper.dart';

class AnalogSignUp extends StatefulWidget {
  final Map<String, dynamic>? draftClient; // 👈 passed from MyClients

  const AnalogSignUp({Key? key, this.draftClient}) : super(key: key);

  @override
  AnalogSignUpstate createState() => AnalogSignUpstate();
}

class AnalogSignUpstate extends State<AnalogSignUp> {
  final _formKey = GlobalKey<FormState>();

  // Image variables (aligned with digital registration)
  File? frontIdImage; // front_of_id
  File? backIdImage; // back_of_id
  File? selfieImage; // selfie
  File? signatureImage; // client_signature
  File? customerPhotoImage; // customer_photo
  File? payslipImage; // latest_payslip
  File? bankStatementImage; // bank_statement
  File? employerLetterImage; // employer_letter
  File? applicationFormImage; // extra

  final ImagePicker _picker = ImagePicker();

  // Simple text fields
  String _fullName = '';

  // Referral
  String? _referralCode;

  // Sending state
  bool _sending = false;
  String _status = 'Idle';

  // Draft/submit tracking
  bool _submitted = false;
  bool _draftSaved = false;
  int? _draftId; // 👈 row id in DB if draft exists

  // Same URL as digital registration
  final String url =
      ApiConfig.baseUrl+'/client/upload';

  @override
  void initState() {
    super.initState();
    _initFromDraftIfAny();
  }

  bool _validateRequiredFields() {
    // Validate text fields using form validators
    final formValid = _formKey.currentState?.validate() ?? false;

    // If name field failed validation → show message
    if (!formValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: const Text("Please fill in Full Name."),
        ),
      );
      return false;
    }

    // Validate required images
    List<String> missing = [];

    if (selfieImage == null) missing.add('Selfie');
    if (applicationFormImage == null) missing.add('Application Form');
    if (customerPhotoImage == null) missing.add('Customer Photo');

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text("Please upload: ${missing.join(', ')}."),
        ),
      );
      return false;
    }

    return true;
  }

  void _initFromDraftIfAny() {
    final draft = widget.draftClient;
    if (draft == null) return;

    _draftId = draft['id'] as int?;
    _fullName = (draft['information'] ?? '') as String;

    final formDataStr = draft['form_data'];
    if (formDataStr != null && formDataStr.toString().isNotEmpty) {
      try {
        final data = json.decode(formDataStr) as Map<String, dynamic>;

        // If old drafts had 'id_number' stored, we just ignore it now

        String? front = data['frontIdPath'];
        String? back = data['backIdPath'];
        String? selfie = data['selfiePath'];
        String? signature = data['signaturePath'];
        String? customer = data['customerPhotoPath'];
        String? payslip = data['payslipPath'];
        String? bank = data['bankStatementPath'];
        String? employer = data['employerLetterPath'];
        String? appForm = data['applicationFormPath'];

        if (front != null && front.isNotEmpty) frontIdImage = File(front);
        if (back != null && back.isNotEmpty) backIdImage = File(back);
        if (selfie != null && selfie.isNotEmpty) selfieImage = File(selfie);
        if (signature != null && signature.isNotEmpty) {
          signatureImage = File(signature);
        }
        if (customer != null && customer.isNotEmpty) {
          customerPhotoImage = File(customer);
        }
        if (payslip != null && payslip.isNotEmpty) {
          payslipImage = File(payslip);
        }
        if (bank != null && bank.isNotEmpty) {
          bankStatementImage = File(bank);
        }
        if (employer != null && employer.isNotEmpty) {
          employerLetterImage = File(employer);
        }
        if (appForm != null && appForm.isNotEmpty) {
          applicationFormImage = File(appForm);
        }
      } catch (_) {
        // ignore parsing errors, just don't prefill
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPopSaveDraft,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 2,
          title: const Text(
            'Forms Upload',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('1. Personal Details'),
                    _textField(
                      'Full Name',
                          (v) => _fullName = v,
                      initialValue: _fullName,
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle('2. ID Capture'),
                    fileRow(
                      'Front of ID',
                      frontIdImage,
                          (f) => frontIdImage = f,
                    ),
                    fileRow(
                      'Back of ID',
                      backIdImage,
                          (f) => backIdImage = f,
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle('3. Selfie (Agent & Client)'),
                    fileRow(
                      'Take Selfie',
                      selfieImage,
                          (f) => selfieImage = f,
                    ),

                    const SizedBox(height: 16),

                    _sectionTitle('4. Supporting Documentation'),
                    fileRow(
                      'Application Form',
                      applicationFormImage,
                          (f) => applicationFormImage = f,
                    ),
                    fileRow(
                      'Customer Photo',
                      customerPhotoImage,
                          (f) => customerPhotoImage = f,
                    ),
                    fileRow(
                      'Latest Payslip',
                      payslipImage,
                          (f) => payslipImage = f,
                    ),
                    fileRow(
                      'Bank Statement',
                      bankStatementImage,
                          (f) => bankStatementImage = f,
                    ),
                    fileRow(
                      'Employer Letter',
                      employerLetterImage,
                          (f) => employerLetterImage = f,
                    ),

                    const SizedBox(height: 24),

                    // Bottom buttons: Referral + Submit
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _sending ? null : _showReferralDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.info,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Referral',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                            _sending ? null : () => _submitForm(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                              const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _sending ? 'Submitting...' : 'Submit',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            if (_sending)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ----------------- UI HELPERS -----------------

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget fileRow(String label, File? file, Function(File) onCapture) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label + capture button
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final XFile? img = await _picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (img != null) {
                      setState(() {
                        onCapture(File(img.path));
                      });
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text(
                    'Capture',
                    style: TextStyle(fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),

            if (file != null) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FullImagePage(imageFile: file),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: Image.file(
                      file,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _textField(
      String label,
      Function(String) onChanged, {
        String? initialValue,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          filled: true,
          fillColor: AppColors.cardBackground,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.textSecondary.withOpacity(0.18),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 1.4,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.danger,
              width: 1.4,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.danger,
              width: 1.4,
            ),
          ),
        ),
        onChanged: onChanged,
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  // ----------------- DRAFT SAVE ON BACK -----------------

  Future<bool> _onWillPopSaveDraft() async {
    await _saveDraftIfNeeded();
    return true;
  }

  Future<void> _saveDraftIfNeeded() async {
    if (_submitted || _draftSaved) return;

    final hasName = _fullName.trim().isNotEmpty;
    final hasImages = frontIdImage != null ||
        backIdImage != null ||
        selfieImage != null ||
        signatureImage != null ||
        customerPhotoImage != null ||
        payslipImage != null ||
        bankStatementImage != null ||
        employerLetterImage != null ||
        applicationFormImage != null;

    if (!hasName && !hasImages) return;

    final nameToSave =
    hasName ? _fullName.trim() : 'Unnamed client (draft)';

    final formJson = json.encode({
      'full_name': _fullName,
      // no id_number for drafts anymore
      'frontIdPath': frontIdImage?.path,
      'backIdPath': backIdImage?.path,
      'selfiePath': selfieImage?.path,
      'signaturePath': signatureImage?.path,
      'customerPhotoPath': customerPhotoImage?.path,
      'payslipPath': payslipImage?.path,
      'bankStatementPath': bankStatementImage?.path,
      'employerLetterPath': employerLetterImage?.path,
      'applicationFormPath': applicationFormImage?.path,
    });

    if (_draftId == null) {
      // insert new draft
      final id = await DatabaseHelper.instance
          .insertClient(nameToSave, 'draft', formData: formJson);
      _draftId = id;
    } else {
      // update existing draft
      await DatabaseHelper.instance.updateClient(
        _draftId!,
        name: nameToSave,
        status: 'draft',
        formData: formJson,
      );
    }

    _draftSaved = true;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Draft saved locally')),
    );
  }

  // ----------------- REFERRAL + SUBMIT LOGIC -----------------

  void _showReferralDialog() {
    final TextEditingController referralCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          "Referral Agent",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: TextField(
          controller: referralCtrl,
          decoration: InputDecoration(
            labelText: 'Agent Code',
            labelStyle: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final code = referralCtrl.text.trim();

              if (code.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter referral code')),
                );
                return;
              }

              setState(() {
                _referralCode = code;
              });

              Navigator.pop(ctx);

              _submitForm(withReferral: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm({bool withReferral = false}) async {
    if (!_validateRequiredFields()) {
      return;
    }

    setState(() {
      _sending = true;
      _status = 'Preparing request...';
    });

    try {
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      // No more id_number field from UI – only full_name + referral
      request.fields.addAll({
        'full_name': _fullName,
        'referal_agent_code': withReferral ? (_referralCode ?? '') : '',
      });

      Future<void> tryAttach(String name, File? file) async {
        if (file != null && await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              name,
              file.path,
              filename: path.basename(file.path),
            ),
          );
        }
      }

      await tryAttach('client_signature', signatureImage);
      await tryAttach('front_of_id', frontIdImage);
      await tryAttach('latest_payslip', payslipImage);
      await tryAttach('bank_statement', bankStatementImage);
      await tryAttach('employer_letter', employerLetterImage);
      await tryAttach('back_of_id', backIdImage);
      await tryAttach('customer_photo', customerPhotoImage);
      await tryAttach('selfie', selfieImage);
      await tryAttach('application_form', applicationFormImage);

      setState(() {
        _status = 'Sending request...';
      });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() {
        _sending = false;
      });

      Map<String, dynamic>? jsonResponse;
      try {
        jsonResponse = json.decode(response.body);
      } catch (_) {
        jsonResponse = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _status = 'Success';
        _submitted = true;

        // 👇 Get the ID from "data" (string like "idl2lk2")
        String? createdId;
        if (jsonResponse != null && jsonResponse['data'] != null) {
          final data = jsonResponse['data'];
          if (data is Map<String, dynamic>) {
            createdId = data['id']?.toString();
          }
        }

        print("the id is: $createdId");

        final nameToSave =
        _fullName.trim().isEmpty ? 'Unnamed client' : _fullName.trim();

        // 🔥 Save server ID instead of typed ID number
        final formJson = json.encode({
          'full_name': _fullName,
          'id_number': createdId, // <--- here we store the server ID
          'frontIdPath': frontIdImage?.path,
          'backIdPath': backIdImage?.path,
          'selfiePath': selfieImage?.path,
          'signaturePath': signatureImage?.path,
          'customerPhotoPath': customerPhotoImage?.path,
          'payslipPath': payslipImage?.path,
          'bankStatementPath': bankStatementImage?.path,
          'employerLetterPath': employerLetterImage?.path,
          'applicationFormPath': applicationFormImage?.path,
        });

        if (_draftId != null) {
          // 🔥 This was a draft: update to pending
          await DatabaseHelper.instance.updateClient(
            _draftId!,
            name: nameToSave,
            status: 'pending',
            formData: formJson,
          );
        } else {
          // New client: insert as pending
          await DatabaseHelper.instance.insertClient(
            nameToSave,
            'pending',
            formData: formJson,
          );
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Success'),
            content: Text(
              withReferral
                  ? 'Form submitted with referral code: $_referralCode'
                  : 'You have successfully submitted the forms.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context); // back to MyClients
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        _status = 'Failed';
        String errorMessage = 'Unknown error';
        if (jsonResponse != null) {
          errorMessage = jsonResponse['message'] ??
              jsonResponse['error'] ??
              jsonResponse.toString();
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _sending = false;
        _status = 'Exception occurred';
      });

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Exception'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
