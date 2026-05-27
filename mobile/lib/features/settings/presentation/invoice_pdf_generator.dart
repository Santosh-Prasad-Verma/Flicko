import 'dart:io';
import 'dart:developer' as dev;
import 'package:flutter/services.dart' show ByteData, rootBundle, Uint8List;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A utility to generate highly professional, tax-compliant corporate PDF invoices for Flicko purchases.
/// Designed with a beautiful, clean, light-mode corporate aesthetic featuring Flicko's emerald green accent
/// and a high-contrast QR Code for flawless mobile scanning.
class InvoicePdfGenerator {


  /// Generates a premium high-contrast tax invoice PDF with a white background and saves/downloads it.
  /// Returns the saved absolute path if written directly, or null if shared via system share sheet.
  static Future<String?> generateAndDownloadInvoice({
    required String txnId,
    required String productName,
    required String amountStr,
    required DateTime date,
    required String paymentMethod,
    required String status,
    required String userEmail,
    required String username,
  }) async {
    final pdf = pw.Document();

    // Try to load Flicko logo for white background
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/Flicko-for-white-background.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      dev.log('[PDF_GENERATOR] Loaded Flicko white-bg logo asset successfully.');
    } catch (e) {
      dev.log('[PDF_GENERATOR] Failed to load Flicko logo asset (using fallback): $e');
    }

    // Load clean professional corporate Roboto fonts that natively support Indian Rupee symbol (₹)
    pw.Font fontRegular;
    pw.Font fontBold;
    try {
      final fontDataRegular = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
      final fontDataBold = await rootBundle.load('assets/fonts/Roboto-Bold.ttf');
      fontRegular = pw.Font.ttf(fontDataRegular);
      fontBold = pw.Font.ttf(fontDataBold);
      dev.log('[PDF_GENERATOR] Loaded local Roboto assets successfully.');
    } catch (e) {
      dev.log('[PDF_GENERATOR] Failed to load Roboto assets (using Helvetica fallback): $e');
      fontRegular = pw.Font.helvetica();
      fontBold = pw.Font.helveticaBold();
    }

    // Parse amount to numeric value for details
    double totalAmount = 0.0;
    try {
      final numericPart = amountStr.replaceAll(RegExp(r'[^0-9.]'), '');
      totalAmount = double.parse(numericPart);
    } catch (_) {
      totalAmount = 799.00;
    }

