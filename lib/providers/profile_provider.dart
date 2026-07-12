import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';

class ProfileProvider with ChangeNotifier {
  UserProfile _profile = UserProfile(firstName: 'Utilisateur', lastName: 'MoniTrack');

  UserProfile get profile => _profile;

  ProfileProvider() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? profileJson = prefs.getString('user_profile');
    if (profileJson != null) {
      _profile = UserProfile.fromJson(json.decode(profileJson));
      notifyListeners();
    }
  }

  Future<void> updateProfile(UserProfile newProfile) async {
    _profile = newProfile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', json.encode(_profile.toJson()));
    notifyListeners();
  }
}
