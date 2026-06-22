/// Modelo de dados para seleção de destinatários de mensagens
/// Suporta três tipos de envio: geral, turmas e individual

enum TipoEnvio { geral, turmas, individual }

class MensagemDestinatario {
  final TipoEnvio tipo;
  final List<String> turmaIds; // preenchido se tipo == turmas
  final bool notificarResponsaveis; // relevante para turmas
  final List<String> alunoIds; // preenchido se tipo == individual
  final List<String> responsavelIds; // ids dos responsáveis selecionados manualmente

  const MensagemDestinatario({
    required this.tipo,
    this.turmaIds = const [],
    this.notificarResponsaveis = false,
    this.alunoIds = const [],
    this.responsavelIds = const [],
  });

  MensagemDestinatario copyWith({
    TipoEnvio? tipo,
    List<String>? turmaIds,
    bool? notificarResponsaveis,
    List<String>? alunoIds,
    List<String>? responsavelIds,
  }) {
    return MensagemDestinatario(
      tipo: tipo ?? this.tipo,
      turmaIds: turmaIds ?? this.turmaIds,
      notificarResponsaveis: notificarResponsaveis ?? this.notificarResponsaveis,
      alunoIds: alunoIds ?? this.alunoIds,
      responsavelIds: responsavelIds ?? this.responsavelIds,
    );
  }

  /// Valida se o destinatário tem informações suficientes para envio
  bool get isValid {
    switch (tipo) {
      case TipoEnvio.geral:
        return true; // sempre válido
      case TipoEnvio.turmas:
        return turmaIds.isNotEmpty;
      case TipoEnvio.individual:
        return alunoIds.isNotEmpty;
    }
  }

  /// Retorna uma descrição textual do destinatário
  String get descricao {
    switch (tipo) {
      case TipoEnvio.geral:
        return 'Todos os usuários';
      case TipoEnvio.turmas:
        if (turmaIds.isEmpty) return 'Nenhuma turma selecionada';
        final turmas = turmaIds.length == 1 ? '1 turma' : '${turmaIds.length} turmas';
        final resp = notificarResponsaveis ? ' + responsáveis' : '';
        return '$turmas$resp';
      case TipoEnvio.individual:
        if (alunoIds.isEmpty) return 'Nenhum aluno selecionado';
        final alunos = alunoIds.length == 1 ? '1 aluno' : '${alunoIds.length} alunos';
        final resp = responsavelIds.isNotEmpty ? ' + ${responsavelIds.length} responsável(is)' : '';
        return '$alunos$resp';
    }
  }
}
