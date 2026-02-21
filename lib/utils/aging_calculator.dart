/// Aging bucket categories for receivables and payables
enum AgingBucket {
  current,      // Not yet due
  overdue1to30, // 1-30 days overdue
  overdue31to60, // 31-60 days overdue
  overdue60plus, // 60+ days overdue
}

class AgingCalculator {
  /// Calculate which aging bucket an invoice/bill falls into
  /// based on its due date compared to today.
  ///
  /// [invoiceDate] - the date the invoice was created
  /// [creditPeriodDays] - number of days credit given (0 = due immediately)
  /// [dueDate] - explicit due date (used if provided, otherwise calculated)
  static AgingBucket getAgingBucket({
    required DateTime invoiceDate,
    int? creditPeriodDays,
    DateTime? dueDate,
  }) {
    final effectiveDueDate = dueDate ??
        invoiceDate.add(Duration(days: creditPeriodDays ?? 0));
    final today = DateTime.now();
    final daysOverdue = today.difference(effectiveDueDate).inDays;

    if (daysOverdue <= 0) return AgingBucket.current;
    if (daysOverdue <= 30) return AgingBucket.overdue1to30;
    if (daysOverdue <= 60) return AgingBucket.overdue31to60;
    return AgingBucket.overdue60plus;
  }

  /// Get the number of days overdue (negative means not yet due)
  static int getDaysOverdue({
    required DateTime invoiceDate,
    int? creditPeriodDays,
    DateTime? dueDate,
  }) {
    final effectiveDueDate = dueDate ??
        invoiceDate.add(Duration(days: creditPeriodDays ?? 0));
    return DateTime.now().difference(effectiveDueDate).inDays;
  }

  /// Get human-readable label for an aging bucket
  static String getBucketLabel(AgingBucket bucket) {
    switch (bucket) {
      case AgingBucket.current:
        return 'Current (Not Due)';
      case AgingBucket.overdue1to30:
        return '1-30 Days';
      case AgingBucket.overdue31to60:
        return '31-60 Days';
      case AgingBucket.overdue60plus:
        return '60+ Days';
    }
  }

  /// Get short label for column headers
  static String getBucketShortLabel(AgingBucket bucket) {
    switch (bucket) {
      case AgingBucket.current:
        return 'Current';
      case AgingBucket.overdue1to30:
        return '1-30 Days';
      case AgingBucket.overdue31to60:
        return '31-60 Days';
      case AgingBucket.overdue60plus:
        return '60+ Days';
    }
  }
}
