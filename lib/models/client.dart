class Client {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? idDocument;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.idDocument,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ---------------------------------------------------------------------------
  // Serialisation
  // ---------------------------------------------------------------------------

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      idDocument: json['id_document'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'id_document': idDocument,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // copyWith
  // ---------------------------------------------------------------------------

  Client copyWith({
    String? id,
    String? fullName,
    Object? phone = _unset,
    Object? email = _unset,
    Object? idDocument = _unset,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Client(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone == _unset ? this.phone : phone as String?,
      email: email == _unset ? this.email : email as String?,
      idDocument: idDocument == _unset ? this.idDocument : idDocument as String?,
      notes: notes == _unset ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Overrides
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Client(id: $id, fullName: $fullName, email: $email)';
}

// Sentinel object for nullable copyWith fields.
const Object _unset = Object();
