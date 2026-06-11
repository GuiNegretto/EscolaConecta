import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/csv_import_service.dart';
import '../../utils/app_theme.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

enum ImportPhase { selection, validation, uploading, results }

class _AdminImportScreenState extends State<AdminImportScreen> {
  final _api = ApiService();
  final _csvService = CsvImportService();

  // State
  ImportPhase _phase = ImportPhase.selection;
  String? _fileName;
  String? _filePath;
  Uint8List? _fileBytes; // Para Flutter Web compatibilidade
  List<CsvRow>? _csvData;
  List<CsvRow>? _invalidRows;
  ImportResult? _importResult;
  String? _error;

  // Progress
  double _uploadProgress = 0;
  bool _isValidating = false;

  // Get file size - works for both web and mobile
  int get _fileSize {
    if (kIsWeb && _fileBytes != null) {
      return _fileBytes!.length;
    } else if (!kIsWeb && _filePath != null) {
      // For mobile, we can't check file size easily without dart:io
      // We'll estimate based on file name or set to 0
      return 0;
    }
    return 0;
  }

  Future<void> _pickFile() async {
    print('[CSV] ============================================');
    print('[CSV] INICIANDO SELEÇÃO DE ARQUIVO');
    print('[CSV] Plataforma: ${kIsWeb ? "WEB" : "MOBILE"}');
    print('[CSV] ============================================');

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        lockParentWindow: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('[CSV] ✓ Arquivo detectado');
        print('[CSV]   Nome: ${file.name}');
        print('[CSV]   Tamanho: ${file.size} bytes');
        print('[CSV]   Extensão: ${file.extension}');

        // Em Flutter Web, usar bytes; em mobile, usar path
        if (kIsWeb) {
          print('[CSV] Modo WEB - verificando bytes...');

          if (file.bytes != null && file.bytes!.isNotEmpty) {
            print('[CSV]   ✓ Bytes disponíveis: ${file.bytes!.length} bytes');

            setState(() {
              _fileName = file.name;
              _filePath = null; // Não é válido em Web
              _fileBytes = file.bytes;
              _error = null;
              _phase = ImportPhase.selection;
            });

            print('[CSV] ✓ Estado atualizado com sucesso');
            print('[CSV]   _fileName: ${_fileName}');
            print('[CSV]   _fileBytes: ${_fileBytes != null ? "✓ (${_fileBytes!.length} bytes)" : "✗"}');
          } else {
            print('[CSV] ✗ ERRO: Bytes nulos ou vazios!');
            setState(() => _error = 'Erro: Não foi possível carregar o arquivo');
          }
        } else {
          print('[CSV] Modo MOBILE - verificando path...');

          if (file.path != null && file.path!.isNotEmpty) {
            print('[CSV]   ✓ Path disponível: ${file.path}');

            setState(() {
              _fileName = file.name;
              _filePath = file.path;
              _fileBytes = null;
              _error = null;
              _phase = ImportPhase.selection;
            });

            print('[CSV] ✓ Estado atualizado com sucesso');
          } else {
            print('[CSV] ✗ ERRO: Path nulo ou vazio!');
            setState(() => _error = 'Erro: Não foi possível carregar o arquivo');
          }
        }
      } else {
        print('[CSV] Seleção cancelada pelo usuário');
      }
    } catch (e, stackTrace) {
      print('[CSV] ✗ ERRO EXCEPTION: $e');
      print('[CSV] StackTrace: $stackTrace');
      setState(() => _error = 'Erro ao selecionar arquivo: $e');
    }

    print('[CSV] ============================================');
  }

  Future<void> _validateFile() async {
    print('[CSV] ============================================');
    print('[CSV] INICIANDO VALIDAÇÃO');
    print('[CSV] ============================================');

    if (_filePath == null && _fileBytes == null) {
      print('[CSV] ✗ ERRO: Nenhum arquivo foi selecionado');
      return;
    }

    print('[CSV] ✓ Arquivo disponível para validação');
    print('[CSV]   Modo: ${kIsWeb ? "WEB (bytes)" : "MOBILE (path)"}');
    print('[CSV]   Bytes: ${_fileBytes?.length ?? "N/A"}');

    setState(() {
      _isValidating = true;
      _error = null;
      _phase = ImportPhase.validation;
    });

    try {
      print('[CSV] Chamando serviço de validação...');

      final result = kIsWeb
          ? await _csvService.prevalidateFileFromBytes(_fileBytes!)
          : await _csvService.prevalidateFile(_filePath!);

      if (!mounted) {
        print('[CSV] ✗ Widget desmontou durante validação');
        return;
      }

      print('[CSV] ============================================');
      print('[CSV] RESULTADO DA VALIDAÇÃO');
      print('[CSV] ============================================');
      print('[CSV] Válido: ${result.isValid}');
      print('[CSV] Linhas válidas: ${result.validRows.length}');
      print('[CSV] Linhas inválidas: ${result.invalidRows.length}');
      if (result.error != null) {
        print('[CSV] Erro: ${result.error}');
      }

      if (!result.isValid) {
        setState(() {
          _error = result.error;
          _invalidRows = result.invalidRows;
          _isValidating = false;
        });
        print('[CSV] ✗ Validação falhou: ${result.error}');
      } else {
        setState(() {
          _csvData = result.validRows;
          _invalidRows = result.invalidRows;
          _isValidating = false;
        });
        print('[CSV] ✓ Arquivo validado com sucesso!');
        print('[CSV]   ${result.validRows.length} registros prontos para importação');
      }
    } catch (e, stackTrace) {
      print('[CSV] ✗ ERRO EXCEPTION durante validação: $e');
      print('[CSV] StackTrace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao validar: $e';
        _isValidating = false;
      });
    }

    print('[CSV] ============================================');
  }

  Future<void> _uploadCsv() async {
    print('[CSV] ============================================');
    print('[CSV] INICIANDO UPLOAD');
    print('[CSV] ============================================');

    if (_filePath == null && _fileBytes == null) {
      print('[CSV] ✗ ERRO: Arquivo não disponível para upload');
      return;
    }

    if (_csvData == null) {
      print('[CSV] ✗ ERRO: Dados CSV não validados');
      return;
    }

    print('[CSV] ✓ Pré-condições atendidas');
    print('[CSV]   Modo: ${kIsWeb ? "WEB (bytes)" : "MOBILE (path)"}');
    print('[CSV]   Registros validados: ${_csvData!.length}');

    setState(() {
      _uploadProgress = 0;
      _phase = ImportPhase.uploading;
      _error = null;
    });

    try {
      print('[CSV] Chamando API para upload...');

      _uploadProgress = 0.3;
      if (mounted) setState(() {});

      final result = kIsWeb
          ? await _api.importStudentsFromCsvBytes(_fileBytes!)
          : await _api.importStudentsFromCsv(_filePath!);

      print('[CSV] ============================================');
      print('[CSV] RESULTADO DO UPLOAD');
      print('[CSV] ============================================');
      print('[CSV] ✓ Upload concluído');
      print('[CSV]   Total processado: ${result.totalProcessed}');
      print('[CSV]   Total importado: ${result.totalImported}');
      print('[CSV]   Total ignorado: ${result.totalIgnored}');
      print('[CSV]   Total com erro: ${result.totalErrors}');

      _uploadProgress = 1.0;
      if (mounted) {
        setState(() {
          _importResult = result;
          _phase = ImportPhase.results;
        });
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      print('[CSV] Erro na API: ${e.message} (status: ${e.statusCode})');
      setState(() {
        _error = e.message;
        _phase = ImportPhase.validation;
      });
    } catch (e) {
      if (!mounted) return;
      print('[CSV] Erro ao fazer upload: $e');
      setState(() {
        _error = 'Erro ao fazer upload: $e';
        _phase = ImportPhase.validation;
      });
    }
  }

  void _reset() {
    setState(() {
      _phase = ImportPhase.selection;
      _fileName = null;
      _filePath = null;
      _fileBytes = null;
      _csvData = null;
      _invalidRows = null;
      _importResult = null;
      _error = null;
      _uploadProgress = 0;
      _isValidating = false;
    });
    print('[CSV] Estado resetado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Importar Alunos e Responsáveis'),
        leading: const BackButton(color: Colors.white),
      ),
      body: WillPopScope(
        onWillPop: () async {
          if (_phase != ImportPhase.selection) {
            _reset();
            return false;
          }
          return true;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              switch (_phase) {
                ImportPhase.selection => _buildSelectionPhase(),
                ImportPhase.validation => _buildValidationPhase(),
                ImportPhase.uploading => _buildUploadingPhase(),
                ImportPhase.results => _buildResultsPhase(),
              },
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    const steps = ['Arquivo', 'Validação', 'Upload', 'Resultado'];
    final currentIndex = _phase.index;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i <= currentIndex;
          final isCurrent = i == currentIndex;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppTheme.accentBlue : Colors.grey[700],
                  ),
                  child: Center(
                    child: isCurrent
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withOpacity(0.8),
                              ),
                            ),
                          )
                        : isActive
                            ? const Icon(Icons.check, color: Colors.white)
                            : Text('${i + 1}', style: const TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  steps[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? Colors.white : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectionPhase() {
    // Use the getter - works for both web and mobile
    final fileSize = _fileSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _fileName != null ? AppTheme.accentBlue : Theme.of(context).dividerColor,
                width: _fileName != null ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.file_upload_outlined,
                  color: AppTheme.accentBlue,
                  size: 56,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Selecione seu arquivo CSV',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Clique para selecionar',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Selecionar Arquivo'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(200, 44),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_fileName != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fileName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Tamanho: ${(fileSize / 1024).toStringAsFixed(2)} KB',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _validateFile,
              icon: const Icon(Icons.check),
              label: const Text('Validar e Continuar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentBlue,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
        const SizedBox(height: 32),
        _buildInstructions(),
      ],
    );
  }

  Widget _buildValidationPhase() {
    if (_isValidating) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Validando arquivo...',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_invalidRows != null && _invalidRows!.isNotEmpty) ...[
            Text(
              'Erros encontrados:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildErrorsTable(_invalidRows!),
            const SizedBox(height: 24),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.close),
              label: const Text('Recomeçar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.8),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      );
    }

    if (_csvData != null && _csvData!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Text(
                      'Arquivo validado!',
                      style: TextStyle(
                        color: Colors.green[200],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_csvData!.length} registros prontos para importar',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Preview:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildPreviewTable(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _uploadCsv,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Importar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUploadingPhase() {
    return Column(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(
          'Enviando arquivo...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            minHeight: 8,
            backgroundColor: Colors.grey[700],
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${(_uploadProgress * 100).toStringAsFixed(0)}%',
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildResultsPhase() {
    if (_importResult == null) return const SizedBox.shrink();

    final result = _importResult!;
    final hasErrors = result.errors.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: result.totalErrors == 0
                ? Colors.green.withOpacity(0.15)
                : Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: result.totalErrors == 0
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                result.totalErrors == 0 ? Icons.check_circle : Icons.info,
                color: result.totalErrors == 0 ? Colors.green : Colors.orange,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  result.totalErrors == 0
                      ? 'Sucesso!'
                      : 'Concluído com avisos',
                  style: TextStyle(
                    color: result.totalErrors == 0 ? Colors.green[200] : Colors.orange[200],
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildStatisticsGrid(result),
        const SizedBox(height: 24),
        if (hasErrors) ...[
          Text(
            'Erros:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildErrorsTable(
            result.errors.map((e) {
              final row = CsvRow(
                lineNumber: e.row,
                studentName: e.field,
                grade: '',
                className: '',
                guardianName: '',
                guardianEmail: '',
                guardianPhone: '',
              );
              row.validationError = e.message;
              return row;
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.home),
            label: const Text('Voltar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsGrid(ImportResult result) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _buildStatCard('Processado', result.totalProcessed.toString(), Colors.blue),
        _buildStatCard('Importados', result.totalImported.toString(), Colors.green),
        _buildStatCard('Ignorados', result.totalIgnored.toString(), Colors.orange),
        _buildStatCard('Erros', result.totalErrors.toString(), Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTable() {
    final rows = _csvData!.take(3).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[800]),
        dataRowHeight: 56,
        columns: const [
          DataColumn(label: Text('Aluno')),
          DataColumn(label: Text('Série')),
          DataColumn(label: Text('Turma')),
          DataColumn(label: Text('Responsável')),
        ],
        rows: rows
            .map(
              (row) => DataRow(cells: [
                DataCell(Text(row.studentName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(Text(row.grade)),
                DataCell(Text(row.className)),
                DataCell(Text(row.guardianName, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _buildErrorsTable(List<CsvRow> errors) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[800]),
        dataRowHeight: 60,
        columns: const [
          DataColumn(label: Text('Linha')),
          DataColumn(label: Text('Campo')),
          DataColumn(label: Text('Erro')),
        ],
        rows: errors
            .map(
              (error) => DataRow(cells: [
                DataCell(Text('${error.lineNumber}')),
                DataCell(Text(error.studentName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      error.validationError ?? 'Erro',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
              ]),
            )
            .toList(),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Formato do CSV',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _instructionRow('Coluna A', 'student_name', 'Nome do Aluno'),
          _instructionRow('Coluna B', 'grade', 'Série'),
          _instructionRow('Coluna C', 'class', 'Turma'),
          _instructionRow('Coluna D', 'guardian_name', 'Nome Responsável'),
          _instructionRow('Coluna E', 'guardian_email', 'Email'),
          _instructionRow('Coluna F', 'guardian_phone', 'Telefone'),
          _instructionRow('Coluna G', 'guardian_phone_secondary', 'Tel. 2º (opcional)'),
          _instructionRow('Coluna H', 'guardian_email_secondary', 'Email 2º (opcional)'),
        ],
      ),
    );
  }

  Widget _instructionRow(String column, String field, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              column,
              style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
