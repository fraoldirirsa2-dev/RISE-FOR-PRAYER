import 'package:shared_preferences/shared_preferences.dart';

class PreferencesStore {
  PreferencesStore._();

  static final PreferencesStore instance = PreferencesStore._();

  Future<SharedPreferences> get preferences async {
    return SharedPreferences.getInstance();
  }
}
