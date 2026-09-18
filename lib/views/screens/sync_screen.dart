import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../services/sync_service.dart';
import '../../providers/cart_provider.dart';
import '../../l10n/app_localizations.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  bool _isServerMode = true;
  bool _isServerRunning = false;
  int _connectedClients = 0;
  List<DiscoveredDevice> _devices = [];
  List<SyncEvent> _events = [];
  bool _isSyncing = false;

  StreamSubscription? _devicesSub;
  StreamSubscription? _eventsSub;

  @override
  void initState() {
    super.initState();
    _listenToStreams();
  }

  void _listenToStreams() {
    _devicesSub = SyncService.instance.devicesStream.listen((devices) {
      if (mounted) setState(() => _devices = devices);
    });

    _eventsSub = SyncService.instance.eventsStream.listen((event) {
      if (mounted) {
        setState(() {
          _events.insert(0, event);
          if (_events.length > 20) _events.removeLast();
          if (event.type == SyncEventType.syncComplete) _isSyncing = false;
          if (event.type == SyncEventType.error) _isSyncing = false;
        });
      }
    });
  }

  Future<void> _toggleServer() async {
    if (_isServerRunning) {
      await SyncService.instance.stopServer();
      setState(() {
        _isServerRunning = false;
        _connectedClients = 0;
      });
    } else {
      final port = await SyncService.instance.startServer();
      if (port != null) {
        setState(() {
          _isServerRunning = true;
        });
      }
    }
  }

  void _startDiscovery() {
    SyncService.instance.startDiscovery();
  }

  void _stopDiscovery() {
    SyncService.instance.stopDiscovery();
  }

  Future<void> _pullFromDevice(DiscoveredDevice device) async {
    setState(() => _isSyncing = true);
    await SyncService.instance.pullFromServer(device);
    // Refresh all data
    ref.invalidate(cartProvider);
    setState(() => _isSyncing = false);
  }

  Future<void> _pushToDevice(DiscoveredDevice device) async {
    setState(() => _isSyncing = true);
    await SyncService.instance.pushToServer(device);
    setState(() => _isSyncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _stopDiscovery();
          context.go('/');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _stopDiscovery();
              context.go('/');
            },
          ),
          title: Text(loc.tr('network_sync')),
        ),
        body: Column(
          children: [
            // Mode toggle
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isServerMode = true;
                        _stopDiscovery();
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isServerMode ? theme.colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.router, size: 18,
                                color: _isServerMode ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(loc.tr('start_server'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: _isServerMode ? Colors.white : Colors.grey[600],
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _isServerMode = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isServerMode ? theme.colorScheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.devices, size: 18,
                                color: !_isServerMode ? Colors.white : Colors.grey[600]),
                            const SizedBox(width: 6),
                            Text(loc.tr('connect_to_server'),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13,
                                  color: !_isServerMode ? Colors.white : Colors.grey[600],
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isServerMode
                  ? _buildServerView(loc, theme)
                  : _buildClientView(loc, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerView(AppLocalizations loc, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Server status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isServerRunning ? Colors.green[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _isServerRunning ? Colors.green[200]! : Colors.grey[300]!),
            ),
            child: Column(
              children: [
                Icon(
                  _isServerRunning ? Icons.check_circle : Icons.cancel,
                  size: 48,
                  color: _isServerRunning ? Colors.green : Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  _isServerRunning ? loc.tr('server_running') : loc.tr('server_stopped'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _isServerRunning ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                if (_isServerRunning) ...[
                  const SizedBox(height: 4),
                  Text('${loc.tr('connected')}: $_connectedClients',
                      style: TextStyle(color: Colors.green[600], fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Start/Stop button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _toggleServer,
              icon: Icon(_isServerRunning ? Icons.stop : Icons.play_arrow),
              label: Text(_isServerRunning ? loc.tr('stop_server') : loc.tr('start_server')),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isServerRunning ? Colors.red[600] : theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sync log
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Sync Log', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[700])),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _events.isEmpty
                ? Center(child: Text('No events yet', style: TextStyle(color: Colors.grey[400])))
                : ListView.builder(
                    itemCount: _events.length,
                    itemBuilder: (_, i) {
                      final event = _events[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          _eventIcon(event.type),
                          size: 16,
                          color: _eventColor(event.type),
                        ),
                        title: Text(event.message, style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                          '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientView(AppLocalizations loc, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Scan button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isSyncing ? null : _startDiscovery,
              icon: const Icon(Icons.search),
              label: Text(loc.tr('searching_devices')),
            ),
          ),
          const SizedBox(height: 16),

          // Discovered devices
          if (_devices.isNotEmpty) ...[
            Text('${_devices.length} ${loc.tr('devices_found')}',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[700])),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (_, i) {
                  final device = _devices[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: theme.colorScheme.primary.withAlpha(20),
                        child: Icon(Icons.computer, color: theme.colorScheme.primary, size: 20),
                      ),
                      title: Text(device.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${device.address}:${device.port}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pull button
                          IconButton(
                            onPressed: _isSyncing ? null : () => _pullFromDevice(device),
                            icon: Icon(Icons.cloud_download, color: Colors.blue[600]),
                            tooltip: loc.tr('pull_data'),
                          ),
                          // Push button
                          IconButton(
                            onPressed: _isSyncing ? null : () => _pushToDevice(device),
                            icon: Icon(Icons.cloud_upload, color: Colors.green[600]),
                            tooltip: loc.tr('push_data'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.devices_other, size: 64, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(loc.tr('searching_devices'),
                        style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Make sure both devices are on the same Wi-Fi or Hotspot',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ],

          // Sync progress
          if (_isSyncing) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(loc.tr('sync_now'), style: TextStyle(color: Colors.grey[600])),
          ],

          // Events
          if (_events.isNotEmpty) ...[
            const Divider(),
            SizedBox(
              height: 100,
              child: ListView.builder(
                itemCount: _events.length.clamp(0, 5),
                itemBuilder: (_, i) {
                  final event = _events[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(_eventIcon(event.type), size: 14, color: _eventColor(event.type)),
                    title: Text(event.message, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _eventIcon(SyncEventType type) {
    switch (type) {
      case SyncEventType.serverStarted: return Icons.play_circle;
      case SyncEventType.serverStopped: return Icons.stop_circle;
      case SyncEventType.deviceFound: return Icons.devices;
      case SyncEventType.connecting: return Icons.wifi_find;
      case SyncEventType.syncing: return Icons.sync;
      case SyncEventType.syncComplete: return Icons.check_circle;
      case SyncEventType.syncRequested: return Icons.cloud_download;
      case SyncEventType.error: return Icons.error;
    }
  }

  Color _eventColor(SyncEventType type) {
    switch (type) {
      case SyncEventType.serverStarted: return Colors.green;
      case SyncEventType.serverStopped: return Colors.grey;
      case SyncEventType.deviceFound: return Colors.blue;
      case SyncEventType.connecting: return Colors.orange;
      case SyncEventType.syncing: return Colors.blue;
      case SyncEventType.syncComplete: return Colors.green;
      case SyncEventType.syncRequested: return Colors.purple;
      case SyncEventType.error: return Colors.red;
    }
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _eventsSub?.cancel();
    super.dispose();
  }
}
