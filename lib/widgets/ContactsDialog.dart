import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ContactsDialog extends StatefulWidget {
  final void Function(Contact) onContactSelected;

  const ContactsDialog({Key? key, required this.onContactSelected})
      : super(key: key);

  @override
  _ContactsDialogState createState() => _ContactsDialogState();
}

class _ContactsDialogState extends State<ContactsDialog> {
  List<Contact> contacts = [];
  List<Contact> filteredContacts = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchController.addListener(_filterContacts);
  }

  Future<void> _loadContacts() async {
    setState(() {
      _isLoading = true;
    });
    try {
      if (!await Permission.contacts.request().isGranted) {
        print('Contacts permission denied');
        setState(() {
          contacts = [];
          filteredContacts = [];
          _isLoading = false;
        });
        return;
      }

      // ✅ Fetch name and phone number
      final loadedContacts = await FastContacts.getAllContacts(
        fields: [ContactField.displayName, ContactField.phoneNumbers],
      );

      setState(() {
        contacts = loadedContacts;
        filteredContacts = loadedContacts;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading contacts: $e');
      setState(() {
        contacts = [];
        filteredContacts = [];
        _isLoading = false;
      });
    }
  }


  void _filterContacts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredContacts = contacts.where((contact) {
        final name = contact.displayName?.toLowerCase() ?? '';
        return name.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Emergency Contact'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredContacts.isEmpty
                  ? const Center(child: Text('No contacts found'))
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = filteredContacts[index];
                  return ListTile(
                    title: Text(contact.displayName ?? 'Unknown'),
                    subtitle: Text(
                      contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : 'No phone',
                    ),
                    onTap: () {
                      print(contact);
                      widget.onContactSelected(contact);
                      // Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}