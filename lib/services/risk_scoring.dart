class Pred {
  final String label; 
  Pred(this.label);
}

class RiskResult {
  final int totalScore;
  final String riskLevel;     // Low / Moderate / High
  final String action;        // No action / Notify / Trigger alert
  final bool shouldSendToCloud;

  RiskResult({
    required this.totalScore,
    required this.riskLevel,
    required this.action,
    required this.shouldSendToCloud,
  });
}

//Scoring tables

// Sleeping position scoring
int _scoreSleeping(String label) {
  switch (label) {
    case 'Normal':
      return 0;
    case 'Abnormal':
      return 2;
    default:
      return 0;
  }
}

// Facial expression scoring
int _scoreExpression(String label) {
  switch (label) {
    case 'Normal':
      return 0;
    case 'Distressed':
      return 2;
    default:
      return 0;
  }
}

// Cry type scoring
int _scoreCry(String label) {
  switch (label) {
    case 'Normal':
    case 'Hungry':
      return 1;
    case 'Pain':
      return 3;
    case 'Asphyxia':
      return 5;
    case 'Silent':
      return 0;
    default:
      return 0;
  }
}

//Total scoring + decision
RiskResult evaluateRisk({
  required Pred sleeping,
  required Pred expression,
  required Pred cry,
}) {
  final sleepScore = _scoreSleeping(sleeping.label);
  final exprScore  = _scoreExpression(expression.label);
  final cryScore   = _scoreCry(cry.label);

  final total = sleepScore + exprScore + cryScore;

  // Risk interpretation table
  String level, action;
  if (total >= 5) {
    level = "High";
    action = "Trigger immediate alert";
  } else if (total >= 3) {
    level = "Moderate";
    action = "Monitor and notify";
  } else {
    level = "Low";
    action = "No action required";
  }

  // Gate: only send to cloud if total >= 1 (your requirement)
  final sendToCloud = total >= 1;

  return RiskResult(
    totalScore: total,
    riskLevel: level,
    action: action,
    shouldSendToCloud: sendToCloud,
  );
}
