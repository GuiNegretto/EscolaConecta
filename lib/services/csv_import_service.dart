import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/models.dart';

class CsvImportException implements Exception {
  final String message;
  const CsvImportException(this.message);

  @override
  String toString() => message;
}

class CsvImportService {
  static final CsvImportService _instance = CsvImportService._internal();

  factory CsvImportService() => _instance;

  CsvImportService._internal();

  /// Valida arquivo CSV local
  Future<List<CsvRow>> validateCsvFile(String filePath) async {
    try {
      final file = File(filePath);

      // Validar existência
      if (!await file.exists()) {
        throw CsvImportException('Arquivo não encontrado');
      }

      // Validar tamanho (máx 10MB)
      final size = await file.length();
      if (size > 10 * 1024 * 1024) {
        throw CsvImportException('Arquivo muito grande (máx 10MB)');
      }

      // Ler conteúdo
      String content;
      try {
        content = await file.readAsString(encoding: utf8);
      } catch (e) {
        try {
          content = await file.readAsString(encoding: latin1);
        } catch (e2) {
          throw CsvImportException('Erro ao ler arquivo: encoding não suportado');
        }
      }

      if (content.isEmpty) {
        throw CsvImportException('Arquivo CSV vazio');
      }

      // Fazer parse do CSV
      final rows = _parseCsv(content);

      if (rows.isEmpty) {
        throw CsvImportException('Arquivo CSV não contém dados válidos');
      }

      // Validar cabeçalhos
      final headerRow = rows.first;
      _validateHeaders(headerRow);

      // Remover cabeçalho e processar dados
      final dataRows = rows.sublist(1);
      if (dataRows.isEmpty) {
        throw CsvImportException('Arquivo CSV sem dados (apenas cabeçalho)');
      }

      // Converter em CsvRow com validação
      final csvRows = <CsvRow>[];
      for (int i = 0; i < dataRows.length; i++) {
        final row = CsvRow.fromCsvLine(dataRows[i], i + 2); // +2: header é linha 1, dados começam em 2
        csvRows.add(row);
      }

      return csvRows;
    } catch (e) {
      if (e is CsvImportException) rethrow;
      throw CsvImportException('Erro ao validar CSV: $e');
    }
  }

  /// Parse CSV com suporte a quoted fields e diferentes delimitadores
  List<List<String>> _parseCsv(String content) {
    final lines = content.split('\n');
    final rows = <List<String>>[];

    for (final line in lines) {
      if (line.trim().isEmpty) continue;

      final fields = _parseCsvLine(line);
      if (fields.isNotEmpty) {
        rows.add(fields);
      }
    }

    return rows;
  }

