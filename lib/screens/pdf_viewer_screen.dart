import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import '../services/file_download_service.dart';
import '../utils/app_theme.dart';

class PdfViewerScreen extends StatefulWidget {
  final String url;
  final String fileName;

  const PdfViewerScreen({
    super.key,
    required this.url,
    required this.fileName,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final _downloadService = FileDownloadService();
  
  String? _localPath;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Baixar PDF temporariamente para visualização
      final path = await _downloadService.downloadTempFile(
        widget.url,
        widget.fileName,
      );

      setState(() {
        _localPath = path;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar PDF: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPermanently() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
      });

      final path = await _downloadService.downloadFile(
        widget.url,
        widget.fileName,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Arquivo salvo em: $path'),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () => OpenFilex.open(path),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isDownloading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          if (_localPath != null && !_isDownloading)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: _downloadPermanently,
              tooltip: 'Baixar arquivo',
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _localPath != null && _totalPages > 0
          ? Container(
              color: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Página ${_currentPage + 1} de $_totalPages',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accentBlue),
            SizedBox(height: 16),
            Text(
              'Carregando PDF...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isDownloading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.grey[800],
                color: AppTheme.accentBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Baixando... ${(_downloadProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return PDFView(
      filePath: _localPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: _currentPage,
      fitPolicy: FitPolicy.WIDTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        setState(() {
          _totalPages = pages ?? 0;
        });
      },
      onError: (error) {
        setState(() {
          _error = 'Erro ao renderizar PDF: $error';
        });
      },
      onPageError: (page, error) {
        debugPrint('Erro na página $page: $error');
      },
      onViewCreated: (PDFViewController controller) {
        // Controlador criado
      },
      onPageChanged: (page, total) {
        setState(() {
          _currentPage = page ?? 0;
          _totalPages = total ?? 0;
        });
      },
    );
  }
}
