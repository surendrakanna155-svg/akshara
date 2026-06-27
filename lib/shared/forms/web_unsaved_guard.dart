// Facade for the browser `beforeunload` guard (RT-30). Resolves to a no-op on
// non-web platforms and to the `dart:js_interop` implementation on web.
export 'web_unsaved_guard_stub.dart'
    if (dart.library.js_interop) 'web_unsaved_guard_web.dart';
