/// Formats the automatic creation timestamp for Brazilian Portuguese labels.
///
/// The value is stored in UTC and shown in the device time zone. The format is
/// built here instead of with a localization package because the application
/// offers a single locale and needs only this pattern.
String formatItemDateTime(DateTime createdAt) {
  final local = createdAt.toLocal();
  final day = _twoDigits(local.day);
  final month = _twoDigits(local.month);
  final hour = _twoDigits(local.hour);
  final minute = _twoDigits(local.minute);
  return '$day/$month/${local.year} às $hour:$minute';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
