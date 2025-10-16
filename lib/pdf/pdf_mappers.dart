// lib/pdf/pdf_mappers.dart
import '../models/reimpressao.dart';
import '../models/proc_item.dart';
import 'autorizacao_pdf_data.dart';

AutorizacaoPdfData mapDetalheToPdfData({
  required ReimpressaoDetalhe det,
  required String nomeTitular,
  required int idMatricula,
  required AutorizacaoTipo tipo,        // << NOVO: obriga informar o tipo
  String? percentual,
  List<ProcItem> procedimentos = const [],
}) {
  // fallback de procedimentos (igual ao site)
  List<ProcItem> procs = procedimentos;
  if (procs.isEmpty) {
    final esp = (det.nomeEspecialidade).toUpperCase();
    if (esp.contains('ODONTO')) {
      procs = const [
        ProcItem(codigo: '10021', descricao: 'CONSULTA ODONTOLÓGICA', quantidade: 1),
      ];
    } else if (esp == 'PSICOLOGIA') {
      procs = const [
        ProcItem(codigo: '50000470', descricao: 'SESSÃO DE PSICOTERAPIA INDIVIDUAL', quantidade: 1),
      ];
    } else if (esp == 'NUTRICAO' || esp == 'NUTRIÇÃO') {
      procs = const [
        ProcItem(codigo: '50000560', descricao: 'CONSULTA COM NUTRICIONISTA', quantidade: 1),
      ];
    } else if (esp == 'FONOAUDIOLOGIA') {
      procs = const [
        ProcItem(codigo: '50000616', descricao: 'SESSÃO INDIVIDUAL DE FONOAUDIOLOGIA', quantidade: 1),
      ];
    } else if (esp == 'ESTOMATOLOGIA') {
      procs = const [
        ProcItem(codigo: '5080', descricao: 'CONSULTA DE ESTOMATOLOGISTA', quantidade: 1),
      ];
    } else {
      procs = const [
        ProcItem(codigo: '10014', descricao: 'CONSULTA MÉDICA', quantidade: 1),
      ];
    }
  }

  return AutorizacaoPdfData(
    tipo: tipo,                           // << repassa o tipo
    numero: det.numero,
    nomePrestador: det.nomePrestadorExec,
    codPrestador: det.codConselhoExec,
    especialidade: det.nomeEspecialidade,
    endereco: det.enderecoComl,
    bairro: det.bairroComl,
    cidade: det.cidadeComl,
    telefone: det.telefoneComl,
    codigoVinculo: det.codVinculo,
    nomeVinculo: det.nomeVinculo,
    idMatricula: idMatricula,
    nomeTitular: nomeTitular,
    idDependente: det.idDependente,
    nomePaciente: det.nomePaciente,
    idadePaciente: det.idadePaciente,
    dataEmissao: det.dataEmissao,
    codigoEspecialidade: det.codEspecialidade,
    observacoes: det.observacoes,
    primeiraImpressao: false,             // reimpressão → sempre false
    percentual: percentual,
    procedimentos: procs,
  );
}
