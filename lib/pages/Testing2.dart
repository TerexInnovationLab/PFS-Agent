// lib/main.dart
import 'dart:io';
import 'dart:convert'; // ✅ ADD THIS
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

import '../config/api_config.dart';

class ClientOnboardingPage extends StatefulWidget {
  const ClientOnboardingPage({super.key});

  @override
  State<ClientOnboardingPage> createState() => _ClientOnboardingPageState();
}

class _ClientOnboardingPageState extends State<ClientOnboardingPage> {
  bool _sending = false;
  String _status = 'Idle';

  String? clientSignaturePath;
  String? identificationPath;
  String? latestPayslipPath;
  String? bankStatementPath;
  String? employerLetterPath;

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

  Future<void> sendOnboarding() async {
    setState(() {
      _sending = true;
      _status = 'Preparing request...';
    });

    try {
      final uri = Uri.parse(url);
      final request = http.MultipartRequest('POST', uri);

      // ✅ ACCEPT JSON RESPONSE
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer 1|qsk108UgVueL8AUVaEvtlW5qSisaQRjQgU7LG3J84ae41441', // optional
      });

      request.fields.addAll({
        "system_information": "Loan application v1",
        "application_date": "2025-01-10",
        "government_employee_payroll": "1",
        "short_term_private": "0",
        "psm_reservation_number": "PSM-2025-0001",
        "title": "Mr",
        "surname": "Nchipi",
        "first_name": "Yesaya",
        "id_number": "987654321",
        "date_of_birth": "1990-05-15",
        "gender": "male",
        "number_of_dependants": "2",
        "marital_status": "married",
        "district": "Lilongwe",
        "traditional_authority": "TA Chimutu",
        "village": "Kaphiri",
        "physical_address": "123 Area 25",
        "town": "Lilongwe",
        "postal_address": "P.O Box 123",
        "province": "central",
        "work_tel_no": "012345678",
        "home_tel_no": "011234567",
        "mobile_tel_no1": "0999999999",
        "mobile_tel_no2": "0888888888",
        "email_address1": "john.banda@example.com",
        "email_address2": "jbanda.alt@example.com",
        "fam_surname": "Chirwa",
        "fam_first_name": "Peter",
        "fam_title": "mr",
        "fam_relation": "Brother",
        "fam_home_tel_no": "0999999999",
        "fam_mobile_tel_no": "0888888888",
        "fam_address": "Chirimba",
        "employer_name": "Malawi Government",
        "specific_employer": "Ministry of Education",
        "department": "Accounts",
        "job_title": "Accountant",
        "employee_code": "EMP001",
        "length_of_service_years": "5",
        "length_of_service_months": "6",
        "full_staff": "1",
        "gross_annual_salary": "6500000",
        "net_monthly_income": "450000",
        "work_address": "Capital Hill",
        "work_city": "Lilongwe",
        "work_province": "central",
        "work_salary_frequency": "monthly",
        "salary_pay_date": "2025-01-30",
        "bank_name": "National Bank",
        "account_holder": "John Banda",
        "branch_name": "City Centre",
        "branch_code": "NB123",
        "account_number": "123456789012345",
        "account_type": "savings",
        "is_salary_paid_to_this_account": "1",
        "account_usage_years": "3",
        "account_usage_months": "4",
        "salary_been_transferred_for_3_months": "1",
        "lending_rate": "12.5",
        "interest_rate": "8.5",
        "first_installment_date": "2025-02-01",
        "last_installment_date": "2026-02-01",
        "net_pay": "450000",
        "max_allowed_installments": "12",
        "total_applied_for": "500000",
        "total_amount_approved": "480000",
        "cash_to_client": "450000",
        "loan_period": "12",
        "admin_fee": "5000.00",
        "interest": "30000.00",
        "total_collectable": "515000.00",
        "monthly_installment": "42916.67",
        "loan_purpose": "School fees"
      }
      );

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
      await tryAttach('identification', identificationPath);
      await tryAttach('latest_payslip', latestPayslipPath);
      await tryAttach('bank_statement', bankStatementPath);
      await tryAttach('employer_letter', employerLetterPath);

      setState(() {
        _status = 'Sending request...';
      });

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      setState(() {
        _sending = false;
      });

      /// ✅ SAFELY PARSE JSON RESPONSE
      Map<String, dynamic>? jsonResponse;
      try {
        jsonResponse = json.decode(response.body);
      } catch (_) {
        jsonResponse = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _status = 'Success';
        });

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Success'),
            content: Text(
              "You have successfully submitted the application."
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
            ],
          ),
        );
      } else {
        setState(() {
          _status = 'Failed';
        });

        String errorMessage = 'Unknown error';
        if (jsonResponse != null) {
          errorMessage =
              jsonResponse['message'] ??
                  jsonResponse['error'] ??
                  jsonResponse.toString();
        }

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              )
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
          title: const Text('Exception'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            )
          ],
        ),
      );

      print(e.toString());
    }
  }

  Widget fileRow(String label, String? pathValue, String pickKey) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        if (pathValue != null) Expanded(child: Text(path.basename(pathValue))),
        TextButton(onPressed: () => pickFile(pickKey), child: const Text('Pick')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Onboarding POST')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            fileRow('Client signature (required)', clientSignaturePath, 'client_signature'),
            fileRow('Identification', identificationPath, 'identification'),
            fileRow('Latest payslip', latestPayslipPath, 'latest_payslip'),
            fileRow('Bank statement', bankStatementPath, 'bank_statement'),
            fileRow('Employer letter', employerLetterPath, 'employer_letter'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _sending ? null
                  : () async {
                if (clientSignaturePath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Client signature required')),
                  );
                  return;
                }
                await sendOnboarding();
              },
              child: Text(_sending ? 'Sending...' : 'Submit'),
            ),
            const SizedBox(height: 12),
            Text('Status: $_status'),
          ],
        ),
      ),
    );
  }
}
