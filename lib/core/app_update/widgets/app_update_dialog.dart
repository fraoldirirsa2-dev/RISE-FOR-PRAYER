import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rise_for_prayer/core/app_update/controllers/app_update_controller.dart';
import 'package:rise_for_prayer/core/app_update/models/app_update_info.dart';
import 'package:rise_for_prayer/utils/colors.dart';
import 'package:rise_for_prayer/utils/localization.dart';

/// Professional Material 3 App Update Dialog consistent with the app's liturgical theme.
class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.updateInfo,
    required this.controller,
    required this.language,
  });

  final AppUpdateInfo updateInfo;
  final AppUpdateController controller;
  final String language;

  /// Shows the dialog safely avoiding overlapping dialogs.
  static bool _isShowing = false;

  static Future<void> show(
    BuildContext context, {
    required AppUpdateInfo updateInfo,
    required AppUpdateController controller,
    required String language,
  }) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: !updateInfo.isMandatory,
        builder: (ctx) => AppUpdateDialog(
          updateInfo: updateInfo,
          controller: controller,
          language: language,
        ),
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = widget.updateInfo;
    final controller = widget.controller;
    final isMandatory = info.isMandatory;
    final language = widget.language;

    final isDownloading = controller.status == UpdateStatus.downloading;
    final isReadyToInstall = controller.status == UpdateStatus.readyToInstall;
    final hasError = controller.status == UpdateStatus.error && controller.errorMessage != null;

    final titleText = localizedText(
      language,
      'አዲስ ማሻሻያ ተዘጋጅቷል',
      'New Version Available',
    );

    final currentLabel = localizedText(language, 'የአሁኑ ስሪት፦', 'Current version:');
    final newLabel = localizedText(language, 'አዲሱ ስሪት፦', 'New version:');
    final sizeLabel = localizedText(language, 'መጠን፦', 'Size:');
    final whatsNewLabel = localizedText(language, 'ምን አዲስ ነገር አለ?', "What's New:");

    return PopScope(
      canPop: !isMandatory && !isDownloading,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: colors.surface,
        elevation: 8,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon + Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.burgundy.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleText,
                            style: GoogleFonts.cinzel(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          if (isMandatory)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                localizedText(
                                  language,
                                  'ይህ ማሻሻያ አስገዳጅ ነው',
                                  'Required Update',
                                ),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Version comparison pill
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1624)
                        : const Color(0xFFF7F3EA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'v${info.installedVersion.displayVersion}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.gold),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            newLabel,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colors.onSurface.withValues(alpha: 0.6),
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'v${info.latestVersion.displayVersion}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (info.apkAsset != null && info.apkAsset!.sizeInBytes > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '$sizeLabel ${info.apkAsset!.formattedSize}',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                  ),
                ],
                const SizedBox(height: 16),

                // Release notes
                if (info.releaseNotes.isNotEmpty) ...[
                  Text(
                    whatsNewLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: colors.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        _sanitizeReleaseNotes(info.releaseNotes),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.5,
                              fontSize: 12,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Downloading Progress Bar
                if (isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: controller.downloadProgress > 0 ? controller.downloadProgress : null,
                      backgroundColor: colors.outlineVariant.withValues(alpha: 0.3),
                      color: AppColors.gold,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.statusMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Error Message
                if (hasError) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!isMandatory && !isDownloading)
                      TextButton(
                        onPressed: () {
                          controller.dismissUpdate();
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          localizedText(language, 'ቆይቼ', 'Later'),
                          style: TextStyle(color: colors.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.burgundy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: isDownloading
                          ? null
                          : () async {
                              if (isReadyToInstall && controller.downloadedApk != null) {
                                await controller.downloadAndInstall();
                              } else {
                                await controller.downloadAndInstall();
                              }
                            },
                      child: Text(
                        hasError
                            ? localizedText(language, 'እንደገና ሞክር', 'Retry')
                            : (isReadyToInstall
                                ? localizedText(language, 'ጫን', 'Install Now')
                                : localizedText(language, 'አሁን አዘምን', 'Update Now')),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sanitizeReleaseNotes(String notes) {
    return notes
        .replaceAll(RegExp(r'\[MANDATORY\]|\[REQUIRED\]', caseSensitive: false), '')
        .trim();
  }
}
