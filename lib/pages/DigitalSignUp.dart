import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pfs_agent/config/api_config.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'FullScreenSignaturePage.dart';
import 'database/digital_registration_db.dart'; // adjust path as needed


import '../layouts/Colors.dart'; // keep your AppColors.primary
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';


class DigitalSignUp extends StatefulWidget {
  final Map<String, dynamic>? draftData;
  final int? localId; // id in digital_registrations table

  const DigitalSignUp({
    Key? key,
    this.draftData,
    this.localId,
  }) : super(key: key);

  @override
  DigitalSignUpState createState() => DigitalSignUpState();
}


class DigitalSignUpState extends State<DigitalSignUp> {

  //this is for the database
  int? _localId;              // ID of the record in SQLite
  bool _submittedToServer = false;


  // --- Signature capture state ---
  late final SignatureController _signatureController;
  bool _signatureHasData = false;


  final PageController _pageController = PageController();
  int _currentStep = 0;

  // --- Controllers & state for all fields (grouped by section) ---
  // 1. System information
  final TextEditingController systemInfoController = TextEditingController();
  DateTime? applicationDate;

  // 2. Application type
  bool appTypeGovernmentPayroll = false;
  bool appTypeShortTermPrivate = false;
  final TextEditingController psmReservationNumberController =
  TextEditingController();

  // 3. Personal information
  String? titleValue;
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
  final TextEditingController traditionalAuthorityController = TextEditingController();

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
  String? famTitle;
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
  final TextEditingController accountHolderController =
  TextEditingController();
  final TextEditingController branchNameController = TextEditingController();
  final TextEditingController branchCodeController = TextEditingController();
  final TextEditingController accountNumberController =
  TextEditingController();
  String accountType = 'current';
  bool salaryPaidIntoAccount = true;
  final TextEditingController accountUsageYearsController =
  TextEditingController();
  final TextEditingController accountUsageMonthsController =
  TextEditingController();
  bool salaryTransferred3Months = false;

  // 9. Supporting documentation (file placeholders)
  String? idFileName;
  String? payslipFileName;
  String? bankStatementFileName;
  String? employerLetterFileName;
  final TextEditingController referralAgentController = TextEditingController();


  String? token;

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
  final TextEditingController monthlyInstalmentController =TextEditingController();
  String? loanpurpose;
  TextEditingController loanPurposeController = TextEditingController();
  String? referralCode; // as a field


  // 11. Declaration and signature
  bool acceptedDeclaration = false;
  String? clientSignatureFile;

  // Form keys (optional per page if you want validation)
  final _formKeys = List.generate(13, (_) => GlobalKey<FormState>());

  File? idCopy;
  File? payslipCopy;
  File? bankStatementCopy;
  File? employerLetterCopy;
  File? signatureCopy;
  File? selfCopy;
  File? identityBackCopy;
  File? customerPhotoCopy;


//................................................................................................................................................................................................................



  //this is for the sending the data to the server
  bool _sending = false;
  String _status = 'Idle';

  String? clientSignaturePath;
  String? identificationPath;
  String? latestPayslipPath;
  String? bankStatementPath;
  String? employerLetterPath;
  String? identificationPathBack;
  String? customerPhoto;
  String? self;

