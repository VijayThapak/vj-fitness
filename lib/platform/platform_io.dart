import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

const bool isWeb = false;

File? _dataFile;

Future<File> _file() async {
  if (_dataFile != null) return _dataFile!;
  final dir = await getApplicationDocumentsDirectory();
  return _dataFile = File('${dir.path}/vjfit_data.json');
}

/// Saved app data as JSON text, or null on first run.
Future<String?> loadData() async {
  final f = await _file();
  if (!await f.exists()) return null;
  return f.readAsString();
}

Future<void> saveData(String json) async {
  final f = await _file();
  final tmp = File('${f.path}.tmp');
  await tmp.writeAsString(json);
  await tmp.rename(f.path);
}

/// Keeps a picked photo and returns the path to store on the exercise.
Future<String> keepPhoto(XFile x, String id) async {
  final dir = await getApplicationDocumentsDirectory();
  final photos = Directory('${dir.path}/photos');
  if (!await photos.exists()) await photos.create(recursive: true);
  final dest = '${photos.path}/$id.jpg';
  await File(x.path).copy(dest);
  return dest;
}

/// Image for a photo saved with [keepPhoto].
ImageProvider photoImage(String path) => FileImage(File(path));

/// Browser download of a text file. Not used on phones (returns false so the
/// caller uses the system save dialog instead).
Future<bool> downloadText(String fileName, String text) async => false;
