import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

class OcrService {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> extractText(File file) async {
    File processedFile = file;

    try {
      processedFile = await _preprocessImage(file);

      final inputImage = InputImage.fromFile(processedFile);
      final recognizedText = await _recognizer.processImage(inputImage);

      final buffer = StringBuffer();

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
        buffer.writeln();
      }

      final result = buffer.toString().trim();
      debugPrint('OCR RESULT LENGTH: ${result.length}');
      debugPrint('OCR RESULT TEXT: $result');

      return result;
    } catch (e) {
      debugPrint('OCR extract error: $e');
      rethrow;
    } finally {
      if (processedFile.path != file.path) {
        try {
          await processedFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<File> _preprocessImage(File originalFile) async {
    try {
      final bytes = await originalFile.readAsBytes();
      final processedBytes = await compute(_processImageBytes, bytes);

      if (processedBytes == null) {
        debugPrint('Preprocess gagal, pakai file asli');
        return originalFile;
      }

      final tempPath =
          '${originalFile.parent.path}/ocr_preprocessed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(processedBytes, flush: true);
      return tempFile;
    } catch (e) {
      debugPrint('Preprocess error: $e');
      return originalFile;
    }
  }

  void dispose() {
    _recognizer.close();
  }
}

Uint8List? _processImageBytes(Uint8List bytes) {
  try {
    img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    if (image.width > 2000) {
      image = img.copyResize(image, width: 2000);
    }

    image = img.grayscale(image);

    image = img.adjustColor(
      image,
      contrast: 1.2,
      brightness: 0.03,
    );

    image = img.convolution(
      image,
      filter: [
        0, -1, 0,
        -1, 5, -1,
        0, -1, 0,
      ],
      div: 1,
      offset: 0,
    );

    return Uint8List.fromList(
      img.encodeJpg(image, quality: 95),
    );
  } catch (e) {
    debugPrint('Isolate preprocess error: $e');
    return null;
  }
}