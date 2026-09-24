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

  Future<Contact> addContact(String code, {String? alias}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newContact = await _contactService.addContact(code, alias: alias);
      upsertContact(newContact);
      return newContact;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Ajoute un contact dans la liste locale sans créer de doublon (par id ou
  /// code utilisateur). Appelé par [addContact] mais aussi par les écrans qui
  /// viennent de créer un contact : cela garantit que le contact est présent
  /// dans la liste au moment du rebuild, même si un `fetchContacts` concurrent
  /// (réseau lent) a remplacé la liste entre-temps.
  void upsertContact(Contact contact) {
    final index = _contacts.indexWhere(
      (c) => c.id == contact.id ||
          (c.userCode.isNotEmpty && c.userCode == contact.userCode),
    );
    if (index >= 0) {
      _contacts[index] = contact;
    } else {
      _contacts.add(contact);
    }
    notifyListeners();
  }

  /// Vide l'état en mémoire (déconnexion) : les contacts sont propres à
  /// chaque compte et seront re-téléchargés à la prochaine connexion.
  void clear() {
    _contacts = [];
    _error = null;
    notifyListeners();
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
