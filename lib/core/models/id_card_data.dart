class IdCardData {
  final bool isValid;
  final String? nationalId;
  final String? expiryDate;
  final double confidence;

  const IdCardData({
    required this.isValid,
    this.nationalId,
    this.expiryDate,
    required this.confidence,
  });
}
