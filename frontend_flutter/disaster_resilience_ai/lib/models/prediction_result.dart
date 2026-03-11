/// Data class representing an AI risk prediction response.
class PredictionResult {
  final double riskScore;
  final String riskLevel;
  final String model;
  final String modelVersion;
  final Map<String, double> featureImportances;

  PredictionResult({
    required this.riskScore,
    required this.riskLevel,
    required this.model,
    required this.modelVersion,
    this.featureImportances = const {},
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    final importances = <String, double>{};
    if (json['feature_importances'] is Map) {
      (json['feature_importances'] as Map).forEach((k, v) {
        importances[k.toString()] = (v as num).toDouble();
      });
    }
    return PredictionResult(
      riskScore: (json['risk_score'] as num).toDouble(),
      riskLevel: json['risk_level'] as String? ?? 'unknown',
      model: json['model'] as String,
      modelVersion: json['model_version'] as String,
      featureImportances: importances,
    );
  }
}
