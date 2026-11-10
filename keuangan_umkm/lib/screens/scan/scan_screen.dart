import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/receipt_result.dart';
import '../../services/receipt_service.dart';
import 'scan_result_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final ImagePicker imagePicker = ImagePicker();
  final ReceiptService receiptService = ReceiptService();

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isInitializingCamera = false;
  bool _isCapturing = false;
  bool _isFlashOn = false;
  bool isScanning = false;

  XFile? selectedImageFile;
  Uint8List? selectedImageBytes;

  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scanAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _scanController, curve: Curves.linear));

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_isInitializingCamera) return;

    _isInitializingCamera = true;

    try {
      final cameras = await availableCameras();

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final oldController = _cameraController;

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      await oldController?.dispose();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _isFlashOn = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCameraReady = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengaktifkan kamera: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isInitializingCamera = false;
    }
  }

  Future<void> pickReceiptFromGallery() async {
    final pickedFile = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    setState(() {
      selectedImageFile = pickedFile;
      selectedImageBytes = bytes;
      isScanning = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto struk berhasil dipilih. Tekan tombol scan untuk memproses.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> captureReceiptFromCamera() async {
    final controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isCapturing ||
        isScanning) {
      return;
    }

    try {
      setState(() {
        _isCapturing = true;
      });

      final XFile photo = await controller.takePicture();
      final bytes = await photo.readAsBytes();

      if (!mounted) return;

      setState(() {
        selectedImageFile = photo;
        selectedImageBytes = bytes;
        isScanning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto struk berhasil diambil. Tekan tombol scan untuk memproses.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<void> toggleFlash() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      if (_isFlashOn) {
        await controller.setFlashMode(FlashMode.off);
      } else {
        await controller.setFlashMode(FlashMode.torch);
      }

      if (!mounted) return;

      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (_) {}
  }

  Future<void> retakePhoto() async {
    setState(() {
      selectedImageFile = null;
      selectedImageBytes = null;
      isScanning = false;
    });

    if ((_cameraController == null ||
            !_cameraController!.value.isInitialized) &&
        mounted) {
      await _initializeCamera();
    }
  }

  Future<void> startScan() async {
    if (selectedImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto struk dulu ya.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isScanning = true;
    });

    _scanController.repeat(reverse: true);

    try {
      final response = await receiptService.scanReceipt(selectedImageFile!);
      final receiptResult = ReceiptResult.fromJson(response);

      _scanController.stop();

      if (!mounted) return;

      setState(() {
        isScanning = false;
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScanResultScreen(
            result: receiptResult,
            imageFile: selectedImageFile!,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      _scanController.stop();

      setState(() {
        isScanning = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: const Text('Scan Struk', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: _buildScanner(),
    );
  }

  Widget _buildScanner() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(
              isScanning
                  ? 'Mengekstraksi teks dari struk...'
                  : selectedImageFile == null
                  ? 'Arahkan struk ke dalam frame lalu ambil foto'
                  : 'Foto sudah diambil, tekan tombol tengah untuk scan OCR',
              style: TextStyle(
                color: isScanning ? const Color(0xFF60A5FA) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(child: Center(child: _buildScanFrame())),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSmallActionButton(
                  icon: Icons.photo_library_outlined,
                  onTap: isScanning ? null : pickReceiptFromGallery,
                ),
                GestureDetector(
                  onTap: isScanning
                      ? null
                      : () async {
                          if (selectedImageFile == null) {
                            await captureReceiptFromCamera();
                          } else {
                            await startScan();
                          }
                        },
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF2196F3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF2196F3,
                          ).withValues(alpha: 0.35),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.6,
                              ),
                            )
                          : Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                selectedImageFile == null
                                    ? Icons.camera_alt_rounded
                                    : Icons.document_scanner_outlined,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                    ),
                  ),
                ),
                _buildSmallActionButton(
                  icon: selectedImageFile == null
                      ? (_isFlashOn ? Icons.flash_on : Icons.flash_off_outlined)
                      : Icons.refresh_rounded,
                  onTap: isScanning
                      ? null
                      : () async {
                          if (selectedImageFile == null) {
                            await toggleFlash();
                          } else {
                            await retakePhoto();
                          }
                        },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              selectedImageFile == null
                  ? 'Kamera aktif realtime'
                  : 'Scan OCR setelah foto sudah pas',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmallActionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildScanFrame() {
    return Container(
      width: 300,
      height: 430,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1D4ED8), width: 2.2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (selectedImageFile != null && selectedImageBytes != null)
              Image.memory(
                selectedImageBytes!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              )
            else if (_isCameraReady &&
                _cameraController != null &&
                _cameraController!.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _cameraController!.value.previewSize!.height,
                    height: _cameraController!.value.previewSize!.width,
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              )
            else
              Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.16)),
            ),
            Container(
              width: 240,
              height: 330,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white, width: 2.2),
              ),
            ),
            Positioned(
              top: 18,
              left: 18,
              right: 18,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _FrameDot(),
                  Text(
                    'Posisikan struk di dalam frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _FrameDot(),
                ],
              ),
            ),
            if (isScanning) ...[
              AnimatedBuilder(
                animation: _scanAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 55 + (_scanAnimation.value * 260),
                    left: 34,
                    right: 34,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x8038BDF8),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memproses OCR...',
                    style: TextStyle(
                      color: Color(0xFF60A5FA),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrameDot extends StatelessWidget {
  const _FrameDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        color: Color(0xFF38BDF8),
        shape: BoxShape.circle,
      ),
    );
  }
}
