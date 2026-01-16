class StableFlag {
  bool isAbnormal = false;
  int _abnormalStreak = 0;
  int _normalStreak = 0;

  final int enterK;
  final int exitJ;

  StableFlag({
    this.enterK = 2,
    this.exitJ = 3,
  });

  void update({required bool abnormalNow}) {
    if (abnormalNow) {
      _abnormalStreak++;
      _normalStreak = 0;
    } else {
      _normalStreak++;
      _abnormalStreak = 0;
    }

    // Enter abnormal quickly (safety-first)
    if (!isAbnormal && _abnormalStreak >= enterK) {
      isAbnormal = true;
    }

    // Exit abnormal more slowly (stability)
    if (isAbnormal && _normalStreak >= exitJ) {
      isAbnormal = false;
    }
  }

  void reset() {
    isAbnormal = false;
    _abnormalStreak = 0;
    _normalStreak = 0;
  }
}