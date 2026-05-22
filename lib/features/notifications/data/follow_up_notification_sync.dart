import 'package:intl/intl.dart';

import '../../visits/data/models/visit_model.dart';
import 'notifications_local_store.dart';

/// Mirrors legacy [NotificationService.scheduleDailyFollowups] list rows: today's follow-ups
/// appear in the notification screen for the rest of the day.
Future<void> syncTodayFollowUpNotificationRows({
  required String currentUserId,
  required List<VisitModel> visits,
}) async {
  if (currentUserId.isEmpty) return;

  final store = NotificationsLocalStore.instance;
  final now = DateTime.now();

  for (final visit in visits) {
    if (visit.createdById != currentUserId) continue;

    final fDate = visit.followUpDate;
    if (fDate == null) continue;

    if (fDate.year != now.year || fDate.month != now.month || fDate.day != now.day) {
      continue;
    }

    final has = await store.hasFollowUpRowForVisit(
      userId: currentUserId,
      visitId: visit.id,
    );
    if (has) continue;

    final isDateOnly = fDate.hour == 0 && fDate.minute == 0 && fDate.second == 0;
    final name = visit.clientName.isNotEmpty ? visit.clientName : visit.contractorName;
    final title = 'Follow-up Reminder';
    final String body;
    if (isDateOnly) {
      body = 'You have a follow-up visit with $name today.';
    } else {
      body = 'Follow-up with $name at ${DateFormat('hh:mm a').format(fDate)}.';
    }

    await store.insertNotification(
      userId: currentUserId,
      title: title,
      body: body,
      type: 'followup',
      visitId: visit.id,
      receivedAt: DateTime.now(),
    );
  }
}
