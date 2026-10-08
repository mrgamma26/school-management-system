import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Service for exporting data to PDF and CSV formats
class ExportService {
  /// Export data to PDF with custom header and table
  static Future<void> exportToPdf({
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<String>> rows,
    String? footer,
  }) async {
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
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
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
                  color: PdfColors.indigo,
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
}
