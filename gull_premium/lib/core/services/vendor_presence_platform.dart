/// Platform-specific vendor presence (e.g. beforeunload on web).
library;

import 'vendor_presence_stub.dart'
    if (dart.library.js_interop) 'vendor_presence_web.dart' as impl;

void registerVendorPresenceBeforeUnload(void Function() onBeforeUnload) {
  impl.registerVendorPresenceBeforeUnload(onBeforeUnload);
}

void unregisterVendorPresenceBeforeUnload() {
  impl.unregisterVendorPresenceBeforeUnload();
}
