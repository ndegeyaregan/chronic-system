// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Fetches raw bytes from a browser blob URL (web only).
Future<Uint8List?> fetchBlobBytes(String url) async {
  try {
    final request = html.HttpRequest();
    request.open('GET', url);
    request.responseType = 'arraybuffer';
    request.send();
    await request.onLoad.first;
    final buffer = request.response as ByteBuffer;
    return buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
