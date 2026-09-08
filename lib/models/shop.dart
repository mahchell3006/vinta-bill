class Shop {
  final int? id;
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String nif;
  final String rc;
  final String footerText;

  const Shop({
    this.id,
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.nif = '',
    this.rc = '',
    this.footerText = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'addressLine1': addressLine1,
      'addressLine2': addressLine2,
      'phoneNumber': phoneNumber,
      'nif': nif,
      'rc': rc,
      'footerText': footerText,
    };
  }

  factory Shop.fromMap(Map<String, dynamic> map) {
    return Shop(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      addressLine1: map['addressLine1'] as String? ?? '',
      addressLine2: map['addressLine2'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      nif: map['nif'] as String? ?? '',
      rc: map['rc'] as String? ?? '',
      footerText: map['footerText'] as String? ?? '',
    );
  }

  Shop copyWith({
    int? id,
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? nif,
    String? rc,
    String? footerText,
  }) {
    return Shop(
      id: id ?? this.id,
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      nif: nif ?? this.nif,
      rc: rc ?? this.rc,
      footerText: footerText ?? this.footerText,
    );
  }
}
