import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool updateAvailable;
  final String? releaseNotes;
  final String? downloadUrl;
  final String? releaseName;
  final DateTime? publishedAt;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.updateAvailable,
    this.releaseNotes,
    this.downloadUrl,
    this.releaseName,
    this.publishedAt,
  });
}

class UpdateService {
  static const String _owner = 'trirooppvtltd';
  static const String _repo = 'msme_tool_release';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  // Cached update info
  static UpdateInfo? _cachedUpdateInfo;
  static DateTime? _lastCheckTime;
  static const Duration _cacheDuration = Duration(hours: 1);

  /// Get current app version from package info
  static Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (e) {
      debugPrint('Error getting package info: $e');
      return '1.0.0';
    }
  }

  /// Compare two version strings
  /// Returns true if latest is newer than current
  static bool isNewerVersion(String latest, String current) {
    // Remove 'v' prefix if present
    latest = latest.replaceFirst(RegExp(r'^v'), '');
    // Remove build number (+N) from current version
    current = current.split('+').first;

    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) latestParts.add(0);
      while (currentParts.length < 3) currentParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint('Error comparing versions: $e');
      return false;
    }
  }

  /// Check for updates from GitHub releases
  /// Returns cached result if checked recently
  static Future<UpdateInfo> checkForUpdates({bool forceCheck = false}) async {
    // Return cached result if available and not expired
    if (!forceCheck && _cachedUpdateInfo != null && _lastCheckTime != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
      if (timeSinceLastCheck < _cacheDuration) {
        return _cachedUpdateInfo!;
      }
    }

    final currentVersion = await getCurrentVersion();

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        final tagName = data['tag_name'] as String? ?? '';
        final releaseName = data['name'] as String?;
        final body = data['body'] as String?;
        final htmlUrl = data['html_url'] as String?;
        final publishedAtStr = data['published_at'] as String?;

        DateTime? publishedAt;
        if (publishedAtStr != null) {
          publishedAt = DateTime.tryParse(publishedAtStr);
        }

        // Check for direct download URL from assets
        String? downloadUrl = htmlUrl;
        final assets = data['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            final assetName = (asset['name'] as String?)?.toLowerCase() ?? '';
            if (assetName.endsWith('.exe') || assetName.contains('setup')) {
              downloadUrl = asset['browser_download_url'] as String?;
              break;
            }
          }
        }

        final updateAvailable = isNewerVersion(tagName, currentVersion);

        _cachedUpdateInfo = UpdateInfo(
          latestVersion: tagName.replaceFirst(RegExp(r'^v'), ''),
          currentVersion: currentVersion,
          updateAvailable: updateAvailable,
          releaseNotes: body,
          downloadUrl: downloadUrl,
          releaseName: releaseName,
          publishedAt: publishedAt,
        );
        _lastCheckTime = DateTime.now();

        return _cachedUpdateInfo!;
      } else if (response.statusCode == 404) {
        // No releases found
        debugPrint('No releases found in repository');
        return UpdateInfo(
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          updateAvailable: false,
          releaseNotes: null,
          downloadUrl: null,
        );
      } else {
        debugPrint('GitHub API error: ${response.statusCode}');
        throw Exception('Failed to check for updates: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      // Return non-update result on error
      return UpdateInfo(
        latestVersion: currentVersion,
        currentVersion: currentVersion,
        updateAvailable: false,
        releaseNotes: null,
        downloadUrl: null,
      );
    }
  }

  /// Clear cached update info
  static void clearCache() {
    _cachedUpdateInfo = null;
    _lastCheckTime = null;
  }
}
