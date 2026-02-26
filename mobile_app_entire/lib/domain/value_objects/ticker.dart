class Ticker {
  const Ticker._(this.value);

  final String value;

  static Ticker fromRaw(String raw) {
    final normalized = raw.trim().toUpperCase();
    if (normalized.isEmpty) {
      throw const FormatException('티커가 비어 있습니다.');
    }
    final cleaned = normalized.replaceAll(RegExp(r'[^A-Z0-9.]'), '');
    if (cleaned.isEmpty) {
      throw const FormatException('유효한 티커 형식이 아닙니다.');
    }
    return Ticker._(cleaned);
  }
}
