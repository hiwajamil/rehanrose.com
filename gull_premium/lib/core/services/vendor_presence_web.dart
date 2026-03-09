import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.EventListener? _beforeUnloadHandler;

/// Web: register beforeunload so we can attempt to set vendor offline when tab closes.
void registerVendorPresenceBeforeUnload(void Function() onBeforeUnload) {
  unregisterVendorPresenceBeforeUnload();
  void handler(web.Event _) => onBeforeUnload();
  _beforeUnloadHandler = handler.toJS;
  web.window.addEventListener('beforeunload', _beforeUnloadHandler);
}

void unregisterVendorPresenceBeforeUnload() {
  if (_beforeUnloadHandler != null) {
    web.window.removeEventListener('beforeunload', _beforeUnloadHandler);
    _beforeUnloadHandler = null;
  }
}
