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
      home: RestWidget(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
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

  @override
  void initState() {
    super.initState();
    _getUFS();
  }

  Future<void> _getUFS() async {
    final url = Uri.parse('https://brasilapi.com.br/api/ibge/uf/v1');
    final resposta = await  http.get(url);
    if (resposta.statusCode != 200) return;
    final dados = jsonDecode(resposta.body) as List<dynamic>;
    final lista = dados.map((elem) => elem['sigla'] as String).toList();
    lista.sort();
    setState(() {  
      ufList.addAll(lista);
    });
  }

  Future<void> buscarFeriados() async {
    if (estaProcessando) return;
    
    setState(() {
      estaProcessando = true;
      mensagemErro = null;
      feriados = [];
    });

    final ano = controladorAno.text;
    String url = 'https://brasilapi.com.br/api/feriados/v1/$ano';
    if (uf != null) url += '?uf=$uf';

    final uri = Uri.parse(url);
    try {
      final resposta = await http.get(uri);
      final bodyRes = jsonDecode(resposta.body);
      if (resposta.statusCode == 200) {
        final decodedList = (bodyRes as List).cast<Map<String, dynamic>>();
        setState(() {
          feriados.clear();
          feriados.addAll(decodedList.map((elem) => Feriado.fromJson(elem)));
        });
        return;
      }

      setState(() {
        mensagemErro = (bodyRes as Map<String, dynamic>)['message'] as String;
      });

    } catch(erro) {
      setState(() {
        mensagemErro = 'Não foi capaz de conectar na internet. Verifique sua internet';
      });
    } finally {
      setState(() {
        estaProcessando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: .max,
          children: [Text('Consulta Feriado', textAlign: .center, style: TextStyle(fontWeight: .bold),)],
        )),
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: controladorAno,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(label: Text('Digite o ano')),
              ),
              const SizedBox(height: 8),
              if (ufList.isNotEmpty) DropdownButton(
                  value: uf,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('')),
                    ...ufList.map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(value: value, child: Text(value));
                    })],
                  icon: const Icon(Icons.arrow_downward_rounded),
                  onChanged: (value) => setState(() {
                    uf = value;
                  })
                ),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: buscarFeriados, child: const Text('Buscar Feriados')),
                if (estaProcessando) ...[
                  const SizedBox(height: 26),
                  const CircularProgressIndicator(),
                ],
                if (mensagemErro != null) ...[
                  const SizedBox(height: 16),
                  Text(mensagemErro!, style: const TextStyle(color: Colors.red)),
                  ],
                const SizedBox(height: 16),
                Expanded(child:
                  GridView.builder(
                    itemCount: feriados.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final feriado = feriados[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Icon(Icons.calendar_month, size: 40,),
                                const SizedBox(height: 4.0),
                                Text(
                                  feriado.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                                ),
                                const SizedBox(height: 2.75),
                                Text('Data: ${feriado.date.day}/${feriado.date.month}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
                                if (feriado.weekday != null) Text('Dia da semana: ${feriado.weekday}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20)),
                                Text('Tipo: ${feriado.type}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 20))
                              ],
                            ),
                          ),
                        );  
                      },
                  ) 
                ),
            ],
          ),
        ),
    );
  }
  
}