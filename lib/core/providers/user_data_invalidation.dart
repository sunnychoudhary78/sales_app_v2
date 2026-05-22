import '../../features/claims/presentation/providers/claims_provider.dart';
import '../../features/home/presentation/providers/home_dashboard_provider.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';
import '../../features/products/presentation/providers/products_provider.dart';
import '../../features/tracking/presentation/providers/tracking_provider.dart';
import '../../features/visits/presentation/providers/visits_providers.dart';

/// Clears cached async/notifier state tied to the signed-in user. Call when
/// [userId] changes in [AppRoot] so lists and form notifiers cannot flash
/// another user's data.
void invalidateAllUserScopedData(dynamic ref) {
  ref.invalidate(trackingProvider);
  ref.invalidate(visitsProvider);
  ref.invalidate(productsProvider);
  ref.invalidate(homeDashboardProvider);
  ref.invalidate(myClaimPreviewProvider);
  ref.invalidate(managerClaimRequestsProvider);
  ref.invalidate(notificationsProvider);
  ref.invalidate(unreadCountProvider);
}
