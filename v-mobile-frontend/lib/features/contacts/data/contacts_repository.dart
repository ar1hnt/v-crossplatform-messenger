import 'package:dio/dio.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/contact_match.dart';

final contactsRepositoryProvider = Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.watch(apiClientProvider));
});

class ContactsRepository {
  const ContactsRepository(this._dio);

  final Dio _dio;

  Future<List<Map<String, String>>> readDeviceContacts() async {
    final hasPermission = await FlutterContacts.requestPermission(
      readonly: true,
    );
    if (!hasPermission) {
      return [];
    }
    final contacts = await FlutterContacts.getContacts(withProperties: true);
    return contacts
        .where((contact) => contact.phones.isNotEmpty)
        .map((contact) {
          final phone = _normalizePhone(contact.phones.first.number);
          final name = contact.displayName.trim().isEmpty
              ? 'Без имени'
              : contact.displayName.trim();
          return {'contact_name': name, 'phone_number': phone};
        })
        .where(
          (contact) =>
              (contact['phone_number'] ?? '').replaceAll('+', '').length >= 5,
        )
        .toList();
  }

  Future<List<ContactMatch>> syncDeviceContacts() async {
    final contacts = await readDeviceContacts();
    final response = await _dio.post<List<dynamic>>(
      '/contacts/sync',
      data: {'contacts': contacts},
    );
    return (response.data ?? [])
        .map((item) => ContactMatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ContactMatch>> getMatches() async {
    final response = await _dio.get<List<dynamic>>('/contacts/matches');
    return (response.data ?? [])
        .map((item) => ContactMatch.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  String _normalizePhone(String phoneNumber) {
    final raw = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.startsWith('8') && raw.length == 11) {
      return '+7${raw.substring(1)}';
    }
    if (raw.startsWith('7') && raw.length == 11) {
      return '+$raw';
    }
    return raw;
  }
}
