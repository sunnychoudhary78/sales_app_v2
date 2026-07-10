enum VisitScope { all, mine, team }

enum VisitTypeFilter { all, newVisit, followup }

class VisitListFilters {
  const VisitListFilters({
    this.scope = VisitScope.all,
    this.employeeId,
    this.startDate,
    this.endDate,
    this.search = '',
    this.visitType = VisitTypeFilter.all,
  });

  final VisitScope scope;
  final String? employeeId;
  final DateTime? startDate;
  final DateTime? endDate;
  final String search;
  final VisitTypeFilter visitType;

  static const mineOnly = VisitListFilters(scope: VisitScope.mine);

  bool get hasActiveFilters =>
      scope != VisitScope.all ||
      (employeeId != null && employeeId!.isNotEmpty) ||
      startDate != null ||
      endDate != null ||
      search.trim().isNotEmpty ||
      visitType != VisitTypeFilter.all;

  VisitListFilters copyWith({
    VisitScope? scope,
    String? employeeId,
    bool clearEmployeeId = false,
    DateTime? startDate,
    DateTime? endDate,
    bool clearStartDate = false,
    bool clearEndDate = false,
    String? search,
    VisitTypeFilter? visitType,
  }) {
    return VisitListFilters(
      scope: scope ?? this.scope,
      employeeId: clearEmployeeId ? null : (employeeId ?? this.employeeId),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      search: search ?? this.search,
      visitType: visitType ?? this.visitType,
    );
  }

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (employeeId != null && employeeId!.isNotEmpty) {
      params['userId'] = employeeId;
    } else {
      params['scope'] = switch (scope) {
        VisitScope.all => 'all',
        VisitScope.mine => 'mine',
        VisitScope.team => 'team',
      };
    }
    if (startDate != null) {
      params['startDate'] = _isoDate(startDate!);
    }
    if (endDate != null) {
      params['endDate'] = _isoDate(endDate!);
    }
    final q = search.trim();
    if (q.isNotEmpty) params['search'] = q;
    switch (visitType) {
      case VisitTypeFilter.newVisit:
        params['isNewVisit'] = 'true';
      case VisitTypeFilter.followup:
        params['isNewVisit'] = 'false';
      case VisitTypeFilter.all:
        break;
    }
    return params;
  }

  static String _isoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class VisitsListMeta {
  const VisitsListMeta({this.canFilterTeam = false, this.total = 0});

  final bool canFilterTeam;
  final int total;

  factory VisitsListMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VisitsListMeta();
    return VisitsListMeta(
      canFilterTeam: json['can_filter_team'] == true,
      total: int.tryParse(json['total']?.toString() ?? '') ?? 0,
    );
  }
}

class VisitTeamMember {
  const VisitTeamMember({
    required this.id,
    required this.name,
    this.employeeId,
    this.departmentName,
    this.companyName,
  });

  final String id;
  final String name;
  final String? employeeId;
  final String? departmentName;
  final String? companyName;

  factory VisitTeamMember.fromJson(Map<String, dynamic> json) {
    return VisitTeamMember(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      employeeId: json['employee_id']?.toString(),
      departmentName: json['department_name']?.toString(),
      companyName: json['company_name']?.toString(),
    );
  }

  String displayLabel({bool showCompany = false}) {
    final code = employeeId?.trim();
    var label = name;
    if (code != null && code.isNotEmpty) {
      label = '$name ($code)';
    }
    final company = companyName?.trim();
    if (showCompany && company != null && company.isNotEmpty) {
      label = '$label · $company';
    }
    return label;
  }
}
