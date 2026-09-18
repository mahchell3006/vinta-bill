import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'backup_service.dart';

/// Network sync service using NSD (Network Service Discovery) and HTTP
class SyncService {
  SyncService._();
  static final instance = SyncService._();

  static const String serviceType = '_algerian_billing._tcp';
  static const String serviceName = 'AlgerianBilling';

  // Server state
  HttpServer? _server;
  bool _isServerRunning = false;
  int _connectedClients = 0;

  // Client state
  List<DiscoveredDevice> _discoveredDevices = [];
  StreamController<List<DiscoveredDevice>> _devicesController = StreamController.broadcast();
  StreamController<SyncEvent> _eventsController = StreamController.broadcast();

  // Timers
  Timer? _broadcastTimer;

  bool get isServerRunning => _isServerRunning;
  int get connectedClients => _connectedClients;
  List<DiscoveredDevice> get discoveredDevices => _discoveredDevices;

  Stream<List<DiscoveredDevice>> get devicesStream => _devicesController.stream;
  Stream<SyncEvent> get eventsStream => _eventsController.stream;

  // ==================== SERVER ====================

  /// Start the sync server on a dynamic port
  Future<int?> startServer() async {
    try {
      final shop = await DatabaseService.instance.getShop();
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      _server = server;
      _isServerRunning = true;

      final port = server.port;
      _emitEvent(SyncEvent(message: 'Server started on port $port', type: SyncEventType.serverStarted));

      // Register NSD service
      _registerNsdService(port);

      // Handle requests
      server.listen((HttpRequest request) async {
        _handleRequest(request, shop);
      });

      return port;
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Failed to start server: $e', type: SyncEventType.error));
      return null;
    }
  }

  /// Stop the sync server
  Future<void> stopServer() async {
    try {
      _broadcastTimer?.cancel();
      await _server?.close();
      _server = null;
      _isServerRunning = false;
      _connectedClients = 0;
      _emitEvent(SyncEvent(message: 'Server stopped', type: SyncEventType.serverStopped));
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Error stopping server: $e', type: SyncEventType.error));
    }
  }

