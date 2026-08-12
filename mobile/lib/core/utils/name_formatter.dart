class NameFormatter {
  /// Strips a leading "Dr", "Dr.", or "Doctor" (case-insensitive, with
  /// optional trailing period/space) so it can be safely re-prefixed
  /// with "Dr." for display without duplicating it.
  static String displayName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return 'Medical Professional';
    }
    final cleaned = fullName.trim().replaceFirst(
      RegExp(r'^(dr\.?|doctor)\s+', caseSensitive: false),
      '',
    );
    return 'Dr. $cleaned';
  }
}