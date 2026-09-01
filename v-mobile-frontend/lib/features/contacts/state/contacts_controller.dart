import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/contacts_repository.dart';
import '../domain/contact_match.dart';

class ContactsController extends AsyncNotifier<List<ContactMatch>> {
  @override
  Future<List<ContactMatch>> build() async {
    return ref.read(contactsRepositoryProvider).getMatches();
  }

  Future<void> syncContacts() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(contactsRepositoryProvider).syncDeviceContacts(),
    );
  }
}

final contactsControllerProvider =
    AsyncNotifierProvider<ContactsController, List<ContactMatch>>(
      ContactsController.new,
    );
