import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signature/signature.dart';

import 'package:pfs_agent/config/api_config.dart';
import '../layouts/Colors.dart';
import 'FullScreenSignaturePage.dart';
import 'Home.dart';
import 'database/digital_registration_db.dart';

class DigitalSignUpBounced extends StatefulWidget {
  final Map<String, dynamic>? draftData;
  final int? localId; // id in digital_registrations table

  // ✅ NEW: data passed from DigitalClientPreview
  final Map<String, dynamic>? clientPreviewData;

  // ✅ NEW: server/client id to be used in URL: /client/{id}
  final String? clientId;

  const DigitalSignUpBounced({
    Key? key,
    this.draftData,
    this.localId,
    this.clientPreviewData,
    this.clientId,
  }) : super(key: key);

  @override
  DigitalSignUpBouncedState createState() => DigitalSignUpBouncedState();
}

const double _digitalSignUpFieldGap = 20.0;

class DigitalSignUpBouncedState extends State<DigitalSignUpBounced> {
  // Local DB
  int? _localId;
  bool _submittedToServer = false;

  // ✅ NEW: store preview/server client id in state too (optional, but useful)
  String? _clientIdFromPreview;

  // Signature
  late final SignatureController _signatureController;
  bool _signatureHasData = false;
  late final VoidCallback _signatureListener;

  // Steps
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // --- Controllers & state for all fields ---
  // 1. System information
  final TextEditingController systemInfoController = TextEditingController();
  DateTime? applicationDate;

  // 2. Application type
  bool appTypeGovernmentPayroll = false;
  bool appTypeShortTermPrivate = false;
  final TextEditingController psmReservationNumberController =
      TextEditingController();

  // 3. Personal information
  String? titleValue; // stored lowercase: 'mr', 'mrs', etc.
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  DateTime? dateOfBirth;
  String gender = 'male';
  final TextEditingController dependantsController = TextEditingController();
  String maritalStatus = 'single';
  final TextEditingController homeVillageController = TextEditingController();
  final TextEditingController villageController = TextEditingController();
  final TextEditingController districtController = TextEditingController();
  final TextEditingController traditionalAuthorityController =
      TextEditingController();

  // 4. Address detail
  final TextEditingController physicalAddressController =
      TextEditingController();
  final TextEditingController cityController = TextEditingController();
  String? province;
  final TextEditingController postalAddressController = TextEditingController();

  // 5. Contact details
  final TextEditingController workTelController = TextEditingController();
  final TextEditingController homeTelController = TextEditingController();
  final TextEditingController mobile1Controller = TextEditingController();
  final TextEditingController mobile2Controller = TextEditingController();
  final TextEditingController email1Controller = TextEditingController();
  final TextEditingController email2Controller = TextEditingController();

  // 6. Details of family member
  final TextEditingController famSurnameController = TextEditingController();
  final TextEditingController famFirstNameController = TextEditingController();
  String? famTitle; // lowercase
  final TextEditingController famRelationController = TextEditingController();
  final TextEditingController famHomeTelController = TextEditingController();
  final TextEditingController famMobileController = TextEditingController();
  final TextEditingController famAddressController = TextEditingController();

  // 7. Employment detail
  final TextEditingController employerNameController = TextEditingController();
  final TextEditingController employerSpecificController =
      TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController jobTitleController = TextEditingController();
  final TextEditingController employerCodeController = TextEditingController();
  final TextEditingController lengthYearsController = TextEditingController();
  final TextEditingController lengthMonthsController = TextEditingController();
  bool employedFullTime = true;
  final TextEditingController grossAnnualController = TextEditingController();
  final TextEditingController netMonthlyController = TextEditingController();
  final TextEditingController workAddressController = TextEditingController();
  final TextEditingController workCityController = TextEditingController();
  String? workProvince;
  String salaryFrequency = 'monthly';
  DateTime? salaryPayDate;

