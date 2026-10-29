import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

const bool isWeb = true;

const _dataKey = 'vjfit_data';
const _photoPrefix = 'vjfit_photo_';

/// Saved app data as JSON text, or null on first visit.
Future<String?> loadData() async {
  try {
    return web.window.localStorage.getItem(_dataKey);
  } catch (_) {
    return null;
  }
}

/// Throws if the browser refuses (storage full or blocked), so the app can say so.
Future<void> saveData(String json) async {
  web.window.localStorage.setItem(_dataKey, json);
  _askToKeepData();
}

bool _asked = false;

/// Asks the browser not to clear VJ Fit's data when space runs low.
void _askToKeepData() {
  if (_asked) return;
  _asked = true;
  try {
    web.window.navigator.storage.persist();
  } catch (_) {}
}

/// Keeps a picked photo in browser storage and returns a "web:" reference.
/// The picker already shrank it, so a photo is roughly 40–90 KB.
Future<String> keepPhoto(XFile x, String id) async {
  final bytes = await x.readAsBytes();
  final key = '$_photoPrefix$id';
  try {
    web.window.localStorage.setItem(key, base64Encode(bytes));
  } catch (_) {
    throw StateError('Browser storage is full. Remove some of your own exercise photos and try again.');
  }
  _cache[key] = bytes;
  return 'web:$key';
}

final Map<String, Uint8List> _cache = {};

/// Image for a photo saved with [keepPhoto].
ImageProvider photoImage(String path) {
  final key = path.startsWith('web:') ? path.substring(4) : path;
  var bytes = _cache[key];
  if (bytes == null) {
    final b64 = web.window.localStorage.getItem(key);
    bytes = b64 == null ? Uint8List(0) : base64Decode(b64);
    _cache[key] = bytes;
  }
  return MemoryImage(bytes);
}

/// Downloads a text file in the browser. Returns true when started.
Future<bool> downloadText(String fileName, String text) async {
  final blob = web.Blob(
    <JSAny>[utf8.encode(text).toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body?.appendChild(a);
  a.click();
  a.remove();
  Future.delayed(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return true;
}
