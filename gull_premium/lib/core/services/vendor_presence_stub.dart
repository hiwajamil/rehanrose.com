/// Stub: no-op on non-web. Web implementation registers window beforeunload.
library;

void registerVendorPresenceBeforeUnload(void Function() onBeforeUnload) {}

void unregisterVendorPresenceBeforeUnload() {}
