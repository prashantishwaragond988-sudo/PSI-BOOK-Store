class Address {
  final String id;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String pincode;

  Address({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
      };
}
