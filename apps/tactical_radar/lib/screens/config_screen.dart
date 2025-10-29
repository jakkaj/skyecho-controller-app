import 'dart:async';
import 'package:flutter/material.dart';
import 'package:skyecho/skyecho.dart';

/// Configuration screen for SkyEcho device settings.
///
/// Displays and allows editing of:
/// - ICAO hex address
/// - Callsign
/// - 1090ES transmit enable/disable
///
/// Polls device every 1 second to maintain connection status.
class ConfigScreen extends StatefulWidget {
  /// Creates a configuration screen.
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  // SkyEcho client
  late final SkyEchoClient _client;

  // Text controllers
  late final TextEditingController _hexController;
  late final TextEditingController _callsignController;

  // State
  bool _transmitEnabled = false;
  bool _deviceTransmitting = false; // Actual state from device polls
  bool _isConnected = false;
  bool _isSaving = false;
  int _failureCount = 0;
  String? _errorMessage;
  bool _hasUserEdits = false;

  // Polling timer
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();

    _client = SkyEchoClient('http://192.168.4.1');
    _hexController = TextEditingController();
    _callsignController = TextEditingController();

    // Start polling
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _hexController.dispose();
    _callsignController.dispose();
    super.dispose();
  }

  void _startPolling() {
    // Poll every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isSaving) {
        _pollDevice();
      }
    });

    // Initial poll
    _pollDevice();
  }

  Future<void> _pollDevice() async {
    try {
      final config = await _client.fetchSetupConfig();

      if (mounted) {
        setState(() {
          _isConnected = true;
          _failureCount = 0;
          _errorMessage = null;

          // ALWAYS update device transmit state (for app bar indicator)
          _deviceTransmitting = config.es1090TransmitEnabled;

          // Only update UI fields if user hasn't made any edits
          if (!_hasUserEdits) {
            _hexController.text = config.icaoAddress;
            _callsignController.text = config.callsign;
            _transmitEnabled = config.es1090TransmitEnabled;
          }
        });
      }
    } on SkyEchoError catch (e) {
      if (mounted) {
        setState(() {
          _failureCount++;

          // Show "Not Connected" after 2 failures (10 seconds at 5s interval)
          if (_failureCount >= 2) {
            _isConnected = false;
            _deviceTransmitting = false; // Device offline = not transmitting
            _errorMessage = 'Not Connected - ${e.message}\n${e.hint ?? ''}';
          }
        });
      }
    }
  }

  Future<void> _handleSave() async {
    // Pause polling
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Apply changes (applySetup internally fetches fresh config first)
      final result = await _client.applySetup((update) {
        update.icaoAddress = _hexController.text.trim();
        update.callsign = _callsignController.text.trim().toUpperCase();
        update.es1090TransmitEnabled = _transmitEnabled;
      });

      if (mounted) {
        if (result.verified) {
          setState(() {
            _errorMessage = '✅ Configuration saved successfully';
            _hasUserEdits = false; // Reset edit flag after successful save
          });
        } else {
          setState(() {
            _errorMessage =
                '⚠️ Save succeeded but verification failed:\n'
                '${result.mismatches}';
          });
        }
      }
    } on SkyEchoFieldError catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Validation Error:\n${e.message}\n${e.hint ?? ''}';
        });
      }
    } on SkyEchoNetworkError catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Network Error:\n${e.message}\n${e.hint ?? ''}';
        });
      }
    } on SkyEchoHttpError catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Device Error:\n${e.message}\n${e.hint ?? ''}';
        });
      }
    } on SkyEchoError catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '❌ Error:\n${e.message}\n${e.hint ?? ''}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine app bar color based on transmit state
    final appBarColor = !_isConnected
        ? Colors.grey.shade700 // Grey when disconnected
        : _deviceTransmitting
            ? Colors.green.shade600 // Green when transmitting
            : Colors.grey.shade700; // Grey when connected but not transmitting

    return Scaffold(
      appBar: AppBar(
        title: Text(
          !_isConnected
              ? 'SkyEcho - DISCONNECTED'
              : _deviceTransmitting
                  ? 'SkyEcho - TRANSMITTING'
                  : 'SkyEcho - STANDBY',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: appBarColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Not Connected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ICAO Hex Address
            TextField(
              controller: _hexController,
              decoration: const InputDecoration(
                labelText: 'ICAO Hex Address',
                helperText: 'e.g., 7CC599',
                border: OutlineInputBorder(),
              ),
              enabled: _isConnected && !_isSaving,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) {
                setState(() {
                  _hasUserEdits = true;
                });
              },
            ),
            const SizedBox(height: 16),

            // Callsign
            TextField(
              controller: _callsignController,
              decoration: const InputDecoration(
                labelText: 'Callsign',
                helperText: '1-8 alphanumeric characters',
                border: OutlineInputBorder(),
              ),
              enabled: _isConnected && !_isSaving,
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
              onChanged: (_) {
                setState(() {
                  _hasUserEdits = true;
                });
              },
            ),
            const SizedBox(height: 16),

            // 1090ES Transmit Enable
            CheckboxListTile(
              title: const Text('1090ES Transmit'),
              subtitle: const Text(
                'Enable ADS-B transmit (requires proper authorization)',
              ),
              value: _transmitEnabled,
              onChanged: _isConnected && !_isSaving
                  ? (value) {
                      setState(() {
                        _transmitEnabled = value ?? false;
                        _hasUserEdits = true;
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 24),

            // Save Button
            FilledButton.icon(
              onPressed: _isConnected && !_isSaving ? _handleSave : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Saving...' : 'Save Configuration'),
            ),
            const SizedBox(height: 24),

            // Error/Success Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _errorMessage!.startsWith('✅')
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  border: Border.all(
                    color: _errorMessage!.startsWith('✅')
                        ? Colors.green
                        : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: _errorMessage!.startsWith('✅')
                        ? Colors.green.shade900
                        : Colors.red.shade900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
