import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MonthlyReport {
  final String monthYear;
  final int totalAdmissions;
  final double totalIncome;

  MonthlyReport({required this.monthYear, required this.totalAdmissions, required this.totalIncome});
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  String _currentUser = 'kushbinary';
  List<MonthlyReport> _reports = [];
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    _currentUser = prefs.getString('current_logged_in_user') ?? 'kushbinary';

    final students = await ApiService.getStudentsForUser(_currentUser);
    _calculateReports(students);
  }

  void _calculateReports(List<Student> students) {
    Map<String, List<Student>> grouped = {};

    for (var s in students) {
      try {
        DateTime admissionDate = DateTime.parse(s.admissionDate);
        String monthYear = DateFormat('MMMM yyyy').format(admissionDate); // e.g., "August 2026"
        
        if (!grouped.containsKey(monthYear)) {
          grouped[monthYear] = [];
        }
        grouped[monthYear]!.add(s);
      } catch (e) {
        // ignore parsing errors
      }
    }

    List<MonthlyReport> reports = [];
    grouped.forEach((monthYear, list) {
      double income = list.fold(0.0, (sum, item) => sum + item.paidAmount);
      reports.add(MonthlyReport(
        monthYear: monthYear,
        totalAdmissions: list.length,
        totalIncome: income,
      ));
    });

    // Sort by date roughly (latest first). For simplicity, we just rely on string parsing if needed, 
    // but a better way is to parse MMMM yyyy back to date.
    reports.sort((a, b) {
      try {
        DateTime dateA = DateFormat('MMMM yyyy').parse(a.monthYear);
        DateTime dateB = DateFormat('MMMM yyyy').parse(b.monthYear);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  Future<void> _generateAndPrintPDF() async {
    final pdf = pw.Document();

    final prefs = await SharedPreferences.getInstance();
    final libraryName = prefs.getString('library_custom_business_name') ?? 'MyLibBook';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$libraryName - Monthly Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text('Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 30),
              pw.Table.fromTextArray(
                headers: ['Month & Year', 'Total Admissions', 'Total Earnings (INR)'],
                data: _reports.map((r) => [
                  r.monthYear,
                  r.totalAdmissions.toString(),
                  'Rs. ${r.totalIncome.toInt()}'
                ]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
                cellAlignment: pw.Alignment.center,
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total Overall Income: Rs. ${_reports.fold(0.0, (sum, item) => sum + item.totalIncome).toInt()}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]
              )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '${libraryName.replaceAll(' ', '_')}_Monthly_Report.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8fafc),
      appBar: AppBar(
        title: const Text('Monthly Reports', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF4338CA),
        elevation: 0,
        actions: [
          if (_reports.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
              onPressed: _generateAndPrintPDF,
              tooltip: 'Export to PDF',
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? const Center(child: Text('No reports available.', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  report.monthYear,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.green.shade200)
                                  ),
                                  child: Text(
                                    '${report.totalAdmissions} Admissions',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 30),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Earning:', style: TextStyle(fontSize: 14, color: Colors.grey)),
                                Text(
                                  currencyFormat.format(report.totalIncome),
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF4338CA)),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: _reports.isNotEmpty ? FloatingActionButton.extended(
        onPressed: _generateAndPrintPDF,
        backgroundColor: const Color(0xFF4338CA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.picture_as_pdf),
        label: const Text('Export PDF'),
      ) : null,
    );
  }
}
