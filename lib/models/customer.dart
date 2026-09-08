class Customer {
  final int? id;
  final String name;
  final String phoneNumber;
  final String email;
  final String address;
  final String nif;
  final String rc;

  const Customer({
    this.id,
    required this.name,
    this.phoneNumber = '',
    this.email = '',
    this.address = '',
    this.nif = '',
    this.rc = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'address': address,
      'nif': nif,
      'rc': rc,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as int?,
      name: map['name'] as String,
      phoneNumber: map['phoneNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      address: map['address'] as String? ?? '',
      nif: map['nif'] as String? ?? '',
      rc: map['rc'] as String? ?? '',
    );
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? address,
    String? nif,
    String? rc,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      nif: nif ?? this.nif,
      rc: rc ?? this.rc,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
