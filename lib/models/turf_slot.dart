class TurfSlot {
  final String time;
  bool isAvailable;
  final int price;
  String? bookedBy;

  TurfSlot({
    required this.time,
    required this.isAvailable,
    required this.price,
    this.bookedBy,
  });

  factory TurfSlot.fromMap(String time, Map<String, dynamic> map) {
    return TurfSlot(
      time: time,
      isAvailable: map['available'] ?? true,
      price: map['price'] ?? 0,
      bookedBy: map['bookedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'available': isAvailable,
      'price': price,
      'bookedBy': bookedBy,
    };
  }
}
