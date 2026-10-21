import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/finance/domain/models/payment_receipt.dart';
import '../../features/settings/data/school_settings_repository.dart';

/// Service for exporting data to PDF and CSV formats
class ExportService {
  static Future<({String name, Uint8List? logo})> _branding() async {
    final repository = SchoolSettingsRepository();
    final branding = await repository.loadPublicBranding();
    return (
      name: branding.schoolName,
      logo: await repository.downloadLogo(branding.logoPath),
    );
  }

  static pw.Widget _brandHeader(({String name, Uint8List? logo}) branding) {
    return pw.Row(
      children: [
        if (branding.logo != null) ...[
          pw.Image(pw.MemoryImage(branding.logo!), width: 38, height: 38),
          pw.SizedBox(width: 10),
        ],
        pw.Expanded(
          child: pw.Text(
            branding.name,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Export data to PDF with custom header and table
  static Future<void> exportToPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? footer,
  }) async {
    final branding = await _branding();
    final pdf = pw.Document();

    // Build PDF document
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _brandHeader(branding),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    subtitle,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Table
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
              cellHeight: 30,
              cellAlignments: {
                for (int i = 0; i < headers.length; i++)
                  i: pw.Alignment.centerLeft,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),

            // Footer
            if (footer != null) ...[
              pw.SizedBox(height: 16),
              pw.Text(
                footer,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          );
        },
      ),
    );

    // Display print preview dialog
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: '$title.pdf',
    );
  }

  /// Export data to CSV file
  static Future<File> exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    // Prepare CSV data
    final csvData = [headers, ...rows];

    // Convert to CSV string
    final csvString = const ListToCsvConverter().convert(csvData);

    // Get the app's document directory
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$filename.csv';
    final file = File(path);

    // Write to file
    await file.writeAsString(csvString);

