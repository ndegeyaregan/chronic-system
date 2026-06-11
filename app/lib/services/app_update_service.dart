import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/constants.dart';
import '../core/app_colors.dart';

/// Result of an update check against `GET /api/app/version`.
class UpdateInfo {
  final String latest;        // human version e.g. "1.0.1"
  final int latestCode;       // build number e.g. 2
  final String minSupported;
  final int minSupportedCode;
  final String currentVersion;
  final int currentCode;
  final String url;           // absolute APK url
  final int sizeBytes;
  final List<String> releaseNotes;

  const UpdateInfo({
    required this.latest,
    required this.latestCode,
    required this.minSupported,
    required this.minSupportedCode,
    required this.currentVersion,
    required this.currentCode,
    required this.url,
    required this.sizeBytes,
    required this.releaseNotes,
  });

  bool get hasUpdate => latestCode > currentCode;
  bool get isForceUpdate => currentCode < minSupportedCode;
  String get sizeMb => (sizeBytes / (1024 * 1024)).toStringAsFixed(1);
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static const _kSkippedVersionKey = 'update_skipped_code_v1';

  Future<UpdateInfo?> check() async {
    try {
      final resp = await _dio.get('/app/version');
      final data = Map<String, dynamic>.from(resp.data as Map);
      final pkg = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(pkg.buildNumber) ?? 0;
      return UpdateInfo(
        latest: (data['latest'] ?? '').toString(),
        latestCode: (data['latestCode'] as num?)?.toInt() ?? 0,
        minSupported: (data['minSupported'] ?? '').toString(),
        minSupportedCode: (data['minSupportedCode'] as num?)?.toInt() ?? 0,
        currentVersion: pkg.version,
        currentCode: currentCode,
        url: (data['url'] ?? '').toString(),
        sizeBytes: (data['sizeBytes'] as num?)?.toInt() ?? 0,
        releaseNotes:
            ((data['releaseNotes'] as List?) ?? const [])
                .map((e) => e.toString())
                .toList(),
      );
    } catch (_) {
      // Offline / network error — silently skip.
      return null;
    }
  }

  Future<bool> wasSkipped(int code) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kSkippedVersionKey) == code;
  }

  Future<void> markSkipped(int code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kSkippedVersionKey, code);
  }

  Future<bool> openDownload(String url) async {
    final uri = Uri.parse(url);
    // Don't gate on canLaunchUrl(): on Android 11+ it returns false unless the
    // exact intent is declared in <queries>, even when a browser is installed.
    // Try the launch directly and fall back to in-app webview if needed.
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return true;
    } catch (_) {}
    try {
      return await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }
}

/// One-shot update check exposed as a provider so the dashboard can fire it
/// once on first build.
final appUpdateCheckProvider =
    FutureProvider.autoDispose<UpdateInfo?>((ref) async {
  return AppUpdateService.instance.check();
});

/// Pops up the update dialog if a new version is available.
/// Call from `initState` of the dashboard (after the first frame).
Future<void> maybeShowUpdateDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final info = await AppUpdateService.instance.check();
  if (info == null || !info.hasUpdate) return;
  if (!context.mounted) return;

  // Honour "Skip this version" — but never honour it for force-updates.
  if (!info.isForceUpdate &&
      await AppUpdateService.instance.wasSkipped(info.latestCode)) {
    return;
  }
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: !info.isForceUpdate,
    builder: (ctx) => PopScope(
      canPop: !info.isForceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kRadiusLg)),
        title: Row(
          children: [
            Icon(
              info.isForceUpdate
                  ? Icons.warning_amber_rounded
                  : Icons.system_update_rounded,
              color: info.isForceUpdate ? Colors.red : kPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                info.isForceUpdate ? 'Update Required' : 'Update Available',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of the Sanlam Allianz Chronic Care app is ready.',
                style: TextStyle(fontSize: 13, color: context.c.text),
              ),
              const SizedBox(height: 12),
              _versionRow(context, 'Current', info.currentVersion),
              _versionRow(context, 'Latest', info.latest, highlight: true),
              if (info.sizeBytes > 0) _versionRow(context, 'Size', '${info.sizeMb} MB'),
              if (info.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text("What's new",
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: context.c.text)),
                const SizedBox(height: 6),
                ...info.releaseNotes.map(
                  (note) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('•  ',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: kPrimary)),
                        Expanded(
                          child: Text(note,
                              style: TextStyle(
                                  fontSize: 12.5, color: context.c.text, height: 1.4)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (info.isForceUpdate) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(kRadiusMd),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'This update is required to keep using the app.',
                    style: TextStyle(
                        fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          if (!info.isForceUpdate)
            TextButton(
              onPressed: () async {
                await AppUpdateService.instance.markSkipped(info.latestCode);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text('Skip this version',
                  style: TextStyle(color: context.c.subtext)),
            ),
          if (!info.isForceUpdate)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Later'),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kRadiusMd)),
            ),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Update Now'),
            onPressed: () async {
              final ok = await AppUpdateService.instance.openDownload(info.url);
              if (!ctx.mounted) return;
              if (!ok) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Could not open download link. Please visit ${info.url} in your browser.',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 6),
                  ),
                );
                return;
              }
              if (!info.isForceUpdate) Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    ),
  );
}

Widget _versionRow(BuildContext context, String label, String value, {bool highlight = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: context.c.subtext)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: highlight ? kPrimary : context.c.text,
            ),
          ),
        ],
      ),
    );
