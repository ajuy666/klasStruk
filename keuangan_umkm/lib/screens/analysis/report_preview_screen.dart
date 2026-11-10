import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../services/report_service.dart';

class ReportPreviewScreen extends StatefulWidget {
  final ReportPeriod period;

  const ReportPreviewScreen({super.key, required this.period});

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

/// DATABASE (Supabase): state layar yang memuat data laporan pengeluaran.
class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  final reportService = ReportService();

  late Future<ExpenseReportData> reportFuture;

  @override
  void initState() {
    super.initState();
    reportFuture = reportService.getExpenseReport(widget.period);
  }

  String formatCurrency(num value) {
    final raw = value.toStringAsFixed(0);
    final chars = raw.split('').reversed.toList();
    final buffer = StringBuffer();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }

    return 'Rp ${buffer.toString().split('').reversed.join()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F7F9),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text(
          'Preview Laporan',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: FutureBuilder<ExpenseReportData>(
        future: reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat laporan: ${snapshot.error ?? ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }

          final data = snapshot.data!;
          final total = data.rows.fold<double>(
            0,
            (sum, row) => sum + row.amount,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
                child: _ReportSummaryCard(
                  period: data.periodLabel,
                  itemCount: data.rows.length,
                  total: formatCurrency(total),
                ),
              ),
              Expanded(
                child: PdfPreview(
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  canDebug: false,
                  pdfFileName: 'laporan_pengeluaran_${data.fileSuffix}.pdf',
                  build: (_) => reportService.buildExpenseReportPdf(data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReportSummaryCard extends StatelessWidget {
  final String period;
  final int itemCount;
  final String total;

  const _ReportSummaryCard({
    required this.period,
    required this.itemCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laporan $period',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$itemCount item tercatat',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            total,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
