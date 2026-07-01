import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:open_filex/open_filex.dart';
import '../models/models.dart';
import '../utils/app_theme.dart';
import '../screens/pdf_viewer_screen.dart';
import '../screens/video_player_screen.dart';
import '../services/file_download_service.dart';

class MessageAttachmentsWidget extends StatelessWidget {
  final List<MessageAttachment> attachments;

  const MessageAttachmentsWidget({
    super.key,
    required this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 16),
        Text(
          'Anexos',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        ...attachments.map((att) {
          if (att.isImage) {
            return _ImageAttachment(attachment: att);
          } else if (att.isVideo) {
            return _VideoAttachment(attachment: att);
          } else if (att.isPdf) {
            return _PdfAttachment(attachment: att);
          } else {
            return _FileAttachment(attachment: att);
          }
        }),
      ],
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final MessageAttachment attachment;

  const _ImageAttachment({required this.attachment});

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            // Abrir imagem em tela cheia
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _FullScreenImage(
                  url: attachment.url,
                  fileName: attachment.fileName,
                ),
              ),
            );
          },
          child: FutureBuilder<Map<String, String>>(
            future: _getHeaders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  height: 200,
                  color: Theme.of(context).colorScheme.surface,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              return CachedNetworkImage(
                imageUrl: attachment.url,
                httpHeaders: snapshot.data,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppTheme.accentBlue),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Erro ao carregar imagem'),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VideoAttachment extends StatelessWidget {
  final MessageAttachment attachment;

  const _VideoAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          // Abrir player de vídeo
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                url: attachment.url,
                fileName: attachment.fileName,
              ),
            ),
          );
        },
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).dividerColor,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white,
              ),
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.videocam, size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          attachment.fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfAttachment extends StatelessWidget {
  final MessageAttachment attachment;

  const _PdfAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: ListTile(
          tileColor: Colors.transparent,
          leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
          title: Text(
            attachment.fileName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Text(
            attachment.fileType,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, color: AppTheme.accentBlue),
                onPressed: () {
                  // Abrir visualizador de PDF
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        url: attachment.url,
                        fileName: attachment.fileName,
                      ),
                    ),
                  );
                },
                tooltip: 'Visualizar PDF',
              ),
              IconButton(
                icon: const Icon(Icons.download, color: AppTheme.accentBlue),
                onPressed: () => _downloadFile(context),
                tooltip: 'Baixar PDF',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentBlue),
        ),
      );

      final downloadService = FileDownloadService();
      final path = await downloadService.downloadFile(
        attachment.url,
        attachment.fileName,
      );

      if (context.mounted) {
        Navigator.pop(context); // Fechar loading

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
      if (context.mounted) {
        Navigator.pop(context); // Fechar loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FileAttachment extends StatelessWidget {
  final MessageAttachment attachment;

  const _FileAttachment({required this.attachment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
        ),
        child: ListTile(
          tileColor: Colors.transparent,
          leading: const Icon(Icons.attach_file, color: AppTheme.accentBlue),
          title: Text(
            attachment.fileName,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          subtitle: Text(
            attachment.fileType,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download, color: AppTheme.accentBlue),
            onPressed: () => _downloadFile(context),
            tooltip: 'Baixar arquivo',
          ),
        ),
      ),
    );
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppTheme.accentBlue),
        ),
      );

      final downloadService = FileDownloadService();
      final path = await downloadService.downloadFile(
        attachment.url,
        attachment.fileName,
      );

      if (context.mounted) {
        Navigator.pop(context); // Fechar loading

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
      if (context.mounted) {
        Navigator.pop(context); // Fechar loading

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  final String fileName;

  const _FullScreenImage({required this.url, required this.fileName});

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = FileDownloadService();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                );

                final path = await downloadService.downloadFile(url, fileName);

                if (context.mounted) {
                  Navigator.pop(context); // Fechar loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Imagem salva em: $path'),
                      action: SnackBarAction(
                        label: 'Abrir',
                        onPressed: () => OpenFilex.open(path),
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Fechar loading

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erro ao baixar: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            tooltip: 'Baixar imagem',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: FutureBuilder<Map<String, String>>(
            future: _getHeaders(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator(color: Colors.white);
              }

              return CachedNetworkImage(
                imageUrl: url,
                httpHeaders: snapshot.data,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Erro ao carregar imagem',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
