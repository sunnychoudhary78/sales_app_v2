import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/shared_preferences_provider.dart';
import '../../data/location_disclosure_store.dart';

final locationDisclosureStoreProvider = Provider<LocationDisclosureStore>((ref) {
  return LocationDisclosureStore(ref.watch(sharedPreferencesProvider));
});
