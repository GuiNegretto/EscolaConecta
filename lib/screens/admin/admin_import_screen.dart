
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';

class AdminImportScreen extends StatefulWidget {
  const AdminImportScreen({super.key});

  @override
  State<AdminImportScreen> createState() => _AdminImportScreenState();
}

class _AdminImportScreenState extends State<AdminImportScreen> {
  final _api = ApiService();
  String? _fileName;
  String? _filePath;
  bool _uploading = false;
  bool _success = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'csv'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _fileName = result.files.single.name;
        _filePath = result.files.single.path;
        _success = false;
      });
    }
  }

  Future<void> _upload() async {
    if (_filePath == null) return;
    setState(() => _uploading = true);
    try {
      await _api.importSpreadsheet(_filePath!);
      if (!mounted) return;
      setState(() {
        _success = true;
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Planilha importada com sucesso!'),
        backgroundColor: AppTheme.success,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Importar Dados'),
        leading: const BackButton(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _uploading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Upload area
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fileName != null
                          ? AppTheme.accentBlue
                          : Theme.of(context).dividerColor,
                      width: _fileName != null ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _success
                            ? Icons.check_circle_outline
                            : Icons.upload_outlined,
                        color: _success
                            ? AppTheme.success
                            : AppTheme.accentBlue,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _success
                            ? 'Importado com sucesso!'
                            : 'Upload de Planilha',
                        style: TextStyle(
                          color: _success ? AppTheme.success : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_fileName != null)
                        Text(
                          _fileName!,
                          style: const TextStyle(
                              color: AppTheme.accentBlue, fontSize: 14),
                        )
                      else
                       Text(
                          'Formatos aceitos: .xlsx, .csv',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 14
)
                        ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(160, 44),
                        ),
                        child: Text(
                            _fileName != null ? 'Trocar Arquivo' : 'Selecionar Arquivo'),
                      ),
                    ],
                  ),
                ),
              ),

              if (_fileName != null && !_success) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _uploading ? null : _upload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Importar Dados'),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Formato esperado da planilha',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _instructionRow('Coluna A', 'Nome do Aluno'),
                    _instructionRow('Coluna B', 'Série (ex: 1º Ano)'),
                    _instructionRow('Coluna C', 'Turma (ex: A)'),
                    _instructionRow('Coluna D', 'Nome do Responsável'),
                    _instructionRow('Coluna E', 'Telefone do Responsável'),
                    _instructionRow('Coluna F', 'Email do Responsável'),
                    const SizedBox(height: 12),
                    Text(
                      '* A primeira linha deve conter os cabeçalhos.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _instructionRow(String col, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(col,
                style: const TextStyle(
                    color: AppTheme.accentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Text(desc,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
  fontSize: 13,
)),
        ],
      ),
    );
  }
}