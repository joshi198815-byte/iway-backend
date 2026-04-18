import 'traveler_type.dart';

class UserModel {
  final String id;
  final String nombre;
  final String email;
  final String telefono;
  final String pais;
  final String estado;
  final String direccion;
  final String tipo;
  final TravelerType? travelerType;
  final String? documento;
  final String? selfiePath;
  final List<String>? rutas;
  final bool verificado;
  final bool bloqueado;
  final bool telefonoVerificado;
  final bool emailVerificado;

  UserModel({
    required this.id,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.pais,
    required this.estado,
    required this.direccion,
    required this.tipo,
    this.travelerType,
    this.documento,
    this.selfiePath,
    this.rutas,
    this.verificado = false,
    this.bloqueado = false,
    this.telefonoVerificado = false,
    this.emailVerificado = false,
  });

  factory UserModel.fromBackendJson(Map<String, dynamic> json) {
    final travelerProfile = json['travelerProfile'];
    final status = (json['status'] ?? '').toString();
    final stateRegion = (json['stateRegion'] ?? json['estado'] ?? '').toString();
    final derivedRoutes = stateRegion
        .split(RegExp(r'[,\n|/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return UserModel(
      id: (json['id'] ?? '').toString(),
      nombre: (json['fullName'] ?? json['nombre'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telefono: (json['phone'] ?? json['telefono'] ?? '').toString(),
      pais: (json['detectedCountryCode'] ?? json['countryCode'] ?? '').toString(),
      estado: stateRegion,
      direccion: (json['address'] ?? json['direccion'] ?? '').toString(),
      tipo: (json['role'] ?? json['tipo'] ?? '').toString(),
      travelerType: travelerProfile is Map<String, dynamic>
          ? TravelerTypeExtension.fromApiValue(
              travelerProfile['travelerType']?.toString(),
            )
          : null,
      documento: travelerProfile is Map<String, dynamic>
          ? travelerProfile['documentNumber']?.toString()
          : json['documento']?.toString(),
      selfiePath: travelerProfile is Map<String, dynamic>
          ? travelerProfile['selfieUrl']?.toString()
          : json['selfiePath']?.toString(),
      rutas: derivedRoutes.isNotEmpty
          ? derivedRoutes
          : travelerProfile is Map<String, dynamic>
              ? ((travelerProfile['allowedRoutes'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [])
              : (json['rutas'] as List?)?.map((e) => e.toString()).toList(),
      verificado: status == 'active' ||
          (travelerProfile is Map<String, dynamic> &&
              travelerProfile['status'] == 'verified'),
      bloqueado: status == 'blocked' ||
          (travelerProfile is Map<String, dynamic> &&
              travelerProfile['status'] == 'blocked_for_debt'),
      telefonoVerificado: json['phoneVerified'] == true,
      emailVerificado: json['emailVerified'] == true,
    );
  }

  factory UserModel.fromStorageJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      telefono: (json['telefono'] ?? '').toString(),
      pais: (json['pais'] ?? '').toString(),
      estado: (json['estado'] ?? '').toString(),
      direccion: (json['direccion'] ?? '').toString(),
      tipo: (json['tipo'] ?? '').toString(),
      travelerType: TravelerTypeExtension.fromApiValue(
        json['travelerType']?.toString(),
      ),
      documento: json['documento']?.toString(),
      selfiePath: json['selfiePath']?.toString(),
      rutas: (json['rutas'] as List?)?.map((e) => e.toString()).toList(),
      verificado: json['verificado'] == true,
      bloqueado: json['bloqueado'] == true,
      telefonoVerificado: json['telefonoVerificado'] == true,
      emailVerificado: json['emailVerificado'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'pais': pais,
      'estado': estado,
      'direccion': direccion,
      'tipo': tipo,
      'travelerType': travelerType?.apiValue,
      'documento': documento,
      'selfiePath': selfiePath,
      'rutas': rutas,
      'verificado': verificado,
      'bloqueado': bloqueado,
      'telefonoVerificado': telefonoVerificado,
      'emailVerificado': emailVerificado,
    };
  }
}
