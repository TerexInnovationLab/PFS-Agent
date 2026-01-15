import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../layouts/Colors.dart'; // adjust path to your AppColors

class DigitalClientPreview extends StatefulWidget {
  final Map<String, dynamic> data;
  final String status; // "pending", "draft", etc.

  const DigitalClientPreview({
    Key? key,
    required this.data,
    required this.status,
  }) : super(key: key);

  @override
  DigitalClientPreviewState createState() => DigitalClientPreviewState();
}

class DigitalClientPreviewState extends State<DigitalClientPreview> {
  String _fmtDate(dynamic iso) {
    if (iso == null) return '-';
    if (iso is String && iso.trim().isEmpty) return '-';
    try {
      final d = DateTime.parse(iso.toString());
      return d.toIso8601String().split('T').first;
    } catch (_) {
      return iso.toString();
    }
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

  Widget _reviewRow(String label, dynamic value) {
    final String display;
    if (value == null) {
      display = '-';
    } else if (value is String && value.trim().isEmpty) {
      display = '-';
    } else {
      display = value.toString().trim();
    }

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

  Widget _imageRow(String label, String? path) {
    final hasPath = path != null && path.trim().isNotEmpty;
    File? file;
    if (hasPath) {
      file = File(path!);
    }

    return Card(
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
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            hasPath && file!.existsSync()
                ? SizedBox(
              height: 160,
              width: double.infinity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              ),
            )
                : const Text(
              'No image available',
              style: TextStyle(color: Colors.grey),
            ),
            if (hasPath) ...[
              const SizedBox(height: 4),
              Text(
                p.basename(path!),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;

    // Read all fields from the same keys you used in _collectFormData()
    final titleValue = (d['titleValue'] ?? '').toString();
    final firstName = (d['firstName'] ?? '').toString();
    final surname = (d['surname'] ?? '').toString();

    final fullName = [
      titleValue.toUpperCase(),
      firstName,
      surname,
    ].where((p) => p.trim().isNotEmpty).join(' ');

    // Status badge
    final status = widget.status.toLowerCase();
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = 'Approved';
        break;
      case 'denied':
        statusColor = Colors.red;
        statusLabel = 'Denied';
        break;
      case 'draft':
        statusColor = Colors.blueGrey;
        statusLabel = 'Draft';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusLabel = 'Pending';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Digital Client Preview',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name + status
            Row(
              children: [
                const Icon(Icons.person, size: 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Unknown Client' : fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // PERSONAL INFORMATION
            _sectionTitle('Personal Information'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _reviewRow('Title', d['titleValue']),
                    _reviewRow('First Name', d['firstName']),
                    _reviewRow('Surname', d['surname']),
                    _reviewRow('ID Number', d['idNumber']),
                    _reviewRow('Date of Birth', _fmtDate(d['dateOfBirth'])),
                    _reviewRow('Gender', d['gender']),
                    _reviewRow('No. of Dependants', d['dependants']),
                    _reviewRow('Marital Status', d['maritalStatus']),
                    _reviewRow('Home District', d['homeDistrict']),
                    _reviewRow('Home TA', d['homeTraditionalAuthority']),
                    _reviewRow('Home Village', d['homeVillage']),
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
                    _reviewRow('Physical Address', d['physicalAddress']),
                    _reviewRow('City / Town', d['city']),
                    _reviewRow('Region', d['province']),
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
                    _reviewRow('Work Tel. No', d['workTel']),
                    _reviewRow('Home Tel. No', d['homeTel']),
                    _reviewRow('Mobile 1', d['mobile1']),
                    _reviewRow('Mobile 2', d['mobile2']),
                    _reviewRow('Email 1', d['email1']),
                    _reviewRow('Email 2', d['email2']),
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
                    _reviewRow('Surname', d['famSurname']),
                    _reviewRow('First Name', d['famFirstName']),
                    _reviewRow('Title', d['famTitle']),
                    _reviewRow('Relation', d['famRelation']),
                    _reviewRow('Home Tel', d['famHomeTel']),
                    _reviewRow('Mobile Tel', d['famMobile']),
                    _reviewRow('Address', d['famAddress']),
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
                    _reviewRow('Employer / Ministry', d['employerName']),
                    _reviewRow('Specific Employer', d['specificEmployer']),
                    _reviewRow('Department', d['department']),
                    _reviewRow('Job Title', d['jobTitle']),
                    _reviewRow('Employer Code / Payroll No', d['employerCode']),
                    _reviewRow('Length of Service (years)', d['lengthYears']),
                    _reviewRow('Length of Service (months)', d['lengthMonths']),
                    _reviewRow(
                        'Full Time Staff',
                        (d['employedFullTime'] == true ||
                            d['employedFullTime'] == 'true')
                            ? 'Yes'
                            : 'No'),
                    _reviewRow('Gross Annual Salary', d['grossAnnual']),
                    _reviewRow('Net Monthly Income', d['netMonthly']),
                    _reviewRow('Work Address', d['workAddress']),
                    _reviewRow('Work City/Town', d['workCity']),
                    _reviewRow('Work Region', d['workProvince']),
                    _reviewRow('Salary Frequency', d['salaryFrequency']),
                    _reviewRow('Salary Pay Date', _fmtDate(d['salaryPayDate'])),
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
                    _reviewRow('Bank Name', d['bankName']),
                    _reviewRow('Account Holder', d['accountHolder']),
                    _reviewRow('Branch Name', d['branchName']),
                    _reviewRow('Branch Code', d['branchCode']),
                    _reviewRow('Account Number', d['accountNumber']),
                    _reviewRow('Account Type', d['accountType']),
                    _reviewRow(
                        'Salary Paid Into Account',
                        (d['salaryPaidIntoAccount'] == true ||
                            d['salaryPaidIntoAccount'] == 'true')
                            ? 'Yes'
                            : 'No'),
                    _reviewRow('Usage (years)', d['accountUsageYears']),
                    _reviewRow('Usage (months)', d['accountUsageMonths']),
                    _reviewRow(
                        'Salary transferred 3 months',
                        (d['salaryTransferred3Months'] == true ||
                            d['salaryTransferred3Months'] == 'true')
                            ? 'Yes'
                            : 'No'),
                  ],
                ),
              ),
            ),

            // LOAN
            _sectionTitle('Loan Schedule'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    _reviewRow('Total Applied For', d['totalApplied']),
                    _reviewRow('Total Amount Approved', d['totalApproved']),
                    _reviewRow('Cash to Client', d['cashToClient']),
                    _reviewRow('Loan Period (months)', d['loanPeriod']),
                    _reviewRow('Admin Fee', d['adminFee']),
                    _reviewRow('Interest', d['interest']),
                    _reviewRow('Total Collectable', d['totalCollectable']),
                    _reviewRow(
                        'Monthly Instalment', d['monthlyInstalment']),
                    _reviewRow(
                      'Loan Purpose',
                      d['loanPurpose'] == 'other'
                          ? d['loanPurposeText']
                          : d['loanPurpose'],
                    ),
                  ],
                ),
              ),
            ),

            // IMAGES
            _sectionTitle('Supporting Documents'),
            _imageRow('Client Signature', d['clientSignaturePath']),
            _imageRow('Identification (Front)', d['identificationPath']),
            _imageRow('Identification (Back)', d['identificationPathBack']),
            _imageRow('Customer Photo', d['customerPhoto']),
            _imageRow('Self (Customer and Agent)', d['self']),
            _imageRow('Latest Payslip', d['latestPayslipPath']),
            _imageRow('Bank Statement', d['bankStatementPath']),
            _imageRow('Employer Letter', d['employerLetterPath']),

            SizedBox(height: 50,)
          ],
        ),
      ),
    );
  }
}