    // Subtotal and Tax calculations (18% GST standard in India)
    final double subtotal = totalAmount / 1.18;
    final double gstAmount = totalAmount - subtotal;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36), // Balanced margins for white background corporate layout
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          final brandGreen = PdfColor.fromHex('#52B788');
          final primaryDark = PdfColor.fromHex('#0F172A');
          final secondaryDark = PdfColor.fromHex('#475569');
          final borderGrey = PdfColor.fromHex('#E2E8F0');
          final softFill = PdfColor.fromHex('#F8FAFC');

          return pw.Container(
            color: PdfColors.white,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Block: Logo & Invoice details
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    // Brand Block
                    pw.Row(
                      children: [
                        if (logoImage != null)
                          pw.Container(
                            width: 56,
                            height: 56,
                            margin: const pw.EdgeInsets.only(right: 14),
                            child: pw.Image(logoImage),
                          )
                        else
                          pw.Container(
                            width: 56,
                            height: 56,
                            margin: const pw.EdgeInsets.only(right: 14),
                            decoration: pw.BoxDecoration(
                              color: brandGreen,
                              shape: pw.BoxShape.circle,
                            ),
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              'F',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 32,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'FLICKO',
                                style: pw.TextStyle(
                                  fontSize: 32,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'DIGITAL COSMETIC STUDIO',
                                style: pw.TextStyle(
                                  fontSize: 12.0,
                                  color: secondaryDark,
                                  fontWeight: pw.FontWeight.bold,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Tax Invoice Label Block
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text(
                            'TAX INVOICE',
                            style: pw.TextStyle(
                              fontSize: 32,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: pw.BoxDecoration(
                              color: brandGreen,
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                            ),
                            child: pw.Text(
                              'PAID',
                              style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 13.5,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  pw.SizedBox(height: 24),
                  pw.Divider(color: borderGrey, thickness: 1.5),
                  pw.SizedBox(height: 20),

                  // Metadata Rows
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Billed To
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'BILLED TO:',
                              style: pw.TextStyle(
                                fontSize: 13.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: secondaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                username.isNotEmpty ? username.toUpperCase() : 'FLICKO MEMBER',
                                style: pw.TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                userEmail.toLowerCase(),
                                style: pw.TextStyle(
                                  fontSize: 14.5,
                                  color: secondaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'DATE: ${DateFormat('dd MMMM yyyy').format(date)}',
                                style: pw.TextStyle(
                                  fontSize: 14.0,
                                  color: secondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Invoice Details
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'INVOICE DETAILS:',
                                style: pw.TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: secondaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'INVOICE NO: #$txnId',
                                style: pw.TextStyle(
                                  fontSize: 15.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'TRANSACTION ID: $txnId',
                                style: pw.TextStyle(
                                  fontSize: 14.0,
                                  color: secondaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'PAYMENT METHOD: ${paymentMethod.toUpperCase()}',
                                style: pw.TextStyle(
                                  fontSize: 14.0,
                                  color: secondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Issuer Details
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'ISSUED BY:',
                                style: pw.TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: secondaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                'FLICKO CORP INDIA',
                                style: pw.TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'BENGALURU, KARNATAKA',
                                style: pw.TextStyle(
                                  fontSize: 14.0,
                                  color: secondaryDark,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                'GSTIN: 29AAFCC1024F1Z3',
                                style: pw.TextStyle(
                                  fontSize: 14.0,
                                  color: secondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  pw.SizedBox(height: 30),

                  // Table Header row
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: softFill,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: borderGrey, width: 1),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          flex: 6,
                          child: pw.Text('ITEM DESCRIPTION', style: pw.TextStyle(color: primaryDark, fontSize: 14.0, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Container(width: 50, child: pw.Text('QTY', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: primaryDark, fontSize: 14.0, fontWeight: pw.FontWeight.bold))),
                        pw.Container(width: 80, child: pw.Text('PRICE (₹)', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: primaryDark, fontSize: 14.0, fontWeight: pw.FontWeight.bold))),
                        pw.Container(width: 80, child: pw.Text('GST (18%)', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: primaryDark, fontSize: 14.0, fontWeight: pw.FontWeight.bold))),
                        pw.Container(width: 90, child: pw.Text('TOTAL (₹)', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: primaryDark, fontSize: 14.0, fontWeight: pw.FontWeight.bold))),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  // Ledger Row Details
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Item Name & Subtitles
                        pw.Expanded(
                          flex: 6,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(productName.toUpperCase(), style: pw.TextStyle(color: primaryDark, fontSize: 17.0, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('Cosmetic Type: ${productName.contains('PRO') || productName.contains('PLUS') ? 'Subscription' : 'Store Item'}', style: pw.TextStyle(color: secondaryDark, fontSize: 13.0)),
                              pw.Text('Binding Identity: User Account Server-Link', style: pw.TextStyle(color: secondaryDark, fontSize: 13.0)),
                            ],
                          ),
                        ),
                        // Qty
                        pw.Container(
                          width: 50,
                          alignment: pw.Alignment.topCenter,
                          child: pw.Text('1', style: pw.TextStyle(color: primaryDark, fontSize: 15.0, fontWeight: pw.FontWeight.bold)),
                        ),
                        // Price
                        pw.Container(
                          width: 80,
                          alignment: pw.Alignment.topRight,
                          child: pw.Text('₹${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(color: primaryDark, fontSize: 15.0)),
                        ),
                        // GST
                        pw.Container(
                          width: 80,
                          alignment: pw.Alignment.topRight,
                          child: pw.Text('₹${gstAmount.toStringAsFixed(2)}', style: pw.TextStyle(color: primaryDark, fontSize: 15.0)),
                        ),
                        // Total
                        pw.Container(
                          width: 90,
                          alignment: pw.Alignment.topRight,
                          child: pw.Text('₹${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(color: primaryDark, fontSize: 16.5, fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),
                  pw.Divider(color: borderGrey, thickness: 1.5),
                  pw.SizedBox(height: 16),

                  // Totals summary section
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Spacer(),
                      pw.Container(
                        width: 260,
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: softFill,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                          border: pw.Border.all(color: borderGrey, width: 1.5),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildSummaryRow('SUBTOTAL', '₹${subtotal.toStringAsFixed(2)}', secondaryDark, primaryDark, isTotal: false),
                            pw.SizedBox(height: 6),
                            _buildSummaryRow('TAX (GST 18%)', '₹${gstAmount.toStringAsFixed(2)}', secondaryDark, primaryDark, isTotal: false),
                            pw.SizedBox(height: 6),
                            _buildSummaryRow('DISCOUNT', '₹0.00', secondaryDark, primaryDark, isTotal: false),
                            pw.SizedBox(height: 8),
                            pw.Divider(color: borderGrey, thickness: 1),
                            pw.SizedBox(height: 8),
                            _buildSummaryRow('TOTAL AMOUNT', '₹${totalAmount.toStringAsFixed(2)}', primaryDark, brandGreen, isTotal: true),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // Bottom coordinates & Scan QR section
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Payment Details
                      pw.Expanded(
                        flex: 4,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'PAYMENT METHOD',
                              style: pw.TextStyle(
                                fontSize: 14.0,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryDark,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _buildDetailValue('Bank Name', 'HDFC BANK INDIA', secondaryDark),
                            _buildDetailValue('Account Name', 'FLICKO CORP INDIA', secondaryDark),
                            _buildDetailValue('IFSC / BSB', 'HDFC0000123', secondaryDark),
                            _buildDetailValue('Account No', '50100492817283', secondaryDark),
                            _buildDetailValue('Reference', 'FLK-$txnId', secondaryDark),
                          ],
                        ),
                      ),
                      // QR Code
                      pw.Expanded(
                        flex: 3,
                        child: pw.Column(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.white,
                                border: pw.Border.all(color: borderGrey, width: 1.5),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                              child: pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: 'upi://pay?pa=flicko@hdfcbank&pn=FlickoCorp&am=${totalAmount.toStringAsFixed(2)}&cu=INR',
                                color: PdfColors.black,
                                width: 82,
                                height: 82,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            pw.Text(
                              'SCAN TO PAY VIA UPI',
                              style: pw.TextStyle(
                                color: primaryDark,
                                fontSize: 11.0,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Terms
                      pw.Expanded(
                        flex: 5,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'TERMS & CONDITIONS',
                              style: pw.TextStyle(
                                fontSize: 14.0,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryDark,
                              ),
                            ),
                            pw.SizedBox(height: 6),
                            _buildTermLine('1. This invoice covers digital goods & server activations.', secondaryDark),
                            _buildTermLine('2. Digital products are delivered and bound instantly.', secondaryDark),
                            _buildTermLine('3. Custom cosmetics and themes are subject to TOS rules.', secondaryDark),
                            _buildTermLine('4. Digital goods are non-refundable after activation.', secondaryDark),
                          ],
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 35),
                  pw.Divider(color: borderGrey, thickness: 1.5),
                  pw.SizedBox(height: 8),

                  // Bottom Footer metadata strip
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Flicko Corp India', style: pw.TextStyle(color: secondaryDark, fontSize: 12.0)),
                      pw.Text('Bengaluru, KA, India', style: pw.TextStyle(color: secondaryDark, fontSize: 12.0)),
                      pw.Text('GSTIN: 29AAFCC1024F1Z3', style: pw.TextStyle(color: secondaryDark, fontSize: 12.0)),
                      pw.Text('support@flicko.app', style: pw.TextStyle(color: secondaryDark, fontSize: 12.0)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );

    final pdfBytes = await pdf.save();

    // 1. If running on Android, request permissions and write directly to public Downloads folder
    if (Platform.isAndroid) {
      try {
        await [Permission.storage, Permission.manageExternalStorage].request();

        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final filePath = '${downloadDir.path}/invoice_$txnId.pdf';
          final file = File(filePath);
          await file.writeAsBytes(pdfBytes);
          dev.log('[PDF_GENERATOR] Native Android public download succeeded: $filePath');
          await _showDownloadNotification(txnId);
          return filePath;
        } else {
          // Try app external storage downloads directory as fallback
          final extDirs = await getExternalStorageDirectories(type: StorageDirectory.downloads);
          if (extDirs != null && extDirs.isNotEmpty) {
            final filePath = '${extDirs.first.path}/invoice_$txnId.pdf';
            final file = File(filePath);
            await file.writeAsBytes(pdfBytes);
            dev.log('[PDF_GENERATOR] Native Android external download succeeded: $filePath');
            await _showDownloadNotification(txnId);
            return filePath;
          }
        }
      } catch (e) {
        dev.log('[PDF_GENERATOR] Android native direct save failed: $e');
      }
    }

    // 2. If running on Desktop (Linux, macOS, Windows), use FilePicker
    if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      try {
        final String? outputPath = await FilePicker.saveFile(
          dialogTitle: 'Download Invoice',
          fileName: 'invoice_$txnId.pdf',
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          bytes: pdfBytes,
        );

        if (outputPath != null) {
          final file = File(outputPath);
          await file.writeAsBytes(pdfBytes);
          dev.log('[PDF_GENERATOR] Native desktop save succeeded at $outputPath');
          return outputPath;
        }
      } catch (e) {
        dev.log('[PDF_GENERATOR] Desktop save file picker failed: $e');
      }
    }

    // 3. Fallback for iOS and other platform errors: Save to temporary files and show Share sheet
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/invoice_$txnId.pdf';
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Flicko Tax Invoice - $txnId',
        text: 'Here is your official Flicko tax invoice for $productName.',
      );
      dev.log('[PDF_GENERATOR] Completed share sheet fallback.');
      return null; // Return null because it was shared rather than directly saved to downloads
    } catch (e) {
      dev.log('[PDF_GENERATOR] Fallback share sheet failed: $e');
      rethrow;
    }
  }

  static pw.Widget _buildDetailValue(String label, String value, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: '$label: ', style: pw.TextStyle(color: color, fontSize: 13.0, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: value, style: pw.TextStyle(color: color, fontSize: 13.0)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTermLine(String text, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3.5),
      child: pw.Text(
        text,
        style: pw.TextStyle(color: color, fontSize: 11.0, height: 1.3),
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value, PdfColor labelColor, PdfColor valueColor, {bool isTotal = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(fontSize: isTotal ? 16.0 : 13.0, fontWeight: pw.FontWeight.bold, color: labelColor),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: isTotal ? 20.0 : 14.5, fontWeight: pw.FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  static Future<void> _showDownloadNotification(String txnId) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      await plugin.initialize(settings: settings);

      const androidDetails = AndroidNotificationDetails(
        'flicko_downloads_channel',
        'Downloads',
        channelDescription: 'Flicko download status notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
      );
      
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );
      
      await plugin.show(
        id: txnId.hashCode,
        title: 'Download Completed',
        body: 'Invoice saved to: invoice_$txnId.pdf',
        notificationDetails: details,
      );
      dev.log('[PDF_GENERATOR] System download notification triggered.');
    } catch (e) {
      dev.log('[PDF_GENERATOR] Failed to show system notification: $e');
    }
  }
}
