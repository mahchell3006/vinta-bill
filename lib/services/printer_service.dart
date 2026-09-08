import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:intl/intl.dart';
import '../models/cart_item.dart';

class PrinterService {
  // Singleton
  static final PrinterService instance = PrinterService._();
  PrinterService._();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  // ESC/POS Commands
  static const List<int> _initBytes = [0x1B, 0x40];
  static const List<int> _alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> _alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> _alignRight = [0x1B, 0x61, 0x02];
  static const List<int> _boldOn = [0x1B, 0x45, 0x01];
  static const List<int> _boldOff = [0x1B, 0x45, 0x00];
  static const List<int> _textNormal = [0x1D, 0x21, 0x00];
  static const List<int> _textLarge = [0x1D, 0x21, 0x11];
  static const List<int> _lineFeed = [0x0A];
  static const List<int> _cutPaper = [0x1D, 0x56, 0x00];

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      return await PrintBluetoothThermal.pairedBluetooths;
    } catch (e) {
      return [];
    }
  }

  Future<void> scanAndConnect() async {
    final devices = await getBondedDevices();
    if (devices.isEmpty) {
      throw Exception('No paired Bluetooth devices found. Please pair a printer in your phone settings first.');
    }

    bool connected = false;
    for (var device in devices) {
      try {
        final result = await PrintBluetoothThermal.connect(
          macPrinterAddress: device.macAdress,
        );
        if (result) {
          _isConnected = true;
          connected = true;
          break;
        }
      } catch (e) {
        continue;
      }
    }

    if (!connected) {
      throw Exception('Could not connect to any paired device.');
    }
  }

  Future<void> connect(String macAddress) async {
    final result = await PrintBluetoothThermal.connect(
      macPrinterAddress: macAddress,
    );
    _isConnected = result;
    if (!result) {
      throw Exception('Failed to connect to printer');
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      _isConnected = false;
    } catch (e) {
      // ignore
    }
  }

  Future<void> printReceipt(List<CartItem> cart, dynamic cartNotifier,
      {String? customerName, String paymentMethod = 'cash'}) async {
    if (!_isConnected) {
      // Try to reconnect
      try {
        await scanAndConnect();
      } catch (e) {
        throw Exception('Printer not connected. Please connect first.');
      }
    }

    // Check connection status
    final connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (!connectionStatus) {
      _isConnected = false;
      throw Exception('Printer connection lost.');
    }

    List<int> bytes = [];

    // Initialize printer
    bytes += _initBytes;

    // Shop Name (Center, Bold, Large)
    bytes += _alignCenter;
    bytes += _boldOn;
    bytes += _textLarge;
    bytes += _textToBytes('FOUERAGE ALGERIE');
    bytes += _lineFeed;

    // Address & Phone (Normal, Center)
    bytes += _textNormal;
    bytes += _boldOff;
    bytes += _textToBytes('--------------------------------');
    bytes += _lineFeed;

    // Customer name (if credit)
    if (customerName != null && customerName.isNotEmpty) {
      bytes += _alignCenter;
      bytes += _boldOn;
      bytes += _textToBytes('CLIENT: $customerName');
      bytes += _boldOff;
      bytes += _lineFeed;
      bytes += _textToBytes('--------------------------------');
      bytes += _lineFeed;
    }

    // Date and Time
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    bytes += _alignCenter;
    bytes += _textToBytes(formattedDate);
    bytes += _lineFeed;

    bytes += _textToBytes('================================');
    bytes += _lineFeed;

    // Items Header (Align Left)
    bytes += _alignLeft;
    bytes += _textToBytes('Article        Qte   Total');
    bytes += _lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += _lineFeed;

    // Items
    for (var item in cart) {
      String name = item.product.name;
      if (name.length > 14) name = name.substring(0, 14);

      String qty = '${item.quantity}';
      String total = '${item.subtotal.toStringAsFixed(0)} DA';

      String line = name.padRight(14) + qty.padLeft(4) + '  ' + total.padLeft(8);
      bytes += _textToBytes(line);
      bytes += _lineFeed;
    }

    bytes += _textToBytes('--------------------------------');
    bytes += _lineFeed;

    // Calculate totals
    double totalAmount = cart.fold(0, (sum, item) => sum + item.subtotal);
    double totalTva = cart.fold(0, (sum, item) => sum + item.tvaAmount);
    double grandTotal = totalAmount + totalTva;

    // TVA
    bytes += _alignRight;
    bytes += _textToBytes('TVA:     ${totalTva.toStringAsFixed(0)} DA');
    bytes += _lineFeed;

    // Total (Bold)
    bytes += _boldOn;
    bytes += _textLarge;
    bytes += _textToBytes('TOTAL:   ${grandTotal.toStringAsFixed(0)} DA');
    bytes += _lineFeed;
    bytes += _boldOff;
    bytes += _textNormal;

    bytes += _textToBytes('================================');
    bytes += _lineFeed;

    // Payment method
    bytes += _alignCenter;
    String paymentLabel = paymentMethod.toUpperCase();
    if (paymentMethod == 'cash') paymentLabel = 'ESPÈCES';
    if (paymentMethod == 'card') paymentLabel = 'CARTE';
    if (paymentMethod == 'credit') paymentLabel = 'CRÉDIT';
    bytes += _textToBytes('PAIEMENT: $paymentLabel');
    bytes += _lineFeed;

    // Footer
    bytes += _lineFeed;
    bytes += _textToBytes('MERCI DE VOTRE VISITE !');
    bytes += _lineFeed;
    bytes += _lineFeed;
    bytes += _lineFeed;

    // Cut paper
    bytes += _cutPaper;

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  List<int> _textToBytes(String text) {
    return List.from(text.codeUnits);
  }
}