    return file;
  }

  /// Export and share CSV file (mobile-friendly)
  static Future<void> exportAndShareCsv({
    required String filename,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final file = await exportToCsv(
      filename: filename,
      headers: headers,
      rows: rows,
    );

    // Share the file using the printing package's share dialog
    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: '$filename.csv',
    );
  }

  /// Generate financial report PDF
  static Future<void> exportFinancialReportPdf({
    required String yearLabel,
    required double totalCollected,
    required double totalExpected,
    required int paymentCount,
    required double totalAdjustments,
    required String collectionRate,
  }) async {
    final headers = ['Metric', 'Value'];
    final rows = [
      ['Total Collected', 'MWK ${totalCollected.toStringAsFixed(2)}'],
      ['Total Expected', 'MWK ${totalExpected.toStringAsFixed(2)}'],
      ['Collection Rate', '$collectionRate%'],
      ['Number of Payments', '$paymentCount'],
      ['Total Adjustments', 'MWK ${totalAdjustments.toStringAsFixed(2)}'],
    ];

    await exportToPdf(
      title: 'Financial Report',
      subtitle: yearLabel,
      headers: headers,
      rows: rows,
      footer: 'Generated on ${DateTime.now().toString().split('.')[0]}',
    );
  }

  /// Generate enrolment report PDF
  static Future<void> exportEnrolmentReportPdf({
    required String yearLabel,
    required int totalEnrolled,
    required int maleCount,
    required int femaleCount,
    required int activeInYear,
    required Map<String, int> byClass,
  }) async {
    final branding = await _branding();
    final summaryRows = [
      ['Total Enrolled', '$totalEnrolled'],
      ['Male Students', '$maleCount'],
      ['Female Students', '$femaleCount'],
      ['Active in Selected Year', '$activeInYear'],
    ];

    final classRows = byClass.entries
        .map((e) => [e.key, '${e.value}'])
        .toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _brandHeader(branding),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Enrolment Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    yearLabel,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary section
            pw.Text(
              'Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Count'],
              data: summaryRows,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFF1565C0),
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
            ),

            pw.SizedBox(height: 24),

            // By class section
            if (classRows.isNotEmpty) ...[
              pw.Text(
                'Students by Class',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.TableHelper.fromTextArray(
                headers: ['Class', 'Count'],
                data: classRows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF1565C0),
                ),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
            ],

            pw.SizedBox(height: 16),
            pw.Text(
              'Generated on ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Enrolment_Report_$yearLabel.pdf',
    );
  }

  /// Generate performance report PDF
  static Future<void> exportPerformanceReportPdf({
    required String yearLabel,
    required int gradeCount,
    required Map<String, String> avgBySubject,
    required Map<String, int> progressionCounts,
  }) async {
    final branding = await _branding();
    final subjectRows = avgBySubject.entries
        .map((e) => [e.key, '${e.value}%'])
        .toList();

    final progressionRows = progressionCounts.entries
        .map((e) => [e.key, '${e.value}'])
        .toList();

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Title
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _brandHeader(branding),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Performance Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    yearLabel,
                    style: const pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Divider(thickness: 2),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Summary
            pw.Text(
              'Total Grades Recorded: $gradeCount',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),

            // Subject averages section
            pw.Text(
              'Average Score by Subject',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (subjectRows.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['Subject', 'Average (%)'],
                data: subjectRows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.orange,
                ),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              )
            else
              pw.Text(
                'No grades recorded yet.',
                style: const pw.TextStyle(color: PdfColors.grey),
              ),

            pw.SizedBox(height: 24),

            // Progression outcomes section
            pw.Text(
              'Progression Outcomes',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (progressionRows.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['Decision', 'Count'],
                data: progressionRows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.orange,
                ),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              )
            else
              pw.Text(
                'No progression reviews yet.',
                style: const pw.TextStyle(color: PdfColors.grey),
              ),

            pw.SizedBox(height: 16),
            pw.Text(
              'Generated on ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Performance_Report_$yearLabel.pdf',
    );
  }

  /// Generate student list CSV
  static Future<void> exportStudentListCsv({
    required List<Map<String, dynamic>> students,
  }) async {
    final headers = [
      'Student ID',
      'Full Name',
      'Date of Birth',
      'Gender',
      'Status',
    ];
    final rows = students
        .map(
          (s) => [
            (s['studentId'] ?? '').toString(),
            (s['fullName'] ?? '').toString(),
            (s['dateOfBirth'] ?? '').toString(),
            (s['gender'] ?? '').toString(),
            (s['enrollmentStatus'] ?? '').toString(),
          ],
        )
        .toList();

    await exportAndShareCsv(
      filename: 'Students_${DateTime.now().millisecondsSinceEpoch}',
      headers: headers,
      rows: rows,
    );
  }

  // ── Payment receipt ──────────────────────────────────────────────────────

  /// Builds the official payment receipt as PDF bytes. [schoolName] and
  /// [logo] come from the school branding; the logo is optional.
  static Future<Uint8List> buildReceiptPdf(
    PaymentReceiptData receipt, {
    required String schoolName,
    Uint8List? logo,
  }) async {
    final pdf = pw.Document();
    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ],
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _brandHeader((name: schoolName, logo: logo)),
            pw.SizedBox(height: 6),
            pw.Text(
              'OFFICIAL PAYMENT RECEIPT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Divider(thickness: 1.5),
            row('Receipt number', receipt.receiptNumber, bold: true),
            row('Received from', receipt.studentName),
            if (receipt.className != null) row('Class', receipt.className!),
            row('Payment date', _receiptDate(receipt.paymentDate)),
            row('Applied to', receipt.feeType),
            row('Method', receipt.methodLabel),
            if (receipt.reference != null && receipt.reference!.isNotEmpty)
              row('Reference', receipt.reference!),
            pw.Divider(),
            row('Amount received', _receiptMoney(receipt.amount), bold: true),
            row('Previous balance', _receiptMoney(receipt.previousBalance)),
            row(
              'Remaining balance',
              _receiptMoney(receipt.remainingBalance),
              bold: true,
            ),
            pw.Spacer(),
            pw.Text(
              'Keep this receipt for your records. Posted payments are never '
              'edited; corrections are made by a recorded reversal.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ),
    );
    return pdf.save();
  }

  static String _receiptMoney(double value) {
    final fixed = value.abs().toStringAsFixed(2);
    final parts = fixed.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '${value < 0 ? '-' : ''}MWK $grouped.${parts[1]}';
  }

  static String _receiptDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Uint8List> _receiptBytes(PaymentReceiptData receipt) async {
    final branding = await _branding();
    return buildReceiptPdf(
      receipt,
      schoolName: branding.name,
      logo: branding.logo,
    );
  }

  /// Opens the system print dialog with the receipt.
  static Future<void> printReceipt(PaymentReceiptData receipt) async {
    final bytes = await _receiptBytes(receipt);
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'Receipt_${receipt.receiptNumber}.pdf',
    );
  }

  /// Saves/shares the receipt as a PDF file (download on web and desktop).
  static Future<void> downloadReceiptPdf(PaymentReceiptData receipt) async {
    final bytes = await _receiptBytes(receipt);
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Receipt_${receipt.receiptNumber}.pdf',
    );
  }
}
