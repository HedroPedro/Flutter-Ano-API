import 'dart:convert';

import 'package:ano_app/models.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HomePage());
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Busca feriados',
      home: const RestWidget(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
    );
  }
}

class RestWidget extends StatefulWidget {
  const RestWidget({super.key});

  @override
  State<StatefulWidget> createState() => _RestWidget();
}

class _RestWidget extends State<RestWidget> {
  final TextEditingController controladorAno = TextEditingController();
  List<String> ufList = [];
  List<Feriado> feriados = [];
  bool estaProcessando = false;
  String? mensagemErro;
  String? uf;

  static const double _alturaCampo = 48;

  @override
  void initState() {
    super.initState();
    _getUFS();
  }

  Future<void> _getUFS() async {
    final url = Uri.parse('https://brasilapi.com.br/api/ibge/uf/v1');
    final resposta = await http.get(url);
    if (resposta.statusCode != 200) return;
    final dados = jsonDecode(resposta.body) as List<dynamic>;
    final lista = dados.map((elem) => elem['sigla'] as String).toList();
    lista.sort();
    setState(() {
      ufList.addAll(lista);
    });
  }

  // Data de hoje sem a parte de horas, pra poder comparar só dia/mês/ano.
  DateTime get _hoje {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }

  // Quantidade de dias entre hoje e a data do feriado.
  // Pode ser negativo, caso o feriado já tenha passado.
  int _diasAte(DateTime data) {
    final dataSemHora = DateTime(data.year, data.month, data.day);
    return dataSemHora.difference(_hoje).inDays;
  }

  // Índice do primeiro feriado que ainda vai acontecer (lista já ordenada
  // por data). Retorna null se todos já passaram.
  int? get _indiceProximoFeriado {
    for (var i = 0; i < feriados.length; i++) {
      if (_diasAte(feriados[i].date) >= 0) return i;
    }
    return null;
  }

  Color _corTipo(String tipo) {
    switch (tipo) {
      case 'nacional':
        return Colors.indigo;
      case 'estadual':
        return Colors.orange.shade800;
      case 'regional':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> buscarFeriados() async {
    if (estaProcessando) return;

    final ano = controladorAno.text.trim();
    final anoValido = int.tryParse(ano);
    if (ano.isEmpty || anoValido == null) {
      setState(() {
        mensagemErro = 'Digite um ano para buscar os feriado';
        feriados = [];
      });
      return;
    }

    setState(() {
      estaProcessando = true;
      mensagemErro = null;
      feriados = [];
    });

    String url = 'https://brasilapi.com.br/api/feriados/v1/$ano';
    if (uf != null) url += '?uf=$uf';

    final uri = Uri.parse(url);
    try {
      final resposta = await http.get(uri);
      final bodyRes = jsonDecode(resposta.body);
      if (resposta.statusCode == 200) {
        final decodedList = (bodyRes as List).cast<Map<String, dynamic>>();
        // Mostra TODOS os feriados do ano pesquisado, mesmo de anos
        // passados. A contagem de dias só aparece quando o feriado
        // ainda não passou (ver _diasAte).
        final todos = decodedList.map((elem) => Feriado.fromJson(elem)).toList();
        todos.sort((a, b) => a.date.compareTo(b.date));

        setState(() {
          feriados
            ..clear()
            ..addAll(todos);
          mensagemErro = todos.isEmpty ? 'Nenhum feriado encontrado para o ano informado.' : null;
        });
        return;
      }

      setState(() {
        mensagemErro = (bodyRes as Map<String, dynamic>)['message'] as String;
      });
    } catch (erro) {
      setState(() {
        mensagemErro = 'Não foi capaz de conectar na internet. Verifique sua internet';
      });
    } finally {
      setState(() {
        estaProcessando = false;
      });
    }
  }

  void _abrirPopup(Feriado feriado) {
    final dias = _diasAte(feriado.date);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Text('Dados do feriado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                feriado.fullName ?? feriado.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 6),
                  Text('${feriado.date.day}/${feriado.date.month}/${feriado.date.year}'),
                ],
              ),
              if (feriado.weekday != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_view_week, size: 18),
                    const SizedBox(width: 6),
                    Text(feriado.weekday!),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.label_outline, size: 18),
                  const SizedBox(width: 6),
                  Text('Tipo: ${feriado.type}'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    dias >= 0 ? Icons.hourglass_bottom : Icons.history,
                    size: 18,
                    color: dias >= 0 ? Colors.teal : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dias > 0
                        ? 'Faltam $dias dia${dias == 1 ? '' : 's'}'
                        : dias == 0
                            ? 'É hoje!'
                            : 'Esse feriado já passou',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: dias >= 0 ? Colors.teal.shade700 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('voltar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final proximoIndex = _indiceProximoFeriado;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Consulta Feriado',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Ano, UF e botão ficam centralizados e não esticam a tela toda.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ano',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: _alturaCampo,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.centerLeft,
                                child: TextField(
                                  controller: controladorAno,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Ex: 2026',
                                    isDense: true,
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UF',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: _alturaCampo,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    value: uf,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down),
                                    hint: const Text('Todas'),
                                    items: [
                                      const DropdownMenuItem<String?>(value: null, child: Text('Todas')),
                                      ...ufList.map<DropdownMenuItem<String>>((String value) {
                                        return DropdownMenuItem<String>(value: value, child: Text(value));
                                      }),
                                    ],
                                    onChanged: (value) => setState(() {
                                      uf = value;
                                    }),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        width: 260,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: buscarFeriados,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar Feriados'),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (estaProcessando) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
            if (mensagemErro != null) ...[
              const SizedBox(height: 16),
              Text(
                mensagemErro!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: feriados.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  mainAxisExtent: 165,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final feriado = feriados[index];
                  final ehOProximo = index == proximoIndex;
                  final cor = _corTipo(feriado.type);

                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _abrirPopup(feriado),
                    child: Card(
                      elevation: ehOProximo ? 3 : 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: ehOProximo
                            ? BorderSide(color: Colors.teal.shade400, width: 1.5)
                            : BorderSide.none,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_month, size: 20, color: Colors.blueGrey.shade600),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    feriado.type,
                                    style: TextStyle(fontSize: 10, color: cor, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              feriado.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Row(
                              children: [
                                Icon(Icons.event, size: 14, color: Colors.grey.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  '${feriado.date.day}/${feriado.date.month}/${feriado.date.year}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                            if (ehOProximo)
                              Row(
                                children: [
                                  const Icon(Icons.hourglass_bottom, size: 14, color: Colors.teal),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Faltam ${_diasAte(feriado.date)}d',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.teal,
                                    ),
                                  ),
                                ],
                              )
                            else
                              const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}