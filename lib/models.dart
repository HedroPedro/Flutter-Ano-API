
/// Classe que representa o feriado dentro da requisição
class Feriado {
  final DateTime date;
  final String type;
  final String name;
  final String? weekday;
  final String? fullName;

  Feriado({required this.date, required this.type, required this.name, required this.weekday, this.fullName});

  factory Feriado.fromJson(Map<String, dynamic> json) {
      final Map<String, String> typeMap = {
      'national': 'nacional',
      'state': 'estadual',
      'regional': 'regional', 
      };

    return Feriado(
        date: DateTime.parse(json['date'] as String), 
        type: typeMap[json['type'] as String] ?? 'desconhecido', 
        name: json['name'] as String,
        weekday: json['weekday'] as String?,
        fullName: json['fullName'] as String?
      );
  }
}

