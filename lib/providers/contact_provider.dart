import 'package:flutter/foundation.dart';
import '../models/contact.dart';
import '../services/contact_service.dart';

class ContactProvider with ChangeNotifier {
  final ContactService _contactService = ContactService();

  List<Contact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchContacts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _contacts = await _contactService.getContacts();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addContact(String code, {String? alias}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newContact = await _contactService.addContact(code, alias: alias);
      _contacts.add(newContact);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteContact(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _contactService.deleteContact(id);
      _contacts.removeWhere((c) => c.id == id);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
