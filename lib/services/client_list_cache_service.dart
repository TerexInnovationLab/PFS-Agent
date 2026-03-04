import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pfs_agent/config/api_config.dart';
import 'package:pfs_agent/pages/database/digital_registration_db.dart';
import 'package:pfs_agent/pages/database_helper.dart';

class ClientListCacheService {
  ClientListCacheService._();

  static final ClientListCacheService instance = ClientListCacheService._();
  static final Map<String, List<Map<String, dynamic>>> _memoryCache = {};

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  String _normalizeStatus(String? raw) {
    final s = (raw ?? '').toString().toLowerCase().trim();
    if (s == 'bounce') return 'bounced';
    if (s == 'denied') return 'rejected';
    return s;
  }

  Future<String> _cacheKey() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_data');

    if (userJson != null && userJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(userJson);
        if (decoded is Map<String, dynamic>) {
          final email = decoded['email']?.toString().trim().toLowerCase();
          if (email != null && email.isNotEmpty) {
            return 'client_list_cache_$email';
          }
        }
      } catch (_) {}
    }

    return 'client_list_cache';
  }

  List<Map<String, dynamic>> _cloneClients(List<Map<String, dynamic>> clients) {
    return clients.map((client) => Map<String, dynamic>.from(client)).toList();
  }

  String? _firstNonEmpty(Iterable<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }

  bool _parseBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'y';
  }

  String _apiOrigin() {
    final uri = Uri.parse(ApiConfig.baseUrl);
    final portPart =
        uri.hasPort && uri.port != 80 && uri.port != 443 ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$portPart';
  }

  String? _normalizeAssetPath(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    if (raw.startsWith('http://') ||
        raw.startsWith('https://') ||
        raw.startsWith('file://')) {
      return raw;
    }

    if (raw.startsWith('/')) {
      return '${_apiOrigin()}$raw';
    }

    return raw;
  }

  String? _extractServerIdFromRegistration(Map<String, dynamic> item) {
    return _firstNonEmpty([
      item['registration_id'],
      item['client_id'],
      item['id'],
      item['id_number'],
      item['server_id'],
    ]);
  }

  String _detectServerSource(Map<String, dynamic> item) {
    final explicit = _firstNonEmpty([
      item['source'],
      item['registration_type'],
      item['type'],
      item['channel'],
      item['mode'],
      item['form_type'],
    ]);

    final normalizedExplicit = explicit?.toLowerCase();
    if (normalizedExplicit != null) {
      if (normalizedExplicit.contains('digital')) return 'digital';
      if (normalizedExplicit.contains('analog')) return 'analog';
      if (normalizedExplicit.contains('upload')) return 'analog';
      if (normalizedExplicit.contains('scan')) return 'analog';
    }

    final hasDigitalFields = item.containsKey('first_name') ||
        item.containsKey('surname') ||
        item.containsKey('mobile_tel_no1') ||
        item.containsKey('account_number') ||
        item.containsKey('loan_period');

    return hasDigitalFields ? 'digital' : 'analog';
  }

  Map<String, dynamic> _normalizeDigitalPreviewData(
    Map<String, dynamic> item,
    String? serverId,
  ) {
    return {
      'id': serverId ?? item['id'],
      'client_id': serverId ?? item['client_id'] ?? item['id'],
      'titleValue': item['title'] ?? item['titleValue'],
      'firstName': item['first_name'] ?? item['firstName'],
      'surname': item['surname'],
      'idNumber': item['id_number'] ?? item['idNumber'],
      'dateOfBirth': item['date_of_birth'] ?? item['dateOfBirth'],
      'gender': item['gender'],
      'dependants': item['number_of_dependants'] ?? item['dependants'],
      'maritalStatus': item['marital_status'] ?? item['maritalStatus'],
      'homeDistrict': item['district'] ?? item['homeDistrict'],
      'homeTraditionalAuthority':
          item['traditional_authority'] ?? item['homeTraditionalAuthority'],
      'homeVillage': item['home_village_details'] ?? item['homeVillage'],
      'physicalAddress': item['physical_address'] ?? item['physicalAddress'],
      'city': item['town'] ?? item['city'],
      'province': item['province'],
      'workTel': item['work_tel_no'] ?? item['workTel'],
      'homeTel': item['home_tel_no'] ?? item['homeTel'],
      'mobile1': item['mobile_tel_no1'] ?? item['mobile1'],
      'mobile2': item['mobile_tel_no2'] ?? item['mobile2'],
      'email1': item['email1'],
      'email2': item['email2'],
      'famSurname': item['fam_surname'] ?? item['famSurname'],
      'famFirstName': item['fam_first_name'] ?? item['famFirstName'],
      'famTitle': item['fam_title'] ?? item['famTitle'],
      'famRelation': item['fam_relation'] ?? item['famRelation'],
      'famHomeTel': item['fam_home_tel_no'] ?? item['famHomeTel'],
      'famMobile': item['fam_mobile_tel_no'] ?? item['famMobile'],
      'famAddress': item['fam_address'] ?? item['famAddress'],
      'employerName': item['employer_name'] ?? item['employerName'],
      'specificEmployer':
          item['specific_employer'] ?? item['specificEmployer'],
      'department': item['department'],
      'jobTitle': item['job_title'] ?? item['jobTitle'],
      'employerCode': item['employee_code'] ?? item['employerCode'],
      'lengthYears':
          item['length_of_service_years'] ?? item['lengthYears'],
      'lengthMonths':
          item['length_of_service_months'] ?? item['lengthMonths'],
      'employedFullTime':
          _parseBool(item['full_staff'] ?? item['employedFullTime']),
      'grossAnnual': item['gross_annual_salary'] ?? item['grossAnnual'],
      'netMonthly': item['net_monthly_income'] ?? item['netMonthly'],
      'workAddress': item['work_address'] ?? item['workAddress'],
      'workCity': item['work_city'] ?? item['workCity'],
      'workProvince': item['work_province'] ?? item['workProvince'],
      'salaryFrequency':
          item['work_salary_frequency'] ?? item['salaryFrequency'],
      'salaryPayDate': item['salary_pay_date'] ?? item['salaryPayDate'],
      'bankName': item['bank_name'] ?? item['bankName'],
      'accountHolder': item['account_holder'] ?? item['accountHolder'],
      'branchName': item['branch_name'] ?? item['branchName'],
      'branchCode': item['branch_code'] ?? item['branchCode'],
      'accountNumber': item['account_number'] ?? item['accountNumber'],
      'accountType': item['account_type'] ?? item['accountType'],
      'salaryPaidIntoAccount': _parseBool(
        item['is_salary_paid_to_this_account'] ?? item['salaryPaidIntoAccount'],
      ),
      'accountUsageYears':
          item['account_usage_years'] ?? item['accountUsageYears'],
      'accountUsageMonths':
          item['account_usage_months'] ?? item['accountUsageMonths'],
      'salaryTransferred3Months': _parseBool(
        item['salary_been_transferred_for_3_months'] ??
            item['salaryTransferred3Months'],
      ),
      'totalApplied': item['total_applied_for'] ?? item['totalApplied'],
      'totalApproved':
          item['total_amount_approved'] ?? item['totalApproved'],
      'cashToClient': item['cash_to_client'] ?? item['cashToClient'],
      'loanPeriod': item['loan_period'] ?? item['loanPeriod'],
      'adminFee': item['admin_fee'] ?? item['adminFee'],
      'interest': item['interest'],
      'totalCollectable':
          item['total_collectable'] ?? item['totalCollectable'],
      'monthlyInstalment':
          item['monthly_installment'] ?? item['monthlyInstalment'],
      'loanPurpose': item['loan_purpose'] ?? item['loanPurpose'],
      'loanPurposeText': item['loan_purpose_text'] ?? item['loanPurposeText'],
      'clientSignaturePath': _normalizeAssetPath(
        item['client_signature_url'] ??
            item['client_signature'] ??
            item['clientSignaturePath'],
      ),
      'identificationPath': _normalizeAssetPath(
        item['front_of_id_url'] ??
            item['front_of_id'] ??
            item['identificationPath'],
      ),
      'identificationPathBack': _normalizeAssetPath(
        item['back_of_id_url'] ??
            item['back_of_id'] ??
            item['identificationPathBack'],
      ),
      'customerPhoto': _normalizeAssetPath(
        item['customer_photo_url'] ??
            item['customer_photo'] ??
            item['customerPhoto'],
      ),
      'self': _normalizeAssetPath(
        item['selfie_url'] ?? item['selfie'] ?? item['self'],
      ),
      'latestPayslipPath': _normalizeAssetPath(
        item['latest_payslip_url'] ??
            item['latest_payslip'] ??
            item['latestPayslipPath'],
      ),
      'bankStatementPath': _normalizeAssetPath(
        item['bank_statement_url'] ??
            item['bank_statement'] ??
            item['bankStatementPath'],
      ),
      'employerLetterPath': _normalizeAssetPath(
        item['employer_letter_url'] ??
            item['employer_letter'] ??
            item['employerLetterPath'],
      ),
    };
  }

  Map<String, dynamic> _normalizeAnalogPreviewData(
    Map<String, dynamic> item,
    String? serverId,
  ) {
    return {
      'full_name': item['full_name'] ?? item['information'],
      'id_number': serverId ?? item['id_number'] ?? item['id'],
      'frontIdPath': _normalizeAssetPath(
        item['front_of_id_url'] ?? item['front_of_id'] ?? item['frontIdPath'],
      ),
      'backIdPath': _normalizeAssetPath(
        item['back_of_id_url'] ?? item['back_of_id'] ?? item['backIdPath'],
      ),
      'selfiePath': _normalizeAssetPath(
        item['selfie_url'] ?? item['selfie'] ?? item['selfiePath'],
      ),
      'signaturePath': _normalizeAssetPath(
        item['client_signature_url'] ??
            item['client_signature'] ??
            item['signaturePath'],
      ),
      'customerPhotoPath': _normalizeAssetPath(
        item['customer_photo_url'] ??
            item['customer_photo'] ??
            item['customerPhotoPath'],
      ),
      'payslipPath': _normalizeAssetPath(
        item['latest_payslip_url'] ??
            item['latest_payslip'] ??
            item['payslipPath'],
      ),
      'bankStatementPath': _normalizeAssetPath(
        item['bank_statement_url'] ??
            item['bank_statement'] ??
            item['bankStatementPath'],
      ),
      'employerLetterPath': _normalizeAssetPath(
        item['employer_letter_url'] ??
            item['employer_letter'] ??
            item['employerLetterPath'],
      ),
      'applicationFormPath': _normalizeAssetPath(
        item['application_form_url'] ??
            item['application_form'] ??
            item['applicationFormPath'],
      ),
    };
  }

  Map<String, dynamic>? _normalizeServerClient(Map raw) {
    try {
      final item = Map<String, dynamic>.from(raw.cast<dynamic, dynamic>());
      final source = _detectServerSource(item);
      final serverId = _extractServerIdFromRegistration(item);
      final status = _normalizeStatus(item['status']?.toString());
      final reason = _firstNonEmpty([
        item['reason'],
        item['rejection_reason'],
        item['bounce_reason'],
        item['comment'],
      ]);

      if (source == 'digital') {
        final data = _normalizeDigitalPreviewData(item, serverId);
        final name = _firstNonEmpty([
          item['full_name'],
          item['information'],
          [
            (data['titleValue'] ?? '').toString().trim(),
            (data['firstName'] ?? '').toString().trim(),
            (data['surname'] ?? '').toString().trim(),
          ].where((e) => e.isNotEmpty).join(' '),
        ]);

        return {
          'id': serverId ?? item['id'],
          'server_id': serverId,
          'status': status,
          'reason': reason,
          'information': name ?? 'No Name',
          'data': jsonEncode(data),
          'source': 'digital',
          'storage': 'server',
        };
      }

      final formData = _normalizeAnalogPreviewData(item, serverId);
      final name = _firstNonEmpty([
        item['full_name'],
        item['information'],
        formData['full_name'],
      ]);

      return {
        'id': serverId ?? item['id'],
        'server_id': serverId,
        'status': status,
        'reason': reason,
        'information': name ?? 'Unnamed client',
        'form_data': jsonEncode(formData),
        'source': 'analog',
        'storage': 'server',
      };
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _loadLocalDraftClients() async {
    final analog = await DatabaseHelper.instance.getData();
    final analogDrafts = analog
        .where((c) => _normalizeStatus(c['status']?.toString()) == 'draft')
        .map<Map<String, dynamic>>(
          (c) => {
            ...c,
            'status': 'draft',
            'source': 'analog',
            'storage': 'local',
          },
        )
        .toList();

    final digitalRegs = await DigitalRegistrationDb.instance.getAll();
    final digitalDrafts = digitalRegs
        .where((reg) => _normalizeStatus(reg.status) == 'draft')
        .map<Map<String, dynamic>>((reg) {
          final name = _firstNonEmpty([
            reg.data['full_name'],
            reg.data['information'],
            [
              (reg.data['titleValue'] ?? '').toString().trim(),
              (reg.data['firstName'] ?? '').toString().trim(),
              (reg.data['surname'] ?? '').toString().trim(),
            ].where((part) => part.isNotEmpty).join(' '),
          ]);

          return {
            'id': reg.id,
            'status': 'draft',
            'reason': reg.reason,
            'information': name ?? 'No Name',
            'data': jsonEncode(reg.data),
            'source': 'digital',
            'storage': 'local',
          };
        }).toList();

    return [...analogDrafts, ...digitalDrafts];
  }

  Future<List<Map<String, dynamic>>> _fetchServerClients() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/registrations'),
      headers: {
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load registrations');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) return [];

    final registrations = decoded['registrations'] ?? decoded['data'];
    if (registrations is! List) return [];

    return registrations
        .whereType<Map>()
        .map(_normalizeServerClient)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<void> saveClients(List<Map<String, dynamic>> clients) async {
    final key = await _cacheKey();
    final copy = _cloneClients(clients);
    _memoryCache[key] = copy;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(copy));
  }

  Future<List<Map<String, dynamic>>> getCachedClients() async {
    final key = await _cacheKey();
    final memory = _memoryCache[key];
    if (memory != null) return _cloneClients(memory);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      final clients = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item.cast<dynamic, dynamic>()))
          .toList();
      _memoryCache[key] = clients;
      return _cloneClients(clients);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> refreshClients() async {
    final localDrafts = await _loadLocalDraftClients();
    final serverClients = await _fetchServerClients();
    final combined = [...localDrafts, ...serverClients];
    await saveClients(combined);
    return combined;
  }

  Future<void> warmUp() async {
    await getCachedClients();
    try {
      await refreshClients();
    } catch (_) {}
  }
}