  /// Parse uma linha CSV
  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    String currentField = '';
    bool insideQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        // Verificar escape
        if (i + 1 < line.length && line[i + 1] == '"') {
          currentField += '"';
          i++; // Skip próximo quote
        } else {
          insideQuotes = !insideQuotes;
        }
      } else if (char == ',' && !insideQuotes) {
        fields.add(currentField.trim());
        currentField = '';
      } else {
        currentField += char;
      }
    }

    // Adicionar último field
    fields.add(currentField.trim());

    return fields;
  }

  /// Validar cabeçalhos do CSV
  void _validateHeaders(List<String> headers) {
    const requiredHeaders = [
      'student_name',
      'grade',
      'class',
      'guardian_name',
      'guardian_email',
      'guardian_phone',
    ];

    final headersLower = headers.map((h) => h.toLowerCase()).toList();

    for (final required in requiredHeaders) {
      if (!headersLower.contains(required)) {
        throw CsvImportException('Cabeçalho obrigatório não encontrado: "$required"');
      }
    }
  }

  /// Gerar preview das colunas encontradas
  Map<String, int> getColumnMapping(List<String> headers) {
    final mapping = <String, int>{};
    final headersLower = headers.map((h) => h.toLowerCase()).toList();

    mapping['student_name'] = headersLower.indexWhere((h) => h.contains('student') && h.contains('name'));
    mapping['grade'] = headersLower.indexWhere((h) => h.contains('grade') || h.contains('série'));
    mapping['class'] = headersLower.indexWhere((h) => h.contains('class') || h.contains('turma'));
    mapping['guardian_name'] = headersLower.indexWhere((h) => h.contains('guardian') || h.contains('responsável'));
    mapping['guardian_email'] =
        headersLower.indexWhere((h) => h.contains('email') && (h.contains('guardian') || h.contains('responsável')));
    mapping['guardian_phone'] =
        headersLower.indexWhere((h) => h.contains('phone') && (h.contains('guardian') || h.contains('responsável')));

    return mapping;
  }

  /// Validar arquivo antes do upload (sem usar compute para permitir acesso ao contexto)
  Future<({
    bool isValid,
    String? error,
    int rowCount,
    List<CsvRow> validRows,
    List<CsvRow> invalidRows,
  })> prevalidateFile(String filePath) async {
    try {
      final rows = await validateCsvFile(filePath);

      final validRows = rows.where((r) => r.isValid).toList();
      final invalidRows = rows.where((r) => !r.isValid).toList();

      return (
        isValid: invalidRows.isEmpty,
        error: invalidRows.isEmpty ? null : 'Encontrados ${invalidRows.length} erros de validação',
        rowCount: rows.length,
        validRows: validRows,
        invalidRows: invalidRows,
      );
    } catch (e) {
      return (
        isValid: false,
        error: e.toString(),
        rowCount: 0,
        validRows: <CsvRow>[],
        invalidRows: <CsvRow>[],
      );
    }
  }

  /// Validar arquivo a partir de bytes (para Flutter Web)
  Future<({
    bool isValid,
    String? error,
    int rowCount,
    List<CsvRow> validRows,
    List<CsvRow> invalidRows,
  })> prevalidateFileFromBytes(Uint8List bytes) async {
    try {
      print('[CSV-Service] Validando bytes: ${bytes.length} bytes');
      
      // Validar tamanho (máx 10MB)
      if (bytes.length > 10 * 1024 * 1024) {
        throw CsvImportException('Arquivo muito grande (máx 10MB)');
      }

      // Decodificar bytes
      String content;
      try {
        content = utf8.decode(bytes);
        print('[CSV-Service] Decodificado com UTF-8');
      } catch (e) {
        try {
          content = latin1.decode(bytes);
          print('[CSV-Service] Decodificado com Latin-1');
        } catch (e2) {
          throw CsvImportException('Erro ao decodificar arquivo: encoding não suportado');
        }
      }

      if (content.isEmpty) {
        throw CsvImportException('Arquivo CSV vazio');
      }

      // Fazer parse do CSV
      final rows = _parseCsv(content);

      if (rows.isEmpty) {
        throw CsvImportException('Arquivo CSV não contém dados válidos');
      }

      // Validar cabeçalhos
      final headerRow = rows.first;
      _validateHeaders(headerRow);

      // Remover cabeçalho e processar dados
      final dataRows = rows.sublist(1);
      if (dataRows.isEmpty) {
        throw CsvImportException('Arquivo CSV sem dados (apenas cabeçalho)');
      }

      // Converter em CsvRow com validação
      final csvRows = <CsvRow>[];
      for (int i = 0; i < dataRows.length; i++) {
        final row = CsvRow.fromCsvLine(dataRows[i], i + 2);
        csvRows.add(row);
      }

      final validRows = csvRows.where((r) => r.isValid).toList();
      final invalidRows = csvRows.where((r) => !r.isValid).toList();

      print('[CSV-Service] Validação concluída: ${validRows.length} válidas, ${invalidRows.length} inválidas');

      return (
        isValid: invalidRows.isEmpty,
        error: invalidRows.isEmpty ? null : 'Encontrados ${invalidRows.length} erros de validação',
        rowCount: csvRows.length,
        validRows: validRows,
        invalidRows: invalidRows,
      );
    } catch (e) {
      print('[CSV-Service] Erro ao validar bytes: $e');
      return (
        isValid: false,
        error: e.toString(),
        rowCount: 0,
        validRows: <CsvRow>[],
        invalidRows: <CsvRow>[],
      );
    }
  }
}