  void _registerNsdService(int port) {
    // NSD registration is platform-specific and complex
    // For simplicity, we'll use UDP broadcast for device discovery
    _broadcastDeviceInfo(port);

    // Re-broadcast every 3 seconds
    _broadcastTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _broadcastDeviceInfo(port);
    });
  }

  void _broadcastDeviceInfo(int port) {
    try {
      final socket = RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.then((sock) {
        final info = jsonEncode({
          'name': serviceName,
          'port': port,
          'version': '1.0.0',
          'type': 'server',
        });
        final data = utf8.encode(info);
        sock.send(data, InternetAddress('255.255.255.255'), 9876);
        sock.close();
      });
    } catch (_) {}
  }

  Future<void> _handleRequest(HttpRequest request, dynamic shop) async {
    _connectedClients++;

    try {
      final path = request.uri.path;

      if (path == '/api/info' && request.method == 'GET') {
        // Return shop info and server status
        final response = jsonEncode({
          'shopName': shop.name,
          'serverVersion': '1.0.0',
          'timestamp': DateTime.now().toIso8601String(),
          'connectedClients': _connectedClients,
        });
        request.response
          ..headers.contentType = ContentType.json
          ..write(response)
          ..close();
      } else if (path == '/api/backup' && request.method == 'GET') {
        // Create and return a full backup
        _emitEvent(SyncEvent(message: 'Client requested backup', type: SyncEventType.syncRequested));
        final backupFile = await BackupService.instance.createBackup(
          sections: ['invoices', 'products', 'customers', 'categories'],
        );
        final bytes = await backupFile.readAsBytes();
        request.response
          ..headers.contentType = ContentType('application', 'octet-stream')
          ..headers.contentLength = bytes.length
          ..add(bytes)
          ..close();
      } else if (path == '/api/sync' && request.method == 'POST') {
        // Receive sync data from client
        final content = await utf8.decoder.bind(request).join();
        final data = jsonDecode(content);

        _emitEvent(SyncEvent(message: 'Receiving sync data...', type: SyncEventType.syncing));

        // Process the sync data
        final result = await _processIncomingSync(data);

        final response = jsonEncode({
          'success': true,
          'result': result,
        });
        request.response
          ..headers.contentType = ContentType.json
          ..write(response)
          ..close();
      } else {
        request.response
          ..statusCode = HttpStatus.notFound
          ..close();
      }
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Error handling request: $e', type: SyncEventType.error));
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..close();
    } finally {
      _connectedClients--;
    }
  }

  Future<Map<String, int>> _processIncomingSync(Map<String, dynamic> data) async {
    int invoicesAdded = 0, productsUpdated = 0, customersAdded = 0;

    // Process invoices
    if (data['invoices'] != null) {
      for (final inv in data['invoices']) {
        // Insert invoice with items
        final db = await DatabaseService.instance.database;
        final existing = await db.query('invoices',
            where: 'invoiceNumber = ?', whereArgs: [inv['invoiceNumber']]);
        if (existing.isEmpty) {
          await db.insert('invoices', Map<String, dynamic>.from(inv));
          invoicesAdded++;
        }
      }
    }

    // Process product stock updates
    if (data['products'] != null) {
      for (final prod in data['products']) {
        if (prod['id'] != null) {
          await DatabaseService.instance.updateProductStock(prod['id'], prod['stockChange'] ?? 0);
          productsUpdated++;
        }
      }
    }

    return {
      'invoicesAdded': invoicesAdded,
      'productsUpdated': productsUpdated,
      'customersAdded': customersAdded,
    };
  }

  // ==================== CLIENT ====================

  /// Start listening for servers on the local network
  void startDiscovery() {
    _discoveredDevices.clear();
    _devicesController.add([]);

    // Listen for UDP broadcasts from servers
    _listenForBroadcasts();
  }

  void _listenForBroadcasts() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9876);
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram != null) {
            try {
              final info = jsonDecode(utf8.decode(datagram.data));
              if (info['type'] == 'server') {
                final device = DiscoveredDevice(
                  name: info['name'] ?? 'Unknown',
                  address: datagram.address.address,
                  port: info['port'] ?? 0,
                );

                // Add if not already discovered
                if (!_discoveredDevices.any((d) => d.address == device.address && d.port == device.port)) {
                  _discoveredDevices.add(device);
                  _devicesController.add(List.from(_discoveredDevices));
                  _emitEvent(SyncEvent(
                    message: 'Found device: ${device.name}',
                    type: SyncEventType.deviceFound,
                  ));
                }
              }
            } catch (_) {}
          }
        }
      });
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Discovery error: $e', type: SyncEventType.error));
    }
  }

  /// Stop discovery
  void stopDiscovery() {
    _discoveredDevices.clear();
    _devicesController.add([]);
  }

  /// Connect to a discovered server and pull backup
  Future<bool> pullFromServer(DiscoveredDevice device) async {
    try {
      _emitEvent(SyncEvent(message: 'Connecting to ${device.name}...', type: SyncEventType.connecting));

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(Uri.parse('http://${device.address}:${device.port}/api/backup'));
      final response = await request.close();

      if (response.statusCode == 200) {
        _emitEvent(SyncEvent(message: 'Downloading backup...', type: SyncEventType.syncing));

        // Save the backup file
        final tempDir = await getTemporaryDirectory();
        final backupFile = File('${tempDir.path}/sync_backup_${DateTime.now().millisecondsSinceEpoch}.abp');
        await response.pipe(backupFile.openWrite());

        _emitEvent(SyncEvent(message: 'Backup received! Processing...', type: SyncEventType.syncing));

        // Extract and process the backup
        final result = await BackupService.instance.extractBackup(backupFile.path);
        final diff = await BackupService.instance.computeDiff(incomingDbPath: result.dbPath);

        if (!diff.isEmpty) {
          final mergeResult = await BackupService.instance.executeMerge(
            incomingDbPath: result.dbPath,
            diff: diff,
            mergeInvoices: true,
            mergeProducts: true,
            mergeCustomers: true,
            mergeCategories: true,
            updatePrices: false,
            updateStock: true,
          );

          // Cleanup
          await BackupService.instance.cleanupStaging(result.dbPath);
          await backupFile.delete();

          _emitEvent(SyncEvent(
            message: 'Sync complete: ${mergeResult.invoicesAdded} invoices, ${mergeResult.productsAdded} products',
            type: SyncEventType.syncComplete,
          ));
          return true;
        } else {
          _emitEvent(SyncEvent(message: 'No changes to sync', type: SyncEventType.syncComplete));
          await BackupService.instance.cleanupStaging(result.dbPath);
          await backupFile.delete();
          return true;
        }
      }

      _emitEvent(SyncEvent(message: 'Failed to download backup', type: SyncEventType.error));
      return false;
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Sync error: $e', type: SyncEventType.error));
      return false;
    }
  }

  /// Push local changes to a server
  Future<bool> pushToServer(DiscoveredDevice device) async {
    try {
      _emitEvent(SyncEvent(message: 'Preparing local data...', type: SyncEventType.syncing));

      // Create a backup of local data
      final backupFile = await BackupService.instance.createBackup(
        sections: ['invoices', 'products', 'customers', 'categories'],
      );

      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.putUrl(Uri.parse('http://${device.address}:${device.port}/api/sync'));

      // Send the backup data
      final bytes = await backupFile.readAsBytes();
      request.headers.contentType = ContentType('application', 'octet-stream');
      request.contentLength = bytes.length;
      request.add(bytes);

      final response = await request.close();

      if (response.statusCode == 200) {
        _emitEvent(SyncEvent(message: 'Data pushed successfully', type: SyncEventType.syncComplete));
        await backupFile.delete();
        return true;
      }

      _emitEvent(SyncEvent(message: 'Push failed: ${response.statusCode}', type: SyncEventType.error));
      await backupFile.delete();
      return false;
    } catch (e) {
      _emitEvent(SyncEvent(message: 'Push error: $e', type: SyncEventType.error));
      return false;
    }
  }

  void _emitEvent(SyncEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  void dispose() {
    stopServer();
    stopDiscovery();
    _broadcastTimer?.cancel();
    _devicesController.close();
    _eventsController.close();
  }
}

/// Represents a discovered device on the network
class DiscoveredDevice {
  final String name;
  final String address;
  final int port;

  const DiscoveredDevice({
    required this.name,
    required this.address,
    required this.port,
  });

  @override
  String toString() => '$name ($address:$port)';
}

/// Sync event for UI updates
class SyncEvent {
  final String message;
  final SyncEventType type;

  const SyncEvent({required this.message, required this.type});
}

enum SyncEventType {
  serverStarted,
  serverStopped,
  deviceFound,
  connecting,
  syncing,
  syncComplete,
  syncRequested,
  error,
}
