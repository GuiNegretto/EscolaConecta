import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/update_provider.dart';
import '../../services/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_loading_error_widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _checkingUpdates = false;

  Future<void> _handleCheckUpdates() async {
    setState(() => _checkingUpdates = true);
    final updateProvider = context.read<UpdateProvider>();

    try {
      final hasUpdate = await updateProvider.checkForUpdates(silent: false);

      if (!mounted) return;
      setState(() => _checkingUpdates = false);

      if (hasUpdate) {
        _showUpdateDialog(context, updateProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Seu app está atualizado!'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingUpdates = false);
      AppErrorDialog.show(
        context,
        message: 'Erro ao verificar atualizações: ${updateProvider.error}',
      );
    }
  }

  void _showUpdateDialog(BuildContext context, UpdateProvider updateProvider) {
    showDialog(
      context: context,
      barrierDismissible: !updateProvider.forceUpdate,
      builder: (dialogContext) {
        return Consumer<UpdateProvider>(
          builder: (ctx, provider, _) => WillPopScope(
            onWillPop: () async => !provider.forceUpdate,
            child: AlertDialog(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(
                'Atualização Disponível',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Version info
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Nova versão: ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          TextSpan(
                            text: provider.latestVersion,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Download progress bar
                    if (provider.downloading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: provider.downloadProgress,
                          minHeight: 6,
                          backgroundColor: Theme.of(context).dividerColor,
                          valueColor: AlwaysStoppedAnimation(AppTheme.accentBlue),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '${(provider.downloadProgress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Changelog
                    if (provider.changelog.isNotEmpty) ...[
                      Text(
                        'Mudanças:',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkCard
                              : AppTheme.lightCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          provider.changelog,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Force update notice
                    if (provider.forceUpdate)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withOpacity(0.1),
                          border: Border.all(color: AppTheme.warning),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning_amber, color: AppTheme.warning, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Atualização obrigatória',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.warning,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                if (!provider.forceUpdate && !provider.downloading)
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Depois',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                    ),
                  ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                  ),
                  onPressed: provider.downloading
                      ? null
                      : () async {
                    final success = await provider.downloadAndInstall(
                      provider.downloadUrl,
                    );
                    if (!dialogContext.mounted) return;
                    if (!success) {
                      AppErrorDialog.show(
                        dialogContext,
                        message: 'Erro: ${provider.error}',
                      );
                    }
                  },
                  child: Text(
                    provider.downloading ? 'Baixando...' : 'Atualizar',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: const Text('Sobre o App'),
        leading: const BackButton(color: Colors.white),
        actions: [
          Consumer<ThemeProvider>(
            builder: (ctx, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
              ),
              onPressed: () => themeProvider.toggleTheme(),
              tooltip: themeProvider.isDarkMode ? 'Modo Claro' : 'Modo Escuro',
            ),
          ),
        ],
      ),
      body: Consumer<UpdateProvider>(
        builder: (context, updateProvider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App Logo/Name section
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.school,
                        size: 80,
                        color: AppTheme.accentBlue,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'EscolaConecta',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'App de comunicação escolar segura',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Version Information Card
                _buildInfoCard(
                  context,
                  title: 'Versão Instalada',
                  value: updateProvider.currentVersion,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),

                _buildInfoCard(
                  context,
                  title: 'Última Versão',
                  value: updateProvider.latestVersion.isEmpty
                      ? 'Verificando...'
                      : updateProvider.latestVersion,
                  icon: Icons.cloud_download_outlined,
                  valueColor: updateProvider.updateAvailable ? AppTheme.warning : null,
                ),
                const SizedBox(height: 24),

                // Check for Updates Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _checkingUpdates ? null : _handleCheckUpdates,
                    icon: _checkingUpdates
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: AppLoadingButtonIndicator(
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _checkingUpdates ? 'Verificando...' : 'Verificar Atualizações',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Changelog if available
                if (updateProvider.updateAvailable && updateProvider.changelog.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'O que há de novo?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppTheme.darkCard
                              : AppTheme.lightCard,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          updateProvider.changelog,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Download button if update is available
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: updateProvider.downloading
                              ? null
                              : () => _showUpdateDialog(context, updateProvider),
                          icon: updateProvider.downloading
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: AppLoadingButtonIndicator(
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.download),
                          label: Text(
                            updateProvider.downloading
                                ? 'Baixando ${(updateProvider.downloadProgress * 100).toStringAsFixed(0)}%'
                                : 'Baixar Atualização',
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 32),

                // About section
                Text(
                  'Sobre',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'EscolaConecta é um aplicativo seguro e privado para comunicação entre escola, pais e alunos.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppTheme.darkCard
            : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentBlue, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