  final String url =
      ApiConfig.baseUrl+'/client';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signature saved')));
    } else {
      // user cancelled (or no path returned)
    }
  }





  /// Try to extract the server-created id from a variety of response shapes.
  String? _extractCreatedId(Map<String, dynamic>? jsonResp) {
    if (jsonResp == null) return null;

    // Common patterns:
    // { "data": { "id": "abc123", ... } }
    // { "data": { "client_id": "abc123" } }
    // { "data": "abc123" }
    // { "id": "abc123" }  (rare)
    final topLevelId = jsonResp['id'];
    if (topLevelId != null) return topLevelId.toString();

    final data = jsonResp['data'];
    if (data == null) return null;

    if (data is String) {
      // maybe server returns a string id directly
      return data;
    }

    if (data is Map) {
      if (data['id'] != null) return data['id'].toString();
      if (data['client_id'] != null) return data['client_id'].toString();
      if (data['created_id'] != null) return data['created_id'].toString();
      if (data['data'] is Map && data['data']['id'] != null) return data['data']['id'].toString();
    }

    return null;
  }

  /// Save the received server id into the local DigitalRegistration row.
  /// - if _localId is known, update that row's data map with id_number.
  /// - otherwise insert a new pending row containing id_number.
  Future<void> _saveServerIdToLocal(String createdId) async {
    try {
      // Try to find an existing local record
      DigitalRegistration? existing;
      if (_localId != null) {
        final all = await DigitalRegistrationDb.instance.getAll();
        final matches = all.where((r) => r.id == _localId).toList();
        existing = matches.isNotEmpty ? matches.first : null;
      }

      Map<String, dynamic> dataMap;
      if (existing != null) {
        // ensure data is a Map
        if (existing.data is String) {
          try {
            dataMap = json.decode(existing.data as String) as Map<String, dynamic>;
          } catch (_) {
            dataMap = Map<String, dynamic>.from(_collectFormData());
          }
        } else if (existing.data is Map<String, dynamic>) {
          dataMap = Map<String, dynamic>.from(existing.data as Map<String, dynamic>);
        } else {
          dataMap = Map<String, dynamic>.from(_collectFormData());
        }
      } else {
        dataMap = Map<String, dynamic>.from(_collectFormData());
      }

      // set id_number (server id)
      dataMap['id_number'] = createdId;

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

      print('Saved server id $createdId into local digital registration (local id $savedId)');
    } catch (e) {
      print('Failed to save server id locally: $e');
    }
  }

  Map<String, dynamic> _collectFormData() {
    return {
      // --- Personal information ---
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

      // --- Address ---
      'physicalAddress': physicalAddressController.text,
      'city': cityController.text,
      'province': province,

      // --- Contact ---
      'workTel': workTelController.text,
      'homeTel': homeTelController.text,
      'mobile1': mobile1Controller.text,
      'mobile2': mobile2Controller.text,
      'email1': email1Controller.text,
      'email2': email2Controller.text,

      // --- Family member ---
      'famSurname': famSurnameController.text,
      'famFirstName': famFirstNameController.text,
      'famTitle': famTitle,
      'famRelation': famRelationController.text,
      'famHomeTel': famHomeTelController.text,
      'famMobile': famMobileController.text,
      'famAddress': famAddressController.text,

      // --- Employment ---
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

      // --- Banking ---
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

      // --- Loan schedule ---
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

      // --- Declaration ---
      'acceptedDeclaration': acceptedDeclaration,

      // --- File paths ---
      'clientSignaturePath': clientSignaturePath,
      'identificationPath': identificationPath,
      'identificationPathBack': identificationPathBack,
      'latestPayslipPath': latestPayslipPath,
      'bankStatementPath': bankStatementPath,
      'employerLetterPath': employerLetterPath,
      'customerPhoto': customerPhoto,
      'self': self,


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
      salaryTransferred3Months =
          data['salaryTransferred3Months'] ?? false;

      totalAppliedController.text = data['totalApplied'] ?? '';
      totalApprovedController.text = data['totalApproved'] ?? '';
      cashToClientController.text = data['cashToClient'] ?? '';
      loanPeriodController.text = data['loanPeriod'] ?? '';
      adminFeeController.text = data['adminFee'] ?? '';
      interestController.text = data['interest'] ?? '';
      totalCollectableController.text = data['totalCollectable'] ?? '';
      monthlyInstalmentController.text =
          data['monthlyInstalment'] ?? '';
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

      // 🔹 Rebuild File objects for image previews from the saved paths
      if (clientSignaturePath != null && clientSignaturePath!.isNotEmpty) {
        signatureCopy = File(clientSignaturePath!);
      } else {
        signatureCopy = null;
      }

      if (identificationPath != null && identificationPath!.isNotEmpty) {
        idCopy = File(identificationPath!);
      } else {
        idCopy = null;
      }

      if (identificationPathBack != null && identificationPathBack!.isNotEmpty) {
        identityBackCopy = File(identificationPathBack!);
      } else {
        identityBackCopy = null;
      }

      if (customerPhoto != null && customerPhoto!.isNotEmpty) {
        customerPhotoCopy = File(customerPhoto!);
      } else {
        customerPhotoCopy = null;
      }

      if (self != null && self!.isNotEmpty) {
        selfCopy = File(self!);
      } else {
        selfCopy = null;
      }

      if (latestPayslipPath != null && latestPayslipPath!.isNotEmpty) {
        payslipCopy = File(latestPayslipPath!);
      } else {
        payslipCopy = null;
      }

      if (bankStatementPath != null && bankStatementPath!.isNotEmpty) {
        bankStatementCopy = File(bankStatementPath!);
      } else {
        bankStatementCopy = null;
      }

      if (employerLetterPath != null && employerLetterPath!.isNotEmpty) {
        employerLetterCopy = File(employerLetterPath!);
      } else {
        employerLetterCopy = null;
      }

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


  Future<void> sendOnboarding({String? referralCode}) async {
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
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

      // Build fields (only a subset shown here — keep/change as you need)
      request.fields.addAll({
        "application_date": "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2,'0')}-${DateTime.now().day.toString().padLeft(2,'0')}",
        "government_employee_payroll": appTypeGovernmentPayroll ? "1" : "0",
        "short_term_private": appTypeShortTermPrivate ? "1" : "0",
        "psm_reservation_number": psmReservationNumberController.text.trim(),
        "title": titleValue ?? '',
        "surname": surnameController.text.toString(),
        "first_name": firstNameController.text.toString(),
        "id_number": idNumberController.text.toString(),
        "date_of_birth": dateOfBirth?.toIso8601String() ?? '',
        "gender": gender,
        "number_of_dependants": dependantsController.text.toString(),
        "marital_status": maritalStatus,
        "home_village_details": homeVillageController.text.toString(),
        "district": districtController.text.toString(),
        "traditional_authority": traditionalAuthorityController.text.toString(),
        "village": villageController.text.toString(),
        "physical_address": physicalAddressController.text.toString(),
        "town": cityController.text.toString(),
        "province": province?.toString().toLowerCase() ?? '',
        "work_tel_no": workTelController.text.toString(),
        "home_tel_no": homeTelController.text.toString(),
        "mobile_tel_no1": mobile1Controller.text.toString(),
        "mobile_tel_no2": mobile2Controller.text.toString(),
        "fam_surname": famSurnameController.text.toString(),
        "fam_first_name": famFirstNameController.text.toString(),
        "fam_title": famTitle ?? '',
        "fam_relation": famRelationController.text.toString(),
        "fam_home_tel_no": famHomeTelController.text.toString(),
        "fam_mobile_tel_no": famMobileController.text.toString(),
        "fam_address": famAddressController.text.toString(),
        "employer_name": employerNameController.text.toString(),
        "specific_employer": employerSpecificController.text.toString(),
        "department": departmentController.text.toString(),
        "job_title": jobTitleController.text.toString(),
        "employee_code": employerCodeController.text.toString(),
        "length_of_service_years": lengthYearsController.text.toString(),
        "length_of_service_months": lengthMonthsController.text.toString(),
        "full_staff": employedFullTime == true ? "1" : "0",
        "gross_annual_salary": grossAnnualController.text.toString(),
        "net_monthly_income": netMonthlyController.text.toString(),
        "work_address": workAddressController.text.toString(),
        "work_city": workCityController.text.toString(),
        "work_province": workProvince?.toString().toLowerCase() ?? '',
        "work_salary_frequency": salaryFrequency,
        "salary_pay_date": salaryPayDate?.toIso8601String() ?? '',
        "bank_name": bankNameController.text.toString(),
        "account_holder": accountHolderController.text.toString(),
        "branch_name": branchNameController.text.toString(),
        "branch_code": branchCodeController.text.toString(),
        "account_number": accountNumberController.text.toString(),
        "account_type": accountType,
        "is_salary_paid_to_this_account": salaryPaidIntoAccount == true ? "1" : "0",
        "account_usage_years": accountUsageYearsController.text.toString(),
        "account_usage_months": accountUsageMonthsController.text.toString(),
        "salary_been_transferred_for_3_months": salaryTransferred3Months == true ? "1" : "0",
        "total_applied_for": totalAppliedController.text.toString(),
        "total_amount_approved": totalApprovedController.text.toString(),
        "cash_to_client": cashToClientController.text.toString(),
        "loan_period": loanPeriodController.text.toString(),
        "admin_fee": adminFeeController.text.toString(),
        "interest": interestController.text.toString(),
        "total_collectable": totalCollectableController.text.toString(),
        "monthly_installment": monthlyInstalmentController.text.toString(),
        "loan_purpose": ?loanpurpose.toString()=="Other"? loanPurposeController.text.toString(): loanpurpose,
        "referal_agent_code": referralCode ?? "",
      });

      Future<void> tryAttach(String name, String? filePath) async {
        if (filePath != null && await File(filePath).exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              name,
              filePath,
              filename: path.basename(filePath),
            ),
          );
        }
      }

      await tryAttach('client_signature', clientSignaturePath);
      await tryAttach('front_of_id', identificationPath);
      await tryAttach('latest_payslip', latestPayslipPath);
      await tryAttach('bank_statement', bankStatementPath);
      await tryAttach('employer_letter', employerLetterPath);
      await tryAttach('back_of_id', identificationPathBack);
      await tryAttach('customer_photo', customerPhoto);
      await tryAttach('selfie', self);

      setState(() {
        _status = 'Sending request...';
      });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() {
        _sending = false;
      });

      // parse safely
      Map<String, dynamic>? jsonResponse;
      try {
        jsonResponse = json.decode(response.body) as Map<String, dynamic>?;
      } catch (_) {
        jsonResponse = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _status = 'Success';
          _submittedToServer = true;
        });

        // Save locally as pending first (if you haven't already)
        await _saveToDb('pending');

        // Extract created id (flexible)
        final createdId = _extractCreatedId(jsonResponse);

        if (createdId != null && createdId.isNotEmpty) {
          // store id into local DB record and show snackbar
          await _saveServerIdToLocal(createdId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Server id received and stored: $createdId'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          // no id in response — show notice to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No server id returned — saved locally as pending.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }

        // show success dialog (unchanged)
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Success'),
            content: const Text("You have successfully submitted the application."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
            ],
          ),
        );
      } else {
        setState(() {
          _status = 'Failed';
        });

        String errorMessage = 'Unknown error';
        if (jsonResponse != null) {
          errorMessage = jsonResponse['message'] ?? jsonResponse['error'] ?? jsonResponse.toString();
        } else if (response.body.isNotEmpty) {
          errorMessage = response.body;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $errorMessage'), backgroundColor: AppColors.danger),
        );

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
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
        SnackBar(content: Text('Exception: ${e.toString()}'), backgroundColor: AppColors.danger),
      );

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Exception'),
          content: Text(e.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
          ],
        ),
      );

      print(e.toString());
    }
  }


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


  Future<String?> getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      // Retrieve the token, returns null if not found
      token = prefs.getString('token');
      print("Token: $token");
      return token;
    } catch (e) {
      print("Error getting token: $e");
      return null;
    }
  }

  void _onReferralPressed() {
    // Make sure declaration is accepted before sending
    if (!acceptedDeclaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the declaration before submitting a referral'),
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
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final code = referralAgentController.text.trim();
                if (code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter the agent ID'),
                    ),
                  );
                  return;
                }

                Navigator.of(ctx).pop(); // close dialog
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
    getToken();

    // ✅ Only load when an explicit draft is passed (from MyClients)
    if (widget.draftData != null) {
      _localId = widget.localId;
      _loadFromData(widget.draftData!);
    }
    // no else: opening DigitalSignUp() -> always blank form


    // initialize signature controller
    _signatureController = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

