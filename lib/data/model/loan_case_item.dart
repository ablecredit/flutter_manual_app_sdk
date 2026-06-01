class LoanCaseItem {
  final String applicationId;
  final String loanReference;
  final int createdAt;

  const LoanCaseItem({
    required this.applicationId,
    required this.loanReference,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'applicationId': applicationId,
        'loanReference': loanReference,
        'createdAt': createdAt,
      };

  factory LoanCaseItem.fromJson(Map<String, dynamic> json) => LoanCaseItem(
        applicationId: json['applicationId'] as String? ?? '',
        loanReference: json['loanReference'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
      );
}
