class Invoice {
  final int? id;
  final String invoiceNumber;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final DateTime date;
  final double totalAmount;
  final double tvaAmount;
  final double discount;
  final String paymentMethod;
  final bool isPaid;
  final double paidAmount;

  const Invoice({
    this.id,
    required this.invoiceNumber,
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    required this.date,
    required this.totalAmount,
    this.tvaAmount = 0.0,
    this.discount = 0.0,
    this.paymentMethod = 'cash',
    this.isPaid = true,
    this.paidAmount = 0.0,
  });

  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => paidAmount >= totalAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'date': date.toIso8601String(),
      'totalAmount': totalAmount,
      'tvaAmount': tvaAmount,
      'discount': discount,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid ? 1 : 0,
      'paidAmount': paidAmount,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoiceNumber'] as String,
      customerId: map['customerId'] as int?,
      customerName: map['customerName'] as String? ?? '',
      customerPhone: map['customerPhone'] as String? ?? '',
      date: DateTime.parse(map['date'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      tvaAmount: (map['tvaAmount'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? 'cash',
      isPaid: (map['isPaid'] as int?) == 1,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class InvoiceItem {
  final int? id;
  final int invoiceId;
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double tvaRate;

  const InvoiceItem({
    this.id,
    this.invoiceId = 0,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.tvaRate = 0.0,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'productId': productId,
      'productName': productName,
      'price': price,
      'quantity': quantity,
      'tvaRate': tvaRate,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      id: map['id'] as int?,
      invoiceId: map['invoiceId'] as int,
      productId: map['productId'] as int,
      productName: map['productName'] as String,
      price: (map['price'] as num).toDouble(),
      quantity: map['quantity'] as int,
      tvaRate: (map['tvaRate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