// listen to changes so we can enable/disable save on the pad
    _signatureController.addListener(() {
      final has = !_signatureController.isEmpty;
      if (mounted && has != _signatureHasData) {
        setState(() => _signatureHasData = has);
      }
    });

  }



  Future<void> _loadDraftIfAny() async {
    final draft = await DigitalRegistrationDb.instance.getLatestDraft();
    if (draft != null) {
      _localId = draft.id;
      _loadFromData(draft.data);
    }
  }




  /// Validate required fields for the current step/page.
  /// Returns true when valid, otherwise shows a SnackBar and returns false.
  ///
  /// the commands
  bool validateCurrentStep() {
    final missing = <String>[];

    switch (_currentStep) {
    // 0 => Personal Information step (_personalInformationStep)
      case 0:
        if (titleValue == null || titleValue!.isEmpty) missing.add('Title');
        if (firstNameController.text.trim().isEmpty) missing.add('First name');
        if (surnameController.text.trim().isEmpty) missing.add('Surname');
        if (idNumberController.text.trim().isEmpty) missing.add('ID number');
        if (dateOfBirth == null) missing.add('Date of birth');
        //write the district, tradional and village
        if (districtController.text.trim().isEmpty) missing.add('District');
        if (traditionalAuthorityController.text.trim().isEmpty) missing.add('Traditional Authority');
        if (villageController.text.trim().isEmpty) missing.add('Village');

        break;

    // 1 => Address Details (_addressDetailStep)
      case 1:
        if (physicalAddressController.text.trim().isEmpty) missing.add('Physical address');
        if (cityController.text.trim().isEmpty) missing.add('City/Town');
        if (province == null || province!.isEmpty) missing.add('Region');
        break;

    // 2 => Contact Details (_contactDetailsStep)
      case 2:
        if (workTelController.text.trim().isEmpty) missing.add('work tel. no');
        if (mobile1Controller.text.trim().isEmpty) missing.add('mobile Tel no 1');
        break;

    // 3 => Family Member (_familyMemberStep)
      case 3:
        if (famSurnameController.text.trim().isEmpty) missing.add('Family member surname');
        if (famFirstNameController.text.trim().isEmpty) missing.add('Family member first name');
        if (famRelationController.text.trim().isEmpty) missing.add('Family member relation');
        //if (famHomeTelController.text.trim().isEmpty) missing.add('Family member home tel. no');
        if (famMobileController.text.trim().isEmpty) missing.add('Family member mobile tel. no');
        if (famAddressController.text.trim().isEmpty) missing.add('Family member address');

        break;

    // 4 => Employment Details (_employmentDetailStep)
      case 4:
        if (employerNameController.text.trim().isEmpty) missing.add('Employer name');
        if (departmentController.text.trim().isEmpty) missing.add('Department');
        if (jobTitleController.text.trim().isEmpty) missing.add('Job title');
        if (employerCodeController.text.trim().isEmpty) missing.add('Employer code / payroll no');
        //if (lengthMonthsController.text.trim().isEmpty) missing.add("lenth of service(months)");
        //if (lengthYearsController.text.trim().isEmpty) missing.add("length of service(year)");
        //if (grossAnnualController.text.trim().isEmpty) missing.add('Gross annual salary');
        if (netMonthlyController.text.trim().isEmpty) missing.add('Net monthly income');
        if (workCityController.text.trim().isEmpty) missing.add('Work city/town');
        if (workProvince == null || workProvince!.isEmpty) missing.add('Work region');


        break;

    // 5 => Banking Details (_bankingDetailsStep)
      case 5:
        if (bankNameController.text.trim().isEmpty) missing.add('Bank name');
        if (accountHolderController.text.trim().isEmpty) missing.add('Account holder');
        if (accountNumberController.text.trim().isEmpty) missing.add('Account number');
        if (branchNameController.text.trim().isEmpty) missing.add('Branch name');
        //if (accountUsageMonthsController.text.trim().isEmpty) missing.add('Account usage (months)');
        //if (accountUsageYearsController.text.trim().isEmpty) missing.add('Account usage (years)');
        if (accountType == null || accountType!.isEmpty) missing.add('Account type');




        break;

    // 6 => Supporting Documents (_supportingDocsStep)
      case 6:
        if (clientSignaturePath == null || clientSignaturePath!.isEmpty) missing.add('Client signature file');
        if (identificationPath == null || identificationPath!.isEmpty) missing.add('Front Identification file');
        if (identificationPathBack == null || identificationPathBack!.isEmpty) missing.add('Back Identification file');
        //if (latestPayslipPath == null || latestPayslipPath!.isEmpty) missing.add('Latest Payslip file');
        //if (bankStatementPath == null || bankStatementPath!.isEmpty) missing.add('Bank Statement file');
        //if (employerLetterPath == null || employerLetterPath!.isEmpty) missing.add('Employer Letter file');
        if (customerPhoto == null || customerPhoto!.isEmpty) missing.add('Customer Photo file');
        if (self == null || self!.isEmpty) missing.add('Selfie file');

        // (optionally) you can require identificationPath, latestPayslipPath, etc.
        break;

    // 7 => Loan Schedule (_loanScheduleStep)
      case 7:
      //if (baseLendingRateController.text.trim().isEmpty) missing.add('Base lending rate');
      //if (effectiveInterestRateController.text.trim().isEmpty) missing.add('Effective interest rate');
      //if (firstInstalmentDate == null) missing.add('First instalment date');
      //if (lastInstalmentDate == null) missing.add('Last instalment date');
        if (totalAppliedController.text.trim().isEmpty) missing.add('Total Applied for');
        break;

    // 8 => Declaration and Signature (_declarationStep)
      case 8:
      //if (!acceptedDeclaration) missing.add('Accept declaration');
      //if (clientSignatureFile == null || clientSignatureFile!.isEmpty) missing.add('Uploaded client signature (declaration)');
        break;

    // 9 => Extra / Review (no required fields)
      default:
        break;
    }

    if (missing.isNotEmpty) {
      final msg = 'Please complete: ${missing.join(', ')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: Duration(seconds: 5)),
      );
      return false;
    }

    // optional per-form validation if you used Form+TextFormField validators:
    final form = _formKeys[_currentStep];
    if (form.currentState != null) {
      final valid = form.currentState!.validate();
      if (!valid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fix the errors in the form.')),
        );
        return false;
      }
    }

    return true;
  }


  // Replace your existing _nextStep with this version that validates first.
  void _nextStep() {
    // If we are on the last page, trigger submit path


    final isLast = _currentStep == _steps.length - 1;

    // If not last, validate current step before moving forward
    if (!isLast) {
      final ok = validateCurrentStep();
      if (!ok) return; // don't advance if validation fails

      // move to next
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Last page behavior: final validations and submit
    // Example: ensure we have client signature path before sending


    // also validate declaration if that exists (declaration step index may vary)
    if (!acceptedDeclaration) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the declaration before submitting')),
      );
      return;
    }

    // If everything is good, call sendOnboarding()
    sendOnboarding();
  }


  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<DateTime?> _pickDate(BuildContext ctx, DateTime? initial) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    return picked;
  }

  // placeholder file picker
  Future<void> _pickFilePlaceholder(String which) async {
    // Replace with actual file pick logic using file_picker or image_picker.
    // For now we just simulate selecting a file by assigning a name with timestamp.
    final simulatedName = "$which-${DateTime.now().millisecondsSinceEpoch}.pdf";
    setState(() {
      switch (which) {
        case 'id':
          idFileName = simulatedName;
          break;
        case 'payslip':
          payslipFileName = simulatedName;
          break;
        case 'bank':
          bankStatementFileName = simulatedName;
          break;
        case 'letter':
          employerLetterFileName = simulatedName;
          break;
        case 'signature':
          clientSignatureFile = simulatedName;
          break;
      }
    });
  }

  void _submitAll() {
    // Here you'd collect all values, validate and submit to your backend.
    // For demo, we just show a dialog with some summary.
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Applicant: ${firstNameController.text} ${surnameController.text}'),
              Text('ID: ${idNumberController.text}'),
              Text('Email: ${email1Controller.text}'),
              Text('Application Date: ${applicationDate?.toLocal().toIso8601String() ?? '-'}'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK'))
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        'Step ${_currentStep + 1} of 10',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isLast = _currentStep == 9;
    return Row(
      children: [
        if (_currentStep > 0 && !_sending)
          Expanded(
            child: OutlinedButton(
              onPressed: _previousStep,
              child: const Text('Previous'),
            ),
          )
        else
          const Expanded(child: SizedBox()),

        const SizedBox(width: 5),

        if (isLast)
          Expanded(
            child: ElevatedButton(
              onPressed: _sending ? null : _onReferralPressed,   // ⬅ disable when sending
              child: const Text(
                "Referral",
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
            ),
          ),

        const SizedBox(width: 5),

        Expanded(
          child: ElevatedButton(
            onPressed: _sending ? null : _nextStep,              // ⬅ disable when sending
            child: Text(
              isLast
                  ? (_sending ? 'Sending...' : 'Submit')
                  : 'Next',
              style: const TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }


  // --- Each step as a widget (scrollable) ---
  Widget _systemInformationStep() {
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader(),
            Text('System Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            TextFormField(
              controller: systemInfoController,
              decoration: InputDecoration(labelText: 'System Information',
                border: OutlineInputBorder(),),
            ),
            SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Application Date'),
              subtitle: Text(applicationDate == null ? 'Select date' : applicationDate!.toLocal().toIso8601String().split('T').first),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final d = await _pickDate(context, applicationDate);
                if (d != null) setState(() => applicationDate = d);
              },
            ),
            SizedBox(height: 20),
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _applicationTypeStep() {
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Application Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          CheckboxListTile(
            title: Text('Government Employee Payroll'),
            value: appTypeGovernmentPayroll,
            onChanged: (v) => setState(() => appTypeGovernmentPayroll = v ?? false),
          ),
          CheckboxListTile(
            title: Text('Short Term Private'),
            value: appTypeShortTermPrivate,
            onChanged: (v) => setState(() => appTypeShortTermPrivate = v ?? false),
          ),
          TextFormField(
            controller: psmReservationNumberController,
            decoration: InputDecoration(labelText: 'PSM Reservation Number',
              border: OutlineInputBorder(),),
          ),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _personalInformationStep() {
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: titleValue,
            decoration: InputDecoration(labelText: 'Title',
              border: OutlineInputBorder(),),
            items: ['Mr', 'Mrs', 'Miss', 'Dr', 'Prof'].map((t) => DropdownMenuItem(value: t.toLowerCase(), child: Text(t))).toList(),
            onChanged: (v) => setState(() => titleValue = v),
          ),


          SizedBox(height: 8),
          TextFormField(controller: firstNameController, decoration: InputDecoration(labelText: 'First Name',
            border: OutlineInputBorder(),)),


          SizedBox(height: 8),
          TextFormField(controller: surnameController, decoration: InputDecoration(labelText: 'Surname',
            border: OutlineInputBorder(),)),

          SizedBox(height: 8),
          TextFormField(controller: idNumberController, decoration: InputDecoration(labelText: 'ID Number',
            border: OutlineInputBorder(),)),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Date of Birth'),
            subtitle: Text(dateOfBirth == null ? 'Select date' : dateOfBirth!.toLocal().toIso8601String().split('T').first),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              final d = await _pickDate(context, dateOfBirth);
              if (d != null) setState(() => dateOfBirth = d);
            },
          ),
          SizedBox(height: 8),
          Text('Gender'),
          Row(
            children: [
              Radio<String>(value: 'male', groupValue: gender, onChanged: (v) => setState(() => gender = v!)),
              Text('Male'),
              Radio<String>(value: 'female', groupValue: gender, onChanged: (v) => setState(() => gender = v!)),
              Text('Female'),
            ],
          ),
          TextFormField(controller: dependantsController, decoration: InputDecoration(labelText: 'Number of Dependants',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),

          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: maritalStatus,
            decoration: InputDecoration(labelText: 'Marital Status',
              border: OutlineInputBorder(),),
            items: ['single', 'married', 'divorced'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => maritalStatus = v ?? maritalStatus),
          ),

          SizedBox(height: 8),
          TextFormField(controller: districtController, decoration: InputDecoration(labelText: 'Home District',
            border: OutlineInputBorder(),)),SizedBox(height: 8),

          TextFormField(controller: traditionalAuthorityController, decoration: InputDecoration(labelText: 'Home Traditional Authority',
            border: OutlineInputBorder(),)),SizedBox(height: 8),

          TextFormField(controller: villageController, decoration: InputDecoration(labelText: 'Home Village',
            border: OutlineInputBorder(),)),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _addressDetailStep() {
    return Form(
      key: _formKeys[3],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Address Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          TextFormField(controller: physicalAddressController, decoration: InputDecoration(labelText: 'Physical Address',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: cityController, decoration: InputDecoration(labelText: 'City/Town',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: province,
            decoration: InputDecoration(labelText: 'Region',
              border: OutlineInputBorder(),),
            items: ['Northern', 'Central', 'Southern'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => province = v),
          ),
          SizedBox(height: 8),
          //TextFormField(controller: postalAddressController, decoration: InputDecoration(labelText: 'Postal Address', border: OutlineInputBorder(),)),
          //SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _contactDetailsStep() {
    return Form(
      key: _formKeys[4],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Contact Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          TextFormField(controller: workTelController, decoration: InputDecoration(labelText: 'Work Tel. No',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone,),
          SizedBox(height: 8),
          TextFormField(controller: homeTelController, decoration: InputDecoration(labelText: 'Home Tel. No(optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone,), //optinal
          SizedBox(height: 8),
          TextFormField(controller: mobile1Controller, decoration: InputDecoration(labelText: 'Mobile Tel No 1',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone),
          SizedBox(height: 8),
          TextFormField(controller: mobile2Controller, decoration: InputDecoration(labelText: 'Mobile Tel No 2(optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone),
          SizedBox(height: 8),
          TextFormField(controller: email1Controller, decoration: InputDecoration(labelText: 'Email Address 1(optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.emailAddress),
          SizedBox(height: 8),
          TextFormField(controller: email2Controller, decoration: InputDecoration(labelText: 'Email Address 2(optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.emailAddress),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _familyMemberStep() {
    return Form(
      key: _formKeys[5],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Details of a Family Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          TextFormField(controller: famSurnameController, decoration: InputDecoration(labelText: 'Surname',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: famFirstNameController, decoration: InputDecoration(labelText: 'First Name',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: famTitle, // famTitle stores lowercase like 'mr', 'mrs'
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            items: ['Mr', 'Mrs', 'Miss', 'Dr']
                .map((t) =>
                DropdownMenuItem(
                  value: t.toLowerCase(),      // store lowercase value
                  child: Text(t),             // show uppercase / title-case text
                ))
                .toList(),
            onChanged: (v) {
              setState(() {
                famTitle = v;    // keep the lowercase value
              });
            },
          ),



          SizedBox(height: 8),

          TextFormField(controller: famRelationController, decoration: InputDecoration(labelText: 'Relation',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),

          TextFormField(controller: famHomeTelController, decoration: InputDecoration(labelText: 'Home Tel no(Optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone,),

          SizedBox(height: 8),
          TextFormField(controller: famMobileController, decoration: InputDecoration(labelText: 'Mobile Tel no',
            border: OutlineInputBorder(),), keyboardType: TextInputType.phone,),

          SizedBox(height: 8),
          TextFormField(controller: famAddressController, decoration: InputDecoration(labelText: 'Address',
            border: OutlineInputBorder(),)),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _employmentDetailStep() {
    return Form(
      key: _formKeys[6],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Employment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          TextFormField(controller: employerNameController, decoration: InputDecoration(labelText: 'Name of Employer / Ministry',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: employerSpecificController, decoration: InputDecoration(labelText: 'Specific Employer',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: departmentController, decoration: InputDecoration(labelText: 'Department',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: jobTitleController, decoration: InputDecoration(labelText: 'Job Title',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: employerCodeController, decoration: InputDecoration(labelText: 'Employer Code / Payroll No',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextFormField(controller: lengthYearsController, decoration: InputDecoration(labelText: 'Length of Service (years)',
                border: OutlineInputBorder(),), keyboardType: TextInputType.number)),
              SizedBox(width: 8),
              Expanded(child: TextFormField(controller: lengthMonthsController, decoration: InputDecoration(labelText: 'Months',
                border: OutlineInputBorder(),), keyboardType: TextInputType.number)),
            ],
          ),
          SizedBox(height: 8),
          Text('Are you employed as a full time staff member?'),
          Row(children: [
            Radio<bool>(value: true, groupValue: employedFullTime, onChanged: (v) => setState(() => employedFullTime = v!)),
            Text('Yes'),
            Radio<bool>(value: false, groupValue: employedFullTime, onChanged: (v) => setState(() => employedFullTime = v!)),
            Text('No'),
          ]),
          TextFormField(controller: grossAnnualController, decoration: InputDecoration(labelText: 'Gross Annual Salary(optional)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: netMonthlyController, decoration: InputDecoration(labelText: 'Net Monthly Income',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: workAddressController, decoration: InputDecoration(labelText: 'Work Address',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: workCityController, decoration: InputDecoration(labelText: 'City / Town',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: workProvince,
            decoration: InputDecoration(labelText: 'Region',
              border: OutlineInputBorder(),),
            items: ['Northern', 'Central', 'Southern'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => workProvince = v),
          ),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: salaryFrequency,
            decoration: InputDecoration(labelText: 'Salary Frequency',
              border: OutlineInputBorder(),),
            items: ['monthly', 'weekly', 'other'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => salaryFrequency = v ?? salaryFrequency),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Salary Pay Date(Optional'),
            subtitle: Text(salaryPayDate == null ? 'Select date' : salaryPayDate!.toLocal().toIso8601String().split('T').first),
            trailing: Icon(Icons.calendar_today),
            onTap: () async {
              final d = await _pickDate(context, salaryPayDate);
              if (d != null) setState(() => salaryPayDate = d);
            },
          ),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _bankingDetailsStep() {
    return Form(
      key: _formKeys[7],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Banking Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          TextFormField(controller: bankNameController, decoration: InputDecoration(labelText: 'Bank Name',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: accountHolderController, decoration: InputDecoration(labelText: 'Account Holder',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: branchNameController, decoration: InputDecoration(labelText: 'Branch Name',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: branchCodeController, decoration: InputDecoration(labelText: 'Branch Code(Optional)',
            border: OutlineInputBorder(),)),
          SizedBox(height: 8),
          TextFormField(controller: accountNumberController, decoration: InputDecoration(labelText: 'Account Number',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: accountType,
            decoration: InputDecoration(labelText: 'Account Type',
              border: OutlineInputBorder(),),
            items: ['current', 'savings'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => accountType = v ?? accountType),
          ),
          SizedBox(height: 8),
          Text('Is salary paid into this account?'),
          Row(children: [
            Radio<bool>(value: true, groupValue: salaryPaidIntoAccount, onChanged: (v) => setState(() => salaryPaidIntoAccount = v!)),
            Text('Yes'),
            Radio<bool>(value: false, groupValue: salaryPaidIntoAccount, onChanged: (v) => setState(() => salaryPaidIntoAccount = v!)),
            Text('No'),
          ]),
          Row(children: [
            Expanded(child: TextFormField(controller: accountUsageYearsController, decoration: InputDecoration(labelText: 'Usage (years)',
              border: OutlineInputBorder(),), keyboardType: TextInputType.number)),
            SizedBox(width: 8),
            Expanded(child: TextFormField(controller: accountUsageMonthsController, decoration: InputDecoration(labelText: 'Months',
              border: OutlineInputBorder(),), keyboardType: TextInputType.number)),
          ]),
          SizedBox(height: 8),
          Text('Has salary been electronically transferred for 3 months?'),
          Row(children: [
            Radio<bool>(value: true, groupValue: salaryTransferred3Months, onChanged: (v) => setState(() => salaryTransferred3Months = v!)),
            Text('Yes'),
            Radio<bool>(value: false, groupValue: salaryTransferred3Months, onChanged: (v) => setState(() => salaryTransferred3Months = v!)),
            Text('No'),
          ]),
          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }
  void _openImagePreview(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text(
              'Preview',
              style: TextStyle(color: Colors.white),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(
                file,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget fileRow(String label, File? file, Function(File) onCapture) {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? img = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 85,
                    );
                    if (img != null) {
                      onCapture(File(img.path));
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 18),
                  label: const Text('Capture'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: file == null
                  ? const Center(
                child: Text(
                  'No image captured',
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : GestureDetector(
                onTap: () => _openImagePreview(file),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
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




  //pictures of supporting documents

  Widget _supportingDocsStep() {
    return Form(
      key: _formKeys[8],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Supporting Documentation Submitted', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),

          // --- Client signature (signature pad) ---
          Card(
            elevation: 4,
            shadowColor: Colors.blue.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Client signature',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _openSignaturePageAndGetResult,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Sign'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (signatureCopy != null)
                        IconButton(
                          tooltip: 'Remove signature',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              signatureCopy = null;
                              clientSignaturePath = null;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: signatureCopy == null
                        ? const Center(child: Text('No signature captured', style: TextStyle(color: Colors.grey)))
                        : GestureDetector(
                      onTap: () => _openImagePreview(signatureCopy!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          signatureCopy!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          fileRow('Identification (Front)', idCopy, (f) {
            setState(() {
              idCopy = f;
              identificationPath = f.path;
            });
          }),
          fileRow('Identification (Back)', identityBackCopy, (f) {
            setState(() {
              identityBackCopy = f;           // 👈 use the correct File variable
              identificationPathBack = f.path;
            });
          }),
          fileRow('Customer Photo', customerPhotoCopy, (f) {
            setState(() {
              customerPhotoCopy = f;          // 👈 use the correct File variable
              customerPhoto = f.path;
            });
          }),
          fileRow('Self (Customer and Agent)', selfCopy, (f) {
            setState(() {
              selfCopy = f;                   // 👈 use the correct File variable
              self = f.path;
            });
          }),
          fileRow('Latest payslip', payslipCopy, (f) {
            setState(() {
              payslipCopy = f;
              latestPayslipPath = f.path;
            });
          }),
          fileRow('Bank statement', bankStatementCopy, (f) {
            setState(() {
              bankStatementCopy = f;
              bankStatementPath = f.path;
            });
          }),
          fileRow('Employer letter', employerLetterCopy, (f) {
            setState(() {
              employerLetterCopy = f;
              employerLetterPath = f.path;
            });
          }),



          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _loanScheduleStep() {
    return Form(
      key: _formKeys[9],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Loan Schedule Detail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),

          TextFormField(controller: totalAppliedController, decoration: InputDecoration(labelText: 'Total Applied For',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: totalApprovedController, decoration: InputDecoration(labelText: 'Total Amount Approved',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: cashToClientController, decoration: InputDecoration(labelText: 'Cash to Client',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: loanPeriodController, decoration: InputDecoration(labelText: 'Loan Period (months)',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: adminFeeController, decoration: InputDecoration(labelText: 'Admin Fee',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: interestController, decoration: InputDecoration(labelText: 'Interest',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: totalCollectableController, decoration: InputDecoration(labelText: 'Total Collectable',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),
          SizedBox(height: 8),
          TextFormField(controller: monthlyInstalmentController, decoration: InputDecoration(labelText: 'Monthly Instalment',
            border: OutlineInputBorder(),), keyboardType: TextInputType.number),

          SizedBox(height: 8,),

          DropdownButtonFormField<String>(
            value: loanpurpose,
            decoration: InputDecoration(labelText: 'Loan Purpose',
              border: OutlineInputBorder(),),
            items: ['Education', 'Housing', 'Debt Payment', 'Funeral', 'Other'].map((t) => DropdownMenuItem(value: t.toLowerCase(), child: Text(t))).toList(),
            onChanged: (v){
              setState(() {
                loanpurpose = v;
              });
            },
          ),

          SizedBox(height: 8),
          if (loanpurpose == 'other')
            TextFormField(controller: loanPurposeController, decoration: InputDecoration(labelText: 'Specifying Loan Purpose', border: OutlineInputBorder(),)),

          SizedBox(height: 20),
          //shadreck
          _buildNavigationButtons(),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _reviewRow(String label, String? value) {
    final display = (value == null || value.trim().isEmpty) ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: Text(display),
          ),
        ],
      ),
    );
  }

  Widget _declarationStep() {
    return Form(
      key: _formKeys[10],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildStepHeader(),
          Text('Declaration and Signature', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text(
            'I have hereby applied for a loan in the amount fully disclosed herein. I confirm that I have studied all the documentation and that I have noted all cost and repayment detail.',
            style: TextStyle(),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Checkbox(value: acceptedDeclaration, onChanged: (v) => setState(() => acceptedDeclaration = v ?? false)),
              Flexible(child: Text('I accept the declaration above')),
            ],
          ),

          SizedBox(height: 20),
          _buildNavigationButtons(),
        ]),
      ),
    );
  }


  Widget _extraStepB() {
    String _fmtDate(DateTime? d) =>
        d == null ? '-' : d.toLocal().toIso8601String().split('T').first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader(),
          const Text(
            'Review',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please review the information below before submitting your application.',
          ),

          // PERSONAL INFORMATION
          _sectionTitle('Personal Information'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Title', titleValue?.toUpperCase()),
                  _reviewRow('First Name', firstNameController.text),
                  _reviewRow('Surname', surnameController.text),
                  _reviewRow('ID Number', idNumberController.text),
                  _reviewRow('Date of Birth', _fmtDate(dateOfBirth)),
                  _reviewRow('Gender', gender),
                  _reviewRow('No. of Dependants', dependantsController.text),
                  _reviewRow('Marital Status', maritalStatus),
                  _reviewRow('Home District', districtController.text),
                  _reviewRow('Home TA', traditionalAuthorityController.text),
                  _reviewRow('Home Village', villageController.text),
                ],
              ),
            ),
          ),

          // ADDRESS
          _sectionTitle('Address Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Physical Address', physicalAddressController.text),
                  _reviewRow('City / Town', cityController.text),
                  _reviewRow('Region', province),
                ],
              ),
            ),
          ),

          // CONTACT
          _sectionTitle('Contact Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Work Tel. No', workTelController.text),
                  _reviewRow('Home Tel. No', homeTelController.text),
                  _reviewRow('Mobile 1', mobile1Controller.text),
                  _reviewRow('Mobile 2', mobile2Controller.text),
                  _reviewRow('Email 1', email1Controller.text),
                  _reviewRow('Email 2', email2Controller.text),
                ],
              ),
            ),
          ),

          // FAMILY
          _sectionTitle('Family Member Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Surname', famSurnameController.text),
                  _reviewRow('First Name', famFirstNameController.text),
                  _reviewRow('Title', famTitle?.toUpperCase()),
                  _reviewRow('Relation', famRelationController.text),
                  _reviewRow('Home Tel', famHomeTelController.text),
                  _reviewRow('Mobile Tel', famMobileController.text),
                  _reviewRow('Address', famAddressController.text),
                ],
              ),
            ),
          ),

          // EMPLOYMENT
          _sectionTitle('Employment Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Employer / Ministry', employerNameController.text),
                  _reviewRow(
                      'Specific Employer', employerSpecificController.text),
                  _reviewRow('Department', departmentController.text),
                  _reviewRow('Job Title', jobTitleController.text),
                  _reviewRow('Employer Code / Payroll No',
                      employerCodeController.text),
                  _reviewRow('Length of Service (years)',
                      lengthYearsController.text),
                  _reviewRow('Length of Service (months)',
                      lengthMonthsController.text),
                  _reviewRow(
                      'Full Time Staff', employedFullTime ? 'Yes' : 'No'),
                  _reviewRow('Gross Annual Salary', grossAnnualController.text),
                  _reviewRow('Net Monthly Income', netMonthlyController.text),
                  _reviewRow('Work Address', workAddressController.text),
                  _reviewRow('Work City/Town', workCityController.text),
                  _reviewRow('Work Region', workProvince),
                  _reviewRow('Salary Frequency', salaryFrequency),
                  _reviewRow('Salary Pay Date', _fmtDate(salaryPayDate)),
                ],
              ),
            ),
          ),

          // BANKING
          _sectionTitle('Banking Details'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow('Bank Name', bankNameController.text),
                  _reviewRow('Account Holder', accountHolderController.text),
                  _reviewRow('Branch Name', branchNameController.text),
                  _reviewRow('Branch Code', branchCodeController.text),
                  _reviewRow('Account Number', accountNumberController.text),
                  _reviewRow('Account Type', accountType),
                  _reviewRow('Salary Paid Into Account',
                      salaryPaidIntoAccount ? 'Yes' : 'No'),
                  _reviewRow(
                      'Usage (years)', accountUsageYearsController.text),
                  _reviewRow(
                      'Usage (months)', accountUsageMonthsController.text),
                  _reviewRow(
                      'Salary transferred 3 months',
                      salaryTransferred3Months ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),

          // SUPPORTING DOCS
          _sectionTitle('Supporting Documents'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow(
                      'Client Signature',
                      clientSignaturePath == null
                          ? null
                          : path.basename(clientSignaturePath!)),
                  _reviewRow(
                      'Identification',
                      identificationPath == null
                          ? null
                          : path.basename(identificationPath!)),
                  _reviewRow(
                      'Latest Payslip',
                      latestPayslipPath == null
                          ? null
                          : path.basename(latestPayslipPath!)),
                  _reviewRow(
                      'Bank Statement',
                      bankStatementPath == null
                          ? null
                          : path.basename(bankStatementPath!)),
                  _reviewRow(
                      'Employer Letter',
                      employerLetterPath == null
                          ? null
                          : path.basename(employerLetterPath!)),
                ],
              ),
            ),
          ),

          // LOAN SCHEDULE
          _sectionTitle('Loan Schedule'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  _reviewRow(
                      'Base Lending Rate (%)', baseLendingRateController.text),
                  _reviewRow('Effective Interest Rate (%)',
                      effectiveInterestRateController.text),
                  _reviewRow(
                      'First Instalment Date', _fmtDate(firstInstalmentDate)),
                  _reviewRow(
                      'Last Instalment Date', _fmtDate(lastInstalmentDate)),
                  _reviewRow('Net Pay', netPayController.text),
                  _reviewRow('Max Allowed Instalment',
                      maxAllowedInstalmentController.text),
                  _reviewRow('Total Applied For', totalAppliedController.text),

                  _reviewRow('Cash to Client', cashToClientController.text),
                  _reviewRow('Loan Period (months)', loanPeriodController.text),
                  _reviewRow('Admin Fee', adminFeeController.text),
                  _reviewRow('Interest', interestController.text),
                  _reviewRow(
                      'Total Collectable', totalCollectableController.text),
                  _reviewRow(
                      'Monthly Instalment', monthlyInstalmentController.text),
                  _reviewRow(
                    'Loan Purpose',
                    loanpurpose == null
                        ? null
                        : loanpurpose == 'other'
                        ? loanPurposeController.text
                        : loanpurpose,
                  ),
                ],
              ),
            ),
          ),


          const SizedBox(height: 16),
          _buildNavigationButtons(),
        ],
      ),
    );
  }


  // Build page view with all steps in order (13 pages total)
  List<Widget> get _steps => [

    _personalInformationStep(), // 3
    _addressDetailStep(), // 4
    _contactDetailsStep(), // 5
    _familyMemberStep(), // 6
    _employmentDetailStep(), // 7
    _bankingDetailsStep(), // 8
    _supportingDocsStep(), // 9
    _loanScheduleStep(), // 10
    _declarationStep(), // 11
    _extraStepB(), // 13 (placeholder)
  ];

  @override
  void dispose() {
    _pageController.dispose();
    // Dispose controllers
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
    clientSignatureFile = null;
    idFileName = null;
    payslipFileName = null;
    bankStatementFileName = null;
    employerLetterFileName = null;
    // dispose signature controller
    _signatureController.removeListener(() {}); // in case
    _signatureController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // user is moving out without necessarily submitting
        if (!_submittedToServer) {
          await _saveToDb('draft');
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Center(
            child: Text(
              "Digital Registration",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          backgroundColor: AppColors.primary,
        ),
        body: SafeArea(
          child: Stack(
            children: [
              // 👇 existing main content
              Column(
                children: [
                  // step progress
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / _steps.length,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
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

              // 👇 overlay while sending
              if (_sending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Submitting application...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
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
      ),
    );
  }

}
