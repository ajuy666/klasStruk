import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class ExpenseLimitService {
  static const _limitPrefix = 'monthly_expense_limit_';
  static const _notifiedPrefix = 'monthly_expense_limit_notified_';

  Future<double> getMonthlyLimit(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getDouble('$_limitPrefix$userId') ?? 0;
  }

  Future<void> saveMonthlyLimit(String userId, double limit) async {
    final preferences = await SharedPreferences.getInstance();
    if (limit <= 0) {
      await preferences.remove('$_limitPrefix$userId');
      await preferences.remove(_notifiedKey(userId));
      return;
    }

    await preferences.setDouble('$_limitPrefix$userId', limit);
    await preferences.remove(_notifiedKey(userId));
  }

  Future<ExpenseLimitStatus> getStatus({
    required String userId,
    required double currentExpense,
  }) async {
    final limit = await getMonthlyLimit(userId);
    final percent = limit <= 0 ? 0.0 : currentExpense / limit;

    return ExpenseLimitStatus(
      limit: limit,
      currentExpense: currentExpense,
      percent: percent,
    );
  }

  Future<void> notifyIfNeeded({
    required String userId,
    required double currentExpense,
  }) async {
    final status = await getStatus(
      userId: userId,
      currentExpense: currentExpense,
    );

    if (!status.isEnabled || status.percent < 0.8) return;

    final preferences = await SharedPreferences.getInstance();
    final key = _notifiedKey(userId);
    final alertLevel = status.isOverLimit ? 'over' : 'warning';

    if (preferences.getString(key) == alertLevel) return;

    await preferences.setString(key, alertLevel);

    await NotificationService.showExpenseLimitWarning(
      title: status.isOverLimit
          ? 'Batas pengeluaran terlewati'
          : 'Pengeluaran hampir mencapai batas',
      body: status.isOverLimit
          ? 'Pengeluaran bulan ini sudah melewati batas yang kamu atur.'
          : 'Pengeluaran bulan ini sudah mencapai ${status.percentLabel}.',
    );
  }

  String _notifiedKey(String userId) {
    final now = DateTime.now();
    return '$_notifiedPrefix${userId}_${now.year}_${now.month}';
  }
}

class ExpenseLimitStatus {
  final double limit;
  final double currentExpense;
  final double percent;

  const ExpenseLimitStatus({
    required this.limit,
    required this.currentExpense,
    required this.percent,
  });

  bool get isEnabled => limit > 0;
  bool get isOverLimit => isEnabled && currentExpense >= limit;
  bool get isWarning => isEnabled && percent >= 0.8 && percent < 1;

  String get percentLabel {
    if (!isEnabled) return '0%';
    return '${(percent * 100).clamp(0, 999).round()}%';
  }
}