  // 8. Banking details
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountHolderController = TextEditingController();
  final TextEditingController branchNameController = TextEditingController();
  final TextEditingController branchCodeController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  String accountType = 'current';
  bool salaryPaidIntoAccount = true;
  final TextEditingController accountUsageYearsController =
      TextEditingController();
  final TextEditingController accountUsageMonthsController =
      TextEditingController();
  bool salaryTransferred3Months = false;

  // 9. Supporting documentation placeholders + referral
  String? idFileName;
  String? payslipFileName;
  String? bankStatementFileName;
  String? employerLetterFileName;
  final TextEditingController referralAgentController = TextEditingController();

  // 10. Loan schedule detail
  final TextEditingController baseLendingRateController =
      TextEditingController();
  final TextEditingController effectiveInterestRateController =
      TextEditingController();
  DateTime? firstInstalmentDate;
  DateTime? lastInstalmentDate;
  final TextEditingController netPayController = TextEditingController();
  final TextEditingController maxAllowedInstalmentController =
      TextEditingController();
  final TextEditingController totalAppliedController = TextEditingController();
  final TextEditingController totalApprovedController = TextEditingController();
  final TextEditingController cashToClientController = TextEditingController();
  final TextEditingController loanPeriodController = TextEditingController();
  final TextEditingController adminFeeController = TextEditingController();
  final TextEditingController interestController = TextEditingController();
  final TextEditingController totalCollectableController =
      TextEditingController();
  final TextEditingController monthlyInstalmentController =
      TextEditingController();
  String? loanpurpose; // lowercase values
  final TextEditingController loanPurposeController = TextEditingController();

  // 11. Declaration
  bool acceptedDeclaration = false;
  String? clientSignatureFile;

  // Form keys (match number of steps)
  late final List<GlobalKey<FormState>> _formKeys =
      List.generate(_steps.length, (_) => GlobalKey<FormState>());

  // Files
  File? idCopy;
  File? payslipCopy;
  File? bankStatementCopy;
  File? employerLetterCopy;
  File? signatureCopy;
  File? selfCopy;
  File? identityBackCopy;
  File? customerPhotoCopy;

  // Sending state
  bool _sending = false;
  String _status = 'Idle';

  // File paths
  String? clientSignaturePath;
  String? identificationPath;
  String? latestPayslipPath;
  String? bankStatementPath;
  String? employerLetterPath;
  String? identificationPathBack;
  String? customerPhoto;
  String? self;

  // ✅ NEW: Create endpoint becomes /client/{id}
  // NOTE: this is dynamic now, not final constant.
  String get url {
    final id = _clientIdFromPreview ?? widget.clientId;
    if (id == null || id.trim().isEmpty) {
      // fallback (keeps your old behaviour if no id was passed)
      return '${ApiConfig.baseUrl}/client';
    }
    return '${ApiConfig.baseUrl}/client/$id';
  }

  // ------------------------------------------------------------
  // ✅ NEW: normalize preview keys (your preview uses collectFormData keys)
  // and map them into the bounced form fields (backend fields are different)
  Map<String, dynamic> _normalizeClientPreviewData(Map<String, dynamic> d) {
    // Some APIs wrap actual fields inside "data"
    if (d['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(d['data'] as Map<String, dynamic>);
    }
    return d;
  }

  // ✅ NEW: Extract id from preview payload
  String? _extractClientIdFromMap(Map<String, dynamic> raw) {
    dynamic v = raw['id'] ?? raw['client_id'] ?? raw['server_created_id'];
    if (v == null && raw['data'] is Map<String, dynamic>) {
      final inner = raw['data'] as Map<String, dynamic>;
      v = inner['id'] ?? inner['client_id'] ?? inner['server_created_id'];
    }
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ------------------------------------------------------------
  // Helpers
  Future<void> pickFile(String which) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final p = result.files.first.path;
      if (p != null) {
        setState(() {
          switch (which) {
            case 'client_signature':
              clientSignaturePath = p;
              break;
            case 'identification':
              identificationPath = p;
              break;
            case 'latest_payslip':
              latestPayslipPath = p;
              break;
            case 'bank_statement':
              bankStatementPath = p;
              break;
            case 'employer_letter':
              employerLetterPath = p;
              break;
            case 'back_of_id':
              identificationPathBack = p;
              break;
            case 'customer_photo':
              customerPhoto = p;
              break;
            case 'selfie':
              self = p;
              break;
          }
        });
      }
    }
  }

