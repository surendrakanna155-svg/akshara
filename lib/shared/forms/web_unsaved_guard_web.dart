import 'dart:js_interop';

/// Web implementation of the `beforeunload` guard (RT-30). While at least one
/// [AksharaUnsavedChangesGuard] with unsaved changes (or an in-flight mutation)
/// is active, the browser shows its native "Leave site?" confirmation on tab
/// close / refresh, so a hard reload cannot silently discard the user's work.
///
/// Uses `dart:js_interop` (SDK-provided, no extra dependency) rather than the
/// deprecated `dart:html`.
@JS('window')
external _Window get _window;

extension type _Window._(JSObject _) implements JSObject {
  external set onbeforeunload(JSFunction? handler);
}

extension type _BeforeUnloadEvent._(JSObject _) implements JSObject {
  external set returnValue(JSAny? value);
}

int _activeGuards = 0;
bool _installed = false;

void setWebUnloadGuardActive(bool active) {
  _activeGuards += active ? 1 : -1;
  if (_activeGuards < 0) _activeGuards = 0;

  if (!_installed) {
    _installed = true;
    _window.onbeforeunload = ((JSObject event) {
      if (_activeGuards <= 0) return null;
      // A non-empty returnValue triggers the browser's native unsaved-changes
      // confirmation. The text is browser-controlled (modern browsers ignore a
      // custom message), so the value only needs to be non-empty.
      (event as _BeforeUnloadEvent).returnValue = 'unsaved'.toJS;
      return 'unsaved'.toJS;
    }).toJS;
  }
}
