import 'dart:io';
import 'package:flutter/material.dart';

class FullImagePage extends StatelessWidget {
  final File imageFile;

  const FullImagePage({required this.imageFile, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(imageFile),
        ),
      ),
    );
  }
}
