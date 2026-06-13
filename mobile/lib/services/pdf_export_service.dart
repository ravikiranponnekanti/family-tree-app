import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/person.dart';

class PdfExportService {
  /// Builds a printable family directory PDF and opens the share/print sheet.
  static Future<void> exportDirectory(List<Person> persons) async {
    final doc = pw.Document();

    // group by generation depth
    final byId = {for (final p in persons) p.id: p};
    int depth(Person p, Set<int?> seen) {
      if (seen.contains(p.id)) return 0;
      seen.add(p.id);
      int d = 0;
      for (final pid in [p.fatherId, p.motherId]) {
        final parent = byId[pid];
        if (parent != null) {
          final pd = depth(parent, seen) + 1;
          if (pd > d) d = pd;
        }
      }
      return d;
    }

    final groups = <int, List<Person>>{};
    for (final p in persons) {
      groups.putIfAbsent(depth(p, {}), () => []).add(p);
    }
    final sortedDepths = groups.keys.toList()..sort();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Text('Family Directory',
              style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF2E5D4B))),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ),
        build: (context) {
          final widgets = <pw.Widget>[];
          for (final d in sortedDepths) {
            widgets.add(pw.Container(
              margin: const pw.EdgeInsets.only(top: 14, bottom: 6),
              child: pw.Text('Generation ${d + 1}',
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromInt(0xFFB08D3E))),
            ));
            for (final p in groups[d]!) {
              widgets.add(_personRow(p, byId));
            }
          }
          widgets.add(pw.SizedBox(height: 20));
          widgets.add(pw.Text(
              'Total members: ${persons.length}',
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)));
          return widgets;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  static pw.Widget _personRow(Person p, Map<int?, Person> byId) {
    final details = <String>[];
    if (p.gender != null) details.add(p.gender!);
    if (p.birthDate != null) details.add('b. ${p.birthDate}');
    if (p.deathDate != null) details.add('d. ${p.deathDate}');
    final father = byId[p.fatherId];
    final mother = byId[p.motherId];
    final parents = <String>[];
    if (father != null) parents.add('Father: ${father.fullName}');
    if (mother != null) parents.add('Mother: ${mother.fullName}');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8, left: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFBF8F1),
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(p.fullName,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          if (details.isNotEmpty)
            pw.Text(details.join('  •  '),
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          if (parents.isNotEmpty)
            pw.Text(parents.join('   '),
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          if (p.bio != null && p.bio!.isNotEmpty)
            pw.Text(p.bio!,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
        ],
      ),
    );
  }
}
