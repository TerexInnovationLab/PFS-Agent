// signature_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';

class FullScreenSignaturePage extends StatefulWidget {
  const FullScreenSignaturePage({Key? key}) : super(key: key);

  @override
  State<FullScreenSignaturePage> createState() => _FullScreenSignaturePageState();
}

class _FullScreenSignaturePageState extends State<FullScreenSignaturePage> {
  late final SignatureController _controller;
  bool _hasData = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // 🔥 Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _controller.addListener(_onChanged);
    _hasData = !_controller.isEmpty;
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();

    // 🔥 Restore portrait mode for the rest of the app
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    super.dispose();
  }

  void _onChanged() {
    final nowHas = !_controller.isEmpty;
    if (nowHas != _hasData && mounted) {
      setState(() => _hasData = nowHas);
    }
  }

  Future<String> _writePngToAppFolder(Uint8List data) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory sigDir = Directory('${appDocDir.path}/signatures');
    if (!await sigDir.exists()) await sigDir.create(recursive: true);

    final String filePath =
        '${sigDir.path}/signature_${DateTime.now().millisecondsSinceEpoch}.png';
    final File file = File(filePath);
    await file.writeAsBytes(data);
    return file.path;
  }

  Future<void> _save() async {
    if (!_hasData) return;

    setState(() => _saving = true);

    try {
      final Uint8List? bytes = await _controller.toPngBytes();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to export signature.');
      }

      final String savedPath = await _writePngToAppFolder(bytes);

      if (!mounted) return;

      Navigator.of(context).pop(savedPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving signature: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Here'),
        actions: [
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _controller.clear(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔥 FULL-WIDTH SIGNATURE AREA
            Expanded(
              child: Container(
                width: double.infinity, // <-- fill ALL width
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),

            // 🔥 BUTTONS BELOW — FULL WIDTH
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewPadding.bottom + 20,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (!_hasData || _saving) ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.save),
                      label: const Text("Save"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text("Cancel"),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
