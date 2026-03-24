class NameFormatter {
  static String buildFullName({
    required String firstName,
    required String lastName,
    String? middleName,
    bool hasMiddleName = true,
  }) {
    final first = _normalizeNamePart(firstName);
    final middle = hasMiddleName ? _normalizeNamePart(middleName ?? '') : '';
    final last = _normalizeNamePart(lastName);

    final parts = <String>[first];
    if (middle.isNotEmpty) parts.add(middle);
    if (last.isNotEmpty) parts.add(last);

    return parts.join(' ').trim();
  }

  /// Display format used across the app (except profile views):
  /// FirstName + MiddleName(with additional parts initialed) + LastName.
  /// Example: middle="Mark Cruz" -> "Mark C.".
  static String buildDisplayName({
    required String firstName,
    required String lastName,
    String? middleName,
    bool hasMiddleName = true,
  }) {
    final first = _normalizeNamePart(firstName);
    final middle = hasMiddleName ? _normalizeNamePart(middleName ?? '') : '';
    final last = _normalizeNamePart(lastName);

    final middleDisplay = _middleDisplay(middle);

    final parts = <String>[first];
    if (middleDisplay.isNotEmpty) parts.add(middleDisplay);
    if (last.isNotEmpty) parts.add(last);

    return parts.where((p) => p.isNotEmpty).join(' ').trim();
  }

  static String fromUserDataDisplay(
    Map<String, dynamic>? data, {
    String fallback = 'User',
  }) {
    if (data == null) return fallback;

    return fromAnyDisplay(
      fullName: data['fullName'] as String?,
      firstName: data['firstName'] as String?,
      middleName: data['middleName'] as String?,
      lastName: data['lastName'] as String?,
      hasMiddleName: data['hasMiddleName'] as bool?,
      fallback: fallback,
    );
  }

  static String fromUserDataFull(
    Map<String, dynamic>? data, {
    String fallback = 'User',
  }) {
    if (data == null) return fallback;

    return fromAnyFull(
      fullName: data['fullName'] as String?,
      firstName: data['firstName'] as String?,
      middleName: data['middleName'] as String?,
      lastName: data['lastName'] as String?,
      hasMiddleName: data['hasMiddleName'] as bool?,
      fallback: fallback,
    );
  }

  static String fromAnyDisplay({
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    bool? hasMiddleName,
    String fallback = 'User',
  }) {
    final first = _normalizeNamePart(firstName ?? '');
    final middle = _normalizeNamePart(middleName ?? '');
    final last = _normalizeNamePart(lastName ?? '');
    final hasMiddle = hasMiddleName ?? middle.isNotEmpty;

    if (first.isNotEmpty && last.isNotEmpty) {
      return buildDisplayName(
        firstName: first,
        middleName: middle,
        lastName: last,
        hasMiddleName: hasMiddle,
      );
    }

    final parsed = _parseFromFullName(fullName ?? '');
    if (parsed != null) {
      return buildDisplayName(
        firstName: parsed.firstName,
        middleName: parsed.middleName,
        lastName: parsed.lastName,
        hasMiddleName: parsed.middleName.isNotEmpty,
      );
    }

    final raw = _normalizeNamePart(fullName ?? '');
    return raw.isNotEmpty ? raw : fallback;
  }

  static String fromAnyFull({
    String? fullName,
    String? firstName,
    String? middleName,
    String? lastName,
    bool? hasMiddleName,
    String fallback = 'User',
  }) {
    final first = _normalizeNamePart(firstName ?? '');
    final middle = _normalizeNamePart(middleName ?? '');
    final last = _normalizeNamePart(lastName ?? '');
    final hasMiddle = hasMiddleName ?? middle.isNotEmpty;

    if (first.isNotEmpty && last.isNotEmpty) {
      return buildFullName(
        firstName: first,
        middleName: middle,
        lastName: last,
        hasMiddleName: hasMiddle,
      );
    }

    final raw = _normalizeNamePart(fullName ?? '');
    return raw.isNotEmpty ? raw : fallback;
  }

  static NameParts? parseFullName(String fullName) {
    final parsed = _parseFromFullName(fullName);
    if (parsed == null) return null;
    return NameParts(
      firstName: parsed.firstName,
      middleName: parsed.middleName,
      lastName: parsed.lastName,
    );
  }

  static String _middleDisplay(String middleName) {
    final tokens = _tokens(middleName);
    if (tokens.isEmpty) return '';
    if (tokens.length == 1) return '${tokens.first[0].toUpperCase()}.';

    final firstToken = tokens.first;
    final restInitials = tokens
        .skip(1)
        .where((t) => t.isNotEmpty)
        .map((t) => '${t[0].toUpperCase()}.')
        .join(' ');

    return '$firstToken $restInitials'.trim();
  }

  static _ParsedName? _parseFromFullName(String fullName) {
    final tokens = _tokens(fullName);
    if (tokens.length < 2) return null;

    final firstName = tokens.first;
    final lastName = tokens.last;
    final middleName = tokens.sublist(1, tokens.length - 1).join(' ');

    return _ParsedName(
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
    );
  }

  static List<String> _tokens(String value) {
    final trimmed = _normalizeNamePart(value);
    if (trimmed.isEmpty) return const [];
    return trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  static String _normalizeNamePart(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class _ParsedName {
  const _ParsedName({
    required this.firstName,
    required this.middleName,
    required this.lastName,
  });

  final String firstName;
  final String middleName;
  final String lastName;
}

class NameParts {
  const NameParts({
    required this.firstName,
    required this.middleName,
    required this.lastName,
  });

  final String firstName;
  final String middleName;
  final String lastName;

  bool get hasMiddleName => middleName.trim().isNotEmpty;
}
