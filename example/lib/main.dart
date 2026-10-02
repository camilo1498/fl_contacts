import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_contacts/fl_contacts.dart';

void main() => runApp(const ContactsExampleApp());

/// Demo root widget.
class ContactsExampleApp extends StatelessWidget {
  const ContactsExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fl_contacts example',
      theme: ThemeData(useMaterial3: true),
      home: const ContactsPage(),
    );
  }
}

/// Searchable contact list with thumbnails and pull-to-refresh.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  bool? _permission;
  bool _loading = false;
  String _filter = '';
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  /// Asks for access, loads once, then stays fresh via change events.
  Future<void> _requestPermission() async {
    final granted = await FlContacts.requestPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (granted) {
      await _reload();
      FlContacts.addListener(_scheduleReload);
    }
  }

  @override
  void dispose() {
    FlContacts.removeListener(_scheduleReload);
    super.dispose();
  }

  /// Listener-safe fan-in: the plugin expects a sync callback.
  void _scheduleReload() {
    unawaited(_reload());
  }

  /// Reloads hydrated contacts with thumbnails for the list.
  Future<void> _reload() async {
    setState(() => _loading = true);
    final contacts = await FlContacts.getContacts(
      withProperties: true,
      withThumbnail: true,
    );
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _loading = false;
    });
  }

  /// Contacts matching the current search query, if any.
  List<Contact> get _visible {
    if (_filter.isEmpty) return _contacts;
    final query = _filter.toLowerCase();
    return _contacts
        .where((c) => c.displayName.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_permission == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_permission == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('fl_contacts')),
        body: Center(
          child: FilledButton(
            onPressed: _requestPermission,
            child: const Text('Grant contact permission'),
          ),
        ),
      );
    }
    final visible = _visible;
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: SearchBar(
              hintText: 'Search contacts',
              onChanged: (value) => setState(() => _filter = value),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: _loading && _contacts.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (context, index) {
                        final contact = visible[index];
                        final thumbnail = contact.thumbnail;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: thumbnail != null
                                ? MemoryImage(thumbnail)
                                : null,
                            child: thumbnail == null
                                ? Text(
                                    contact.displayName.isNotEmpty
                                        ? contact.displayName[0]
                                        : '?',
                                  )
                                : null,
                          ),
                          title: Text(contact.displayName),
                          subtitle: Text(
                            contact.phones.isNotEmpty
                                ? contact.phones.first.number
                                : 'No phone number',
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
