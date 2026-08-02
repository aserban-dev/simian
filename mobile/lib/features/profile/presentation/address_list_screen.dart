/// Saved addresses (T120, T116).
///
/// FR-040 and FR-041: several addresses, exactly one marked default. FR-063: the no-addresses
/// state carries copy and an action, because a user arriving from checkout with nothing saved
/// needs to be told what to do, not shown an empty box.
library;

import 'package:flutter/material.dart';

@immutable
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.formatted,
    required this.isDefault,
    this.label,
    this.recipientName,
  });

  final String id;
  final String formatted;
  final bool isDefault;
  final String? label;
  final String? recipientName;
}

class AddressListScreen extends StatelessWidget {
  const AddressListScreen({
    required this.addresses,
    this.onAdd,
    this.onEdit,
    this.onDelete,
    this.onMakeDefault,
    super.key,
  });

  final List<SavedAddress> addresses;
  final VoidCallback? onAdd;
  final void Function(SavedAddress address)? onEdit;
  final void Function(SavedAddress address)? onDelete;
  final void Function(SavedAddress address)? onMakeDefault;

  static const String title = 'Delivery addresses';
  static const String emptyTitle = 'No addresses saved';
  static const String emptyBody =
      'Add where you would like your orders delivered. You can save more than one.';
  static const String addLabel = 'Add an address';
  static const String defaultLabel = 'Default';
  static const IconData emptyIcon = Icons.location_off_outlined;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(title)),
      body: SafeArea(
        child: addresses.isEmpty
            ? _Empty(onAdd: onAdd)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: addresses.length,
                separatorBuilder: (_, __) => const Divider(height: 24),
                itemBuilder: (BuildContext context, int index) => _Row(
                  address: addresses[index],
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onMakeDefault: onMakeDefault,
                ),
              ),
      ),
      floatingActionButton: addresses.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text(addLabel),
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              AddressListScreen.emptyIcon,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              AddressListScreen.emptyTitle,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              AddressListScreen.emptyBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              child: const Text(AddressListScreen.addLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.address, this.onEdit, this.onDelete, this.onMakeDefault});

  final SavedAddress address;
  final void Function(SavedAddress address)? onEdit;
  final void Function(SavedAddress address)? onDelete;
  final void Function(SavedAddress address)? onMakeDefault;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Text(address.label ?? 'Address', style: theme.textTheme.titleMedium),
            // FR-041 in words as well as position: a badge that only differed by colour would
            // be invisible to a screen reader (Principle VII).
            if (address.isDefault)
              const Chip(
                label: Text(AddressListScreen.defaultLabel),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        if (address.recipientName != null) Text(address.recipientName!),
        Text(address.formatted, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: <Widget>[
            TextButton(
              onPressed: onEdit == null ? null : () => onEdit!(address),
              child: const Text('Edit'),
            ),
            if (!address.isDefault)
              TextButton(
                onPressed: onMakeDefault == null ? null : () => onMakeDefault!(address),
                child: const Text('Make default'),
              ),
            TextButton(
              onPressed: onDelete == null ? null : () => onDelete!(address),
              child: const Text('Delete'),
            ),
          ],
        ),
      ],
    );
  }
}
