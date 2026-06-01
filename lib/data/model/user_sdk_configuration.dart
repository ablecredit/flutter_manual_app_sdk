class UserSdkConfiguration {
  final String id;
  final String displayName;
  final String apiKey;
  final String tenantId;
  final String baseUrl;
  final String userId;
  final String branchId;

  const UserSdkConfiguration({
    required this.id,
    required this.displayName,
    required this.apiKey,
    required this.tenantId,
    required this.baseUrl,
    required this.userId,
    this.branchId = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'apiKey': apiKey,
        'tenantId': tenantId,
        'baseUrl': baseUrl,
        'userId': userId,
        'branchId': branchId,
      };

  factory UserSdkConfiguration.fromJson(Map<String, dynamic> json) =>
      UserSdkConfiguration(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        tenantId: json['tenantId'] as String? ?? '',
        baseUrl: json['baseUrl'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        branchId: json['branchId'] as String? ?? '',
      );

  UserSdkConfiguration copyWith({
    String? id,
    String? displayName,
    String? apiKey,
    String? tenantId,
    String? baseUrl,
    String? userId,
    String? branchId,
  }) =>
      UserSdkConfiguration(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        apiKey: apiKey ?? this.apiKey,
        tenantId: tenantId ?? this.tenantId,
        baseUrl: baseUrl ?? this.baseUrl,
        userId: userId ?? this.userId,
        branchId: branchId ?? this.branchId,
      );
}
