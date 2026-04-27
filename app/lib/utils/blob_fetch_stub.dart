import 'dart:typed_data';

/// Native stub — blob URLs don't exist on native; always returns null.
Future<Uint8List?> fetchBlobBytes(String url) async => null;
