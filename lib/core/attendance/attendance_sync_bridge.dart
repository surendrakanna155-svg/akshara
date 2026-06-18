/// Notifies Riverpod when [MockAttendanceSyncStore] mutates outside providers.
void Function()? onMockAttendanceSyncChanged;

void notifyMockAttendanceSyncChanged() => onMockAttendanceSyncChanged?.call();
