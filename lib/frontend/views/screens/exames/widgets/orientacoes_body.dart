import 'package:flutter/material.dart';

class OrientacoesBody extends StatelessWidget {
  const OrientacoesBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Bullet('A imagem da requisição deve ser completa e sem cortes.'),
        _Bullet('Se houver exames para locais diferentes, emita autorizações separadas.'),
        _Bullet('Tamanho máximo da imagem 10MB (quando aplicável).'),
        _Bullet('Após a solicitação, o retorno pode levar até 48 horas.'),
        _Bullet('Você pode consultar suas solicitações no histórico do app.'),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  ', style: TextStyle(height: 1.4)),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
