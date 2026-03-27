import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageChanger extends StatefulWidget {
  ImageChanger({super.key});

  @override
  ImageChangerState createState() => ImageChangerState();
}

class ImageChangerState extends State<ImageChanger> {
  Uint8List? _imageData;

  // Function to update image data
  void updateImage(Uint8List newImageData) {
    print('ImageChanger::updateImage');
    setState(() {
      _imageData = newImageData;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _imageData != null
            ? Image.memory(_imageData!)
            : Text('No image loaded'),
      ],
    );
  }
}