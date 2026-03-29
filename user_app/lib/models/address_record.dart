class AddressRecord {
  const AddressRecord({
    required this.id,
    required this.fullname,
    required this.mobile,
    required this.city,
    required this.pincode,
    required this.street,
    required this.landmark,
    required this.addressType,
    required this.createdAt,
  });

  final String id;
  final String fullname;
  final String mobile;
  final String city;
  final String pincode;
  final String street;
  final String landmark;
  final String addressType;
  final String createdAt;

  factory AddressRecord.fromMap(String id, Map<String, dynamic> map) {
    return AddressRecord(
      id: id,
      fullname: (map["fullname"] ?? "").toString().trim(),
      mobile: (map["mobile"] ?? "").toString().trim(),
      city: (map["city"] ?? "").toString().trim(),
      pincode: (map["pincode"] ?? "").toString().trim(),
      street: (map["street"] ?? "").toString().trim(),
      landmark: (map["landmark"] ?? "").toString().trim(),
      addressType: (map["address_type"] ?? "Home").toString().trim(),
      createdAt: (map["created_at"] ?? "").toString().trim(),
    );
  }

  Map<String, dynamic> toMap(String userEmail) {
    return {
      "user": userEmail.toLowerCase(),
      "fullname": fullname.trim(),
      "mobile": mobile.trim(),
      "city": city.trim(),
      "pincode": pincode.trim(),
      "street": street.trim(),
      "landmark": landmark.trim(),
      "address_type": addressType.trim().isEmpty ? "Home" : addressType.trim(),
      "created_at": createdAt,
    };
  }

  String toSingleLine() {
    final parts = <String>[
      fullname,
      street,
      if (landmark.isNotEmpty) landmark,
      city,
      pincode,
      mobile,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(", ");
  }
}
