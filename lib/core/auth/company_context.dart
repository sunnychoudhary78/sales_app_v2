class CompanyContext {
  const CompanyContext({
    this.companyId,
    this.companyName,
    this.tenantRootCompanyId,
    this.isSubCompany = false,
    this.companyLocked = false,
    this.accessibleCompanyIds = const [],
  });

  final String? companyId;
  final String? companyName;
  final String? tenantRootCompanyId;
  final bool isSubCompany;
  final bool companyLocked;
  final List<String> accessibleCompanyIds;

  bool get spansMultipleCompanies => accessibleCompanyIds.length > 1;

  String get displayCompanyName {
    final name = companyName?.trim() ?? '';
    if (name.isEmpty) return '';
    if (isSubCompany) return '$name (Sub)';
    return name;
  }

  String tenantScopeKey(String userId) {
    final root = tenantRootCompanyId ?? companyId ?? '';
    final cid = companyId ?? '';
    return '$userId|$root|$cid';
  }

  factory CompanyContext.fromUser(Map<String, dynamic>? user) {
    if (user == null) return const CompanyContext();

    final rawIds = user['accessible_company_ids'];
    final ids = <String>[];
    if (rawIds is List) {
      for (final id in rawIds) {
        final s = id?.toString().trim();
        if (s != null && s.isNotEmpty) ids.add(s);
      }
    }

    return CompanyContext(
      companyId: user['company_id']?.toString(),
      companyName: user['company_name']?.toString(),
      tenantRootCompanyId: user['tenant_root_company_id']?.toString(),
      isSubCompany: user['is_sub_company'] == true,
      companyLocked: user['company_locked'] == true,
      accessibleCompanyIds: ids,
    );
  }
}
