class VisitLine {
  final String id;
  final String category;
  final String serviceName;
  final String code;
  final double charge;
  final double sanPrice;
  final double benPlanAmount;
  final double memberPay;

  const VisitLine({
    required this.id,
    required this.category,
    required this.serviceName,
    required this.code,
    required this.charge,
    required this.sanPrice,
    required this.benPlanAmount,
    required this.memberPay,
  });

  factory VisitLine.fromJson(Map<String, dynamic> j) => VisitLine(
        id: (j['id'] ?? j['Id'] ?? j['lineId'] ?? '').toString(),
        category: (j['category'] ?? j['Category'] ?? '').toString(),
        serviceName:
            (j['serviceName'] ?? j['ServiceName'] ?? '').toString(),
        code: (j['code'] ?? j['Code'] ?? '').toString(),
        charge: double.tryParse(j['charge']?.toString() ?? '0') ?? 0,
        sanPrice: double.tryParse(j['sanPrice']?.toString() ?? '0') ?? 0,
        benPlanAmount:
            double.tryParse(j['benPlanAmount']?.toString() ?? '0') ?? 0,
        memberPay: double.tryParse(j['memberPay']?.toString() ?? '0') ?? 0,
      );
}
