// Conditional export: uses dart:html on web, stub on native.
export 'blob_fetch_stub.dart'
    if (dart.library.html) 'blob_fetch_web.dart';