  Future<String> _saveSignaturePng(Uint8List pngBytes) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory sigDir = Directory('${appDocDir.path}/signatures');
    if (!await sigDir.exists()) await sigDir.create(recursive: true);

    final String filePath =
        '${sigDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File(filePath);
    await file.writeAsBytes(pngBytes);
    return file.path;
  }

  Future<void> _openSignaturePageAndGetResult() async {
    final result = await Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const FullScreenSignaturePage()),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        clientSignaturePath = result;
        signatureCopy = File(result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signature saved')),
      );
    }
  }

  String? _extractCreatedId(Map<String, dynamic>? jsonResp) {
    if (jsonResp == null) return null;

    final topLevelId = jsonResp['id'];
    if (topLevelId != null) return topLevelId.toString();

    final data = jsonResp['data'];
    if (data == null) return null;

    if (data is String) return data;

    if (data is Map) {
      if (data['id'] != null) return data['id'].toString();
      if (data['client_id'] != null) return data['client_id'].toString();
      if (data['created_id'] != null) return data['created_id'].toString();
      if (data['data'] is Map && (data['data'] as Map)['id'] != null) {
        return (data['data'] as Map)['id'].toString();
      }
    }

    return null;
  }

  Future<void> _saveServerIdToLocal(String createdId) async {
    try {
      DigitalRegistration? existing;
      if (_localId != null) {
        final all = await DigitalRegistrationDb.instance.getAll();
        final matches = all.where((r) => r.id == _localId).toList();
        existing = matches.isNotEmpty ? matches.first : null;
      }

      Map<String, dynamic> dataMap;
      if (existing != null) {
        if (existing.data is String) {
          try {
            dataMap =
                json.decode(existing.data as String) as Map<String, dynamic>;
          } catch (_) {
            dataMap = Map<String, dynamic>.from(_collectFormData());
          }
        } else if (existing.data is Map<String, dynamic>) {
          dataMap = Map<String, dynamic>.from(
            existing.data as Map<String, dynamic>,
          );
        } else {
          dataMap = Map<String, dynamic>.from(_collectFormData());
        }
      } else {
        dataMap = Map<String, dynamic>.from(_collectFormData());
      }

      // Store server id separately (avoid overwriting user's entered id_number)
      dataMap['server_created_id'] = createdId;

      final now = DateTime.now();

      final reg = DigitalRegistration(
        id: existing?.id ?? _localId,
        status: existing?.status ?? 'pending',
        data: dataMap,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      final savedId = await DigitalRegistrationDb.instance.upsert(reg);
      _localId = savedId;

      // ignore: avoid_print
      print(
        'Saved server id $createdId into local digital registration (local id $savedId)',
      );
    } catch (e) {
      // ignore: avoid_print
      print('Failed to save server id locally: $e');
    }
  }

  Map<String, dynamic> _collectFormData() {
    return {
      'titleValue': titleValue,
      'surname': surnameController.text,
      'firstName': firstNameController.text,
      'idNumber': idNumberController.text,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'dependants': dependantsController.text,
      'maritalStatus': maritalStatus,
      'homeDistrict': districtController.text,
      'homeTraditionalAuthority': traditionalAuthorityController.text,
      'homeVillage': villageController.text,

      'physicalAddress': physicalAddressController.text,
      'city': cityController.text,
      'province': province,

      'workTel': workTelController.text,
      'homeTel': homeTelController.text,
      'mobile1': mobile1Controller.text,
      'mobile2': mobile2Controller.text,
      'email1': email1Controller.text,
      'email2': email2Controller.text,

      'famSurname': famSurnameController.text,
      'famFirstName': famFirstNameController.text,
      'famTitle': famTitle,
      'famRelation': famRelationController.text,
      'famHomeTel': famHomeTelController.text,
      'famMobile': famMobileController.text,
      'famAddress': famAddressController.text,

      'employerName': employerNameController.text,
      'specificEmployer': employerSpecificController.text,
      'department': departmentController.text,
      'jobTitle': jobTitleController.text,
      'employerCode': employerCodeController.text,
      'lengthYears': lengthYearsController.text,
      'lengthMonths': lengthMonthsController.text,
      'employedFullTime': employedFullTime,
      'grossAnnual': grossAnnualController.text,
      'netMonthly': netMonthlyController.text,
      'workAddress': workAddressController.text,
      'workCity': workCityController.text,
      'workProvince': workProvince,
      'salaryFrequency': salaryFrequency,
      'salaryPayDate': salaryPayDate?.toIso8601String(),

      'bankName': bankNameController.text,
      'accountHolder': accountHolderController.text,
      'branchName': branchNameController.text,
      'branchCode': branchCodeController.text,
      'accountNumber': accountNumberController.text,
      'accountType': accountType,
      'salaryPaidIntoAccount': salaryPaidIntoAccount,
      'accountUsageYears': accountUsageYearsController.text,
      'accountUsageMonths': accountUsageMonthsController.text,
      'salaryTransferred3Months': salaryTransferred3Months,

      'totalApplied': totalAppliedController.text,
      'totalApproved': totalApprovedController.text,
      'cashToClient': cashToClientController.text,
      'loanPeriod': loanPeriodController.text,
      'adminFee': adminFeeController.text,
      'interest': interestController.text,
      'totalCollectable': totalCollectableController.text,
      'monthlyInstalment': monthlyInstalmentController.text,
      'loanPurpose': loanpurpose,
      'loanPurposeText': loanPurposeController.text,

      'acceptedDeclaration': acceptedDeclaration,

      'clientSignaturePath': clientSignaturePath,
      'identificationPath': identificationPath,
      'identificationPathBack': identificationPathBack,
      'latestPayslipPath': latestPayslipPath,
      'bankStatementPath': bankStatementPath,
      'employerLetterPath': employerLetterPath,
      'customerPhoto': customerPhoto,
      'self': self,

      // ✅ also persist clientId if present
      'server_created_id': _clientIdFromPreview ?? widget.clientId,
    };
  }

  void _loadFromData(Map<String, dynamic> data) {
    setState(() {
      titleValue = data['titleValue'];
      surnameController.text = data['surname'] ?? '';
      firstNameController.text = data['firstName'] ?? '';
      idNumberController.text = data['idNumber'] ?? '';

      final dobStr = data['dateOfBirth'];
      dateOfBirth = dobStr != null ? DateTime.tryParse(dobStr) : null;

      gender = data['gender'] ?? 'male';
      dependantsController.text = data['dependants'] ?? '';
      maritalStatus = data['maritalStatus'] ?? 'single';
      districtController.text = data['homeDistrict'] ?? '';
      traditionalAuthorityController.text =
          data['homeTraditionalAuthority'] ?? '';
      villageController.text = data['homeVillage'] ?? '';

      physicalAddressController.text = data['physicalAddress'] ?? '';
      cityController.text = data['city'] ?? '';
      province = data['province'];

      workTelController.text = data['workTel'] ?? '';
      homeTelController.text = data['homeTel'] ?? '';
      mobile1Controller.text = data['mobile1'] ?? '';
      mobile2Controller.text = data['mobile2'] ?? '';
      email1Controller.text = data['email1'] ?? '';
      email2Controller.text = data['email2'] ?? '';

      famSurnameController.text = data['famSurname'] ?? '';
      famFirstNameController.text = data['famFirstName'] ?? '';
      famTitle = data['famTitle'];
      famRelationController.text = data['famRelation'] ?? '';
      famHomeTelController.text = data['famHomeTel'] ?? '';
      famMobileController.text = data['famMobile'] ?? '';
      famAddressController.text = data['famAddress'] ?? '';

      employerNameController.text = data['employerName'] ?? '';
      employerSpecificController.text = data['specificEmployer'] ?? '';
      departmentController.text = data['department'] ?? '';
      jobTitleController.text = data['jobTitle'] ?? '';
      employerCodeController.text = data['employerCode'] ?? '';
      lengthYearsController.text = data['lengthYears'] ?? '';
      lengthMonthsController.text = data['lengthMonths'] ?? '';
      employedFullTime = data['employedFullTime'] ?? true;
      grossAnnualController.text = data['grossAnnual'] ?? '';
      netMonthlyController.text = data['netMonthly'] ?? '';
      workAddressController.text = data['workAddress'] ?? '';
      workCityController.text = data['workCity'] ?? '';
      workProvince = data['workProvince'];
      salaryFrequency = data['salaryFrequency'] ?? 'monthly';

      final salaryDateStr = data['salaryPayDate'];
      salaryPayDate =
          salaryDateStr != null ? DateTime.tryParse(salaryDateStr) : null;

      bankNameController.text = data['bankName'] ?? '';
      accountHolderController.text = data['accountHolder'] ?? '';
      branchNameController.text = data['branchName'] ?? '';
      branchCodeController.text = data['branchCode'] ?? '';
      accountNumberController.text = data['accountNumber'] ?? '';
      accountType = data['accountType'] ?? 'current';
      salaryPaidIntoAccount = data['salaryPaidIntoAccount'] ?? true;
      accountUsageYearsController.text = data['accountUsageYears'] ?? '';
      accountUsageMonthsController.text = data['accountUsageMonths'] ?? '';
      salaryTransferred3Months = data['salaryTransferred3Months'] ?? false;

      totalAppliedController.text = data['totalApplied'] ?? '';
      totalApprovedController.text = data['totalApproved'] ?? '';
      cashToClientController.text = data['cashToClient'] ?? '';
      loanPeriodController.text = data['loanPeriod'] ?? '';
      adminFeeController.text = data['adminFee'] ?? '';
      interestController.text = data['interest'] ?? '';
      totalCollectableController.text = data['totalCollectable'] ?? '';
      monthlyInstalmentController.text = data['monthlyInstalment'] ?? '';
      loanpurpose = data['loanPurpose'];
      loanPurposeController.text = data['loanPurposeText'] ?? '';

      acceptedDeclaration = data['acceptedDeclaration'] ?? false;

      clientSignaturePath = data['clientSignaturePath'];
      identificationPath = data['identificationPath'];
      identificationPathBack = data['identificationPathBack'];
      latestPayslipPath = data['latestPayslipPath'];
      bankStatementPath = data['bankStatementPath'];
      employerLetterPath = data['employerLetterPath'];
      customerPhoto = data['customerPhoto'];
      self = data['self'];

      signatureCopy =
          (clientSignaturePath != null && clientSignaturePath!.isNotEmpty)
              ? File(clientSignaturePath!)
              : null;

      idCopy = (identificationPath != null && identificationPath!.isNotEmpty)
          ? File(identificationPath!)
          : null;

      identityBackCopy = (identificationPathBack != null &&
              identificationPathBack!.isNotEmpty)
          ? File(identificationPathBack!)
          : null;

      customerPhotoCopy =
          (customerPhoto != null && customerPhoto!.isNotEmpty)
              ? File(customerPhoto!)
              : null;

      selfCopy = (self != null && self!.isNotEmpty) ? File(self!) : null;

      payslipCopy =
          (latestPayslipPath != null && latestPayslipPath!.isNotEmpty)
              ? File(latestPayslipPath!)
              : null;

      bankStatementCopy =
          (bankStatementPath != null && bankStatementPath!.isNotEmpty)
              ? File(bankStatementPath!)
              : null;

      employerLetterCopy =
          (employerLetterPath != null && employerLetterPath!.isNotEmpty)
              ? File(employerLetterPath!)
              : null;
    });
  }

  Future<void> _saveToDb(String status) async {
    final now = DateTime.now();
    final reg = DigitalRegistration(
      id: _localId,
      status: status, // "draft" or "pending"
      data: _collectFormData(),
      createdAt: now,
      updatedAt: now,
    );

    final id = await DigitalRegistrationDb.instance.upsert(reg);
    _localId = id;
  }

  // ------------------------------------------------------------
  // Sending
  Future<void> sendOnboarding({String? referralCode}) async {
    setState(() {
      _sending = true;
      _status = 'Preparing request...';
    });

    try {
      // ✅ URL now includes /client/{id} when available
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      String ymd(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final loanPurposeToSend = (loanpurpose == 'other')
          ? loanPurposeController.text.trim()
          : (loanpurpose ?? '');

      request.fields.addAll({
        "application_date": ymd(DateTime.now()),
        "government_employee_payroll": appTypeGovernmentPayroll ? "1" : "0",
        "short_term_private": appTypeShortTermPrivate ? "1" : "0",
        "psm_reservation_number": psmReservationNumberController.text.trim(),

        "title": titleValue ?? '',
        "surname": surnameController.text.trim(),
        "first_name": firstNameController.text.trim(),
        "id_number": idNumberController.text.trim(),
        "date_of_birth": dateOfBirth?.toIso8601String() ?? '',
        "gender": gender,
        "number_of_dependants": dependantsController.text.trim(),
        "marital_status": maritalStatus,

        "home_village_details": homeVillageController.text.trim(),
        "district": districtController.text.trim(),
        "traditional_authority": traditionalAuthorityController.text.trim(),
        "village": villageController.text.trim(),

        "physical_address": physicalAddressController.text.trim(),
        "town": cityController.text.trim(),
        "province": (province ?? '').toLowerCase(),

        "work_tel_no": workTelController.text.trim(),
        "home_tel_no": homeTelController.text.trim(),
        "mobile_tel_no1": mobile1Controller.text.trim(),
        "mobile_tel_no2": mobile2Controller.text.trim(),
        "email_address1": email1Controller.text.trim(),
        "email_address2": email2Controller.text.trim(),

        "fam_surname": famSurnameController.text.trim(),
        "fam_first_name": famFirstNameController.text.trim(),
        "fam_title": famTitle ?? '',
        "fam_relation": famRelationController.text.trim(),
        "fam_home_tel_no": famHomeTelController.text.trim(),
        "fam_mobile_tel_no": famMobileController.text.trim(),
        "fam_address": famAddressController.text.trim(),

        "employer_name": employerNameController.text.trim(),
        "specific_employer": employerSpecificController.text.trim(),
        "department": departmentController.text.trim(),
        "job_title": jobTitleController.text.trim(),
        "employee_code": employerCodeController.text.trim(),
        "length_of_service_years": lengthYearsController.text.trim(),
        "length_of_service_months": lengthMonthsController.text.trim(),
        "full_staff": employedFullTime ? "1" : "0",
        "gross_annual_salary": grossAnnualController.text.trim(),
        "net_monthly_income": netMonthlyController.text.trim(),
        "work_address": workAddressController.text.trim(),
        "work_city": workCityController.text.trim(),
        "work_province": (workProvince ?? '').toLowerCase(),
        "work_salary_frequency": salaryFrequency,
        "salary_pay_date": salaryPayDate?.toIso8601String() ?? '',

        "bank_name": bankNameController.text.trim(),
        "account_holder": accountHolderController.text.trim(),
        "branch_name": branchNameController.text.trim(),
        "branch_code": branchCodeController.text.trim(),
        "account_number": accountNumberController.text.trim(),
        "account_type": accountType,
        "is_salary_paid_to_this_account": salaryPaidIntoAccount ? "1" : "0",
        "account_usage_years": accountUsageYearsController.text.trim(),
        "account_usage_months": accountUsageMonthsController.text.trim(),
        "salary_been_transferred_for_3_months":
            salaryTransferred3Months ? "1" : "0",

        "total_applied_for": totalAppliedController.text.trim(),
        "total_amount_approved": totalApprovedController.text.trim(),
        "cash_to_client": cashToClientController.text.trim(),
        "loan_period": loanPeriodController.text.trim(),
        "admin_fee": adminFeeController.text.trim(),
        "interest": interestController.text.trim(),
        "total_collectable": totalCollectableController.text.trim(),
        "monthly_installment": monthlyInstalmentController.text.trim(),
        "loan_purpose": loanPurposeToSend,

        "referal_agent_code": referralCode ?? "",
      });

      Future<void> tryAttach(String name, String? filePath) async {
        if (filePath == null) return;
        final f = File(filePath);
        if (!await f.exists()) return;

        request.files.add(
          await http.MultipartFile.fromPath(
            name,
            filePath,
            filename: path.basename(filePath),
          ),
        );
      }

      await tryAttach('client_signature', clientSignaturePath);
      await tryAttach('front_of_id', identificationPath);
      await tryAttach('back_of_id', identificationPathBack);
      await tryAttach('latest_payslip', latestPayslipPath);
      await tryAttach('bank_statement', bankStatementPath);
      await tryAttach('employer_letter', employerLetterPath);
      await tryAttach('customer_photo', customerPhoto);
      await tryAttach('selfie', self);

      setState(() => _status = 'Sending request...');

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() => _sending = false);

      Map<String, dynamic>? jsonResponse;
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) jsonResponse = decoded;
      } catch (_) {
        jsonResponse = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _status = 'Success';
          _submittedToServer = true;
        });

        await _saveToDb('pending');

        final createdId = _extractCreatedId(jsonResponse);
        if (createdId != null && createdId.isNotEmpty) {
          await _saveServerIdToLocal(createdId);

          // ✅ also keep in runtime state for URL if you open again
          _clientIdFromPreview = createdId;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server id received and stored: $createdId'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No server id returned — saved locally as pending.',
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            Future.delayed(const Duration(seconds: 2), () {
              if (!mounted) return;
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => Home()),
              );
            });

            return const AlertDialog(
              title: Text('Success'),
              content: Text("You have successfully submitted the application."),
            );
          },
        );
      } else {
        setState(() => _status = 'Failed');

        String errorMessage = 'Unknown error';
        if (jsonResponse != null) {
          errorMessage = (jsonResponse['message'] ??
                  jsonResponse['error'] ??
                  jsonResponse.toString())
              .toString();
        } else if (response.body.isNotEmpty) {
          errorMessage = response.body;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission failed: $errorMessage'),
            backgroundColor: AppColors.danger,
          ),
        );

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exception: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
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

  // ------------------------------------------------------------
  // UI helpers (unchanged)

  Future<void> pickImage(Function(File) onSelected) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (file != null) {
      onSelected(File(file.path));
      setState(() {});
    }
  }

  void _onReferralPressed() {
    if (!acceptedDeclaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the declaration before submitting a referral',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Referral Agent'),
          content: TextField(
            controller: referralAgentController,
            decoration: const InputDecoration(
              labelText: 'Agent ID',
              border: OutlineInputBorder(),
              hintText: 'Enter referral agent code',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = referralAgentController.text.trim();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter the agent ID')),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                sendOnboarding(referralCode: code);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    // ✅ Priority order:
    // 1) data from client preview (autofill bounced)
    // 2) draftData (local db draft)
    // 3) localId as before
    if (widget.clientPreviewData != null) {
      final normalized = _normalizeClientPreviewData(widget.clientPreviewData!);

      // ✅ pick client id for URL
      _clientIdFromPreview = widget.clientId ??
          _extractClientIdFromMap(widget.clientPreviewData!) ??
          _extractClientIdFromMap(normalized);

      _loadFromData(normalized);
    } else if (widget.draftData != null) {
      _localId = widget.localId;
      _loadFromData(widget.draftData!);
    }

    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _signatureListener = () {
      final has = !_signatureController.isEmpty;
      if (mounted && has != _signatureHasData) {
        setState(() => _signatureHasData = has);
      }
    };
    _signatureController.addListener(_signatureListener);
  }

  // ----------------------------
  // (rest of your file stays same)
  // ✅ Keep your existing validateCurrentStep(), UI steps, dispose(), build(), etc.

  // NOTE: you already have placeholders for steps; no changes needed there.

  // ------------------------------------------------------------
  // Steps UI placeholders remain the same in your snippet

  Widget _personalInformationStep() => const SizedBox.shrink();
  Widget _addressDetailStep() => const SizedBox.shrink();
  Widget _contactDetailsStep() => const SizedBox.shrink();
  Widget _familyMemberStep() => const SizedBox.shrink();
  Widget _employmentDetailStep() => const SizedBox.shrink();
  Widget _bankingDetailsStep() => const SizedBox.shrink();
  Widget _supportingDocsStep() => const SizedBox.shrink();
  Widget _loanScheduleStep() => const SizedBox.shrink();
  Widget _declarationStep() => const SizedBox.shrink();
  Widget _reviewStep() => const SizedBox.shrink();

  List<Widget> get _steps => [
        _personalInformationStep(),
        _addressDetailStep(),
        _contactDetailsStep(),
        _familyMemberStep(),
        _employmentDetailStep(),
        _bankingDetailsStep(),
        _supportingDocsStep(),
        _loanScheduleStep(),
        _declarationStep(),
        _reviewStep(),
      ];

  @override
  void dispose() {
    _pageController.dispose();

    systemInfoController.dispose();
    psmReservationNumberController.dispose();
    surnameController.dispose();
    firstNameController.dispose();
    idNumberController.dispose();
    dependantsController.dispose();
    homeVillageController.dispose();
    physicalAddressController.dispose();
    cityController.dispose();
    postalAddressController.dispose();
    workTelController.dispose();
    homeTelController.dispose();
    mobile1Controller.dispose();
    mobile2Controller.dispose();
    email1Controller.dispose();
    email2Controller.dispose();
    famSurnameController.dispose();
    famFirstNameController.dispose();
    famRelationController.dispose();
    famHomeTelController.dispose();
    famMobileController.dispose();
    famAddressController.dispose();
    employerNameController.dispose();
    employerSpecificController.dispose();
    departmentController.dispose();
    jobTitleController.dispose();
    employerCodeController.dispose();
    lengthYearsController.dispose();
    lengthMonthsController.dispose();
    grossAnnualController.dispose();
    netMonthlyController.dispose();
    workAddressController.dispose();
    workCityController.dispose();
    bankNameController.dispose();
    accountHolderController.dispose();
    branchNameController.dispose();
    branchCodeController.dispose();
    accountNumberController.dispose();
    accountUsageMonthsController.dispose();
    accountUsageYearsController.dispose();
    baseLendingRateController.dispose();
    effectiveInterestRateController.dispose();
    netPayController.dispose();
    maxAllowedInstalmentController.dispose();
    totalAppliedController.dispose();
    totalApprovedController.dispose();
    cashToClientController.dispose();
    loanPeriodController.dispose();
    adminFeeController.dispose();
    interestController.dispose();
    totalCollectableController.dispose();
    monthlyInstalmentController.dispose();
    loanPurposeController.dispose();
    referralAgentController.dispose();

    _signatureController.removeListener(_signatureListener);
    _signatureController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (!_submittedToServer) {
          await _saveToDb('draft');
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Center(
            child: Text(
              "Digital Registration",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          backgroundColor: AppColors.primary,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _steps.length,
                    backgroundColor: Colors.grey.shade300,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                    minHeight: 6,
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _steps,
                      onPageChanged: (i) => setState(() => _currentStep = i),
                    ),
                  ),
                ],
              ),
              if (_sending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Submitting application...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
