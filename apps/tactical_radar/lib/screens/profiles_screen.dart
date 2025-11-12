import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models/aircraft_profile.dart';
import '../services/profile_repository.dart';

/// Screen for managing saved aircraft profiles.
///
/// Displays a list of saved aircraft profiles with their callsigns and ICAO hex
/// codes. Users can add, edit, and delete profiles. The screen automatically
/// refreshes when profiles are modified.
class ProfilesScreen extends StatefulWidget {
  /// Creates a profiles screen.
  const ProfilesScreen({super.key});

  @override
  State<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends State<ProfilesScreen> {
  final ProfileRepository _repository = ProfileRepository.instance;
  List<AircraftProfile> _profiles = [];
  StreamSubscription<ProfileEvent>? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    await _repository.init();
    await _loadProfiles();

    // Subscribe to changes
    _subscription = _repository.changes.listen((event) {
      _loadProfiles();
    });
  }

  Future<void> _loadProfiles() async {
    final profiles = await _repository.getAll();
    if (mounted) {
      setState(() {
        _profiles = profiles;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _showAddEditDialog({AircraftProfile? profile}) {
    final isEdit = profile != null;
    final callsignController =
        TextEditingController(text: profile?.callsign ?? '');
    final hexController = TextEditingController(text: profile?.icaoHex ?? '');

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Aircraft Profile' : 'Add Aircraft Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: callsignController,
              decoration: const InputDecoration(
                labelText: 'Callsign',
                helperText: 'e.g., VH-ABC, N12345',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: hexController,
              decoration: const InputDecoration(
                labelText: 'ICAO Hex',
                helperText: 'e.g., 7CC599',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [UpperCaseTextFormatter()],
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final callsign = callsignController.text.trim();
              final hex = hexController.text.trim();

              // Validate non-empty
              if (callsign.isEmpty || hex.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Callsign and hex are required'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Validate callsign length
              if (callsign.length > 50) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Callsign must be less than 50 characters'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                const uuid = Uuid();
                final newProfile = AircraftProfile(
                  id: profile?.id ?? uuid.v4(),
                  icaoHex: hex,
                  callsign: callsign,
                  createdAt: profile?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await _repository.save(newProfile);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Profile updated successfully'
                          : 'Profile added successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on DuplicateHexError catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${e.message}\n${e.hint}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text(isEdit ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(AircraftProfile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
          'Are you sure you want to delete '
          '"${profile.callsign}" (${profile.icaoHex})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await _repository.delete(profile.id);

                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Aircraft Profiles'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.flight,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved aircraft',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add one',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    return ListTile(
                      leading: const Icon(Icons.flight),
                      title: Text(
                        profile.callsign,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(profile.icaoHex),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showAddEditDialog(profile: profile),
                            tooltip: 'Edit profile',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _showDeleteConfirmation(profile),
                            tooltip: 'Delete profile',
                          ),
                        ],
                      ),
                      onTap: () => _showAddEditDialog(profile: profile),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        tooltip: 'Add aircraft profile',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Text input formatter that converts all input to uppercase.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
