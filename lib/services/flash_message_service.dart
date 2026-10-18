import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flash_message.dart';
import '../database/db_helper.dart';

class FlashMessageService {
  static final FlashMessageService _instance = FlashMessageService._internal();
  factory FlashMessageService() => _instance;
  FlashMessageService._internal();

  static const String cdnUrl =
      'https://cdn.jsdelivr.net/gh/sherawali/tet@main/cdn/flash_messages.json';
  static const String rawUrl =
      'https://raw.githubusercontent.com/sherawali/tet/main/cdn/flash_messages.json';

  final DbHelper _db = DbHelper.instance;

  /// Fetch active flash messages from GitHub CDN or local fallback
  Future<List<FlashMessage>> getActiveMessages() async {
    List<FlashMessage> allMessages = [];

    // 1. Try raw GitHub / CDN URL with cache busting
    try {
      final rawRes = await http.get(
        Uri.parse('$rawUrl?_ts=${DateTime.now().millisecondsSinceEpoch}'),
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(const Duration(seconds: 4));

      if (rawRes.statusCode == 200) {
        allMessages = _parseJson(utf8.decode(rawRes.bodyBytes));
        await _db.setMeta('cached_flash_json', utf8.decode(rawRes.bodyBytes));
      } else {
        final res = await http.get(Uri.parse(cdnUrl)).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          allMessages = _parseJson(utf8.decode(res.bodyBytes));
          await _db.setMeta('cached_flash_json', utf8.decode(res.bodyBytes));
        }
      }
    } catch (_) {
      // 2. Read from cached DB meta on offline/error
      final cachedJson = await _db.getMeta('cached_flash_json');
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        allMessages = _parseJson(cachedJson);
      }
    }

    // 3. Define master multi-slide broadcasts
    final defaultBroadcasts = [
      const FlashMessage(
        id: 'live_flash_2026_master',
        title: '🔥 UTET & CTET 2026: 9,720 प्रश्नों का सम्पूर्ण बैंक लाइव!',
        message: 'सभी 62 ओरिजिनल पेपर्स और 20 मॉडल सेट्स 100% प्रामाणिक हल सहित उपलब्ध हैं। OMR व CBT मोड में अभ्यास करें।',
        type: 'notice',
        actionLabel: 'मॉक सीरीज़ देखें',
        isDismissible: true,
      ),
      const FlashMessage(
        id: 'remote_cloud_sync_notice',
        title: '⚡ लाइव क्लाउड सिंक व रिमोट कंट्रोल सक्रिय',
        message: 'GitHub से नए मॉक, प्रश्न सुधार और फ्री/पेड नियम सीधे बिना ऐप अपडेट के आपके फोन में सिंक होंगे।',
        type: 'update',
        actionLabel: 'मॉक टेस्ट देखें',
        isDismissible: true,
      ),
      const FlashMessage(
        id: 'offline_cbt_omr_mode',
        title: '📝 वास्तविक परीक्षा जैसा OMR व CBT मोड',
        message: 'समय सीमा, नेगेटिव मार्किंग और संपूर्ण हल सहित अपनी तैयारी का लाइव मूल्यांकन करें।',
        type: 'success',
        actionLabel: 'टेस्ट शुरू करें',
        isDismissible: true,
      ),
    ];

    // Ensure all fresh multi-slide broadcasts are present alongside remote messages
    for (final def in defaultBroadcasts) {
      if (!allMessages.any((m) => m.id == def.id)) {
        allMessages.add(def);
      }
    }

    // 4. Filter out dismissed message IDs (messages with isDismissible == false always show)
    final dismissedSet = await _getDismissedIds();
    var visible = allMessages.where((m) => !m.isDismissible || !dismissedSet.contains(m.id)).toList();

    // If all messages were dismissed, reset and show the fresh broadcasts so banner remains active
    if (visible.isEmpty) {
      visible = defaultBroadcasts;
    }

    return visible;
  }

  List<FlashMessage> _parseJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => FlashMessage.fromJson(Map<String, dynamic>.from(e))).toList();
      } else if (decoded is Map && decoded['messages'] is List) {
        return (decoded['messages'] as List)
            .map((e) => FlashMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  /// Mark single message as dismissed by user
  Future<void> dismissMessage(String id) async {
    final dismissed = await _getDismissedIds();
    dismissed.add(id);
    await _saveDismissedIds(dismissed);
  }

  /// Mark multiple messages as dismissed at once (e.g. when user closes banner)
  Future<void> dismissAll(List<String> ids) async {
    final dismissed = await _getDismissedIds();
    dismissed.addAll(ids);
    await _saveDismissedIds(dismissed);
  }

  Future<void> _saveDismissedIds(Set<String> dismissed) async {
    final list = dismissed.toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('dismissed_flash_ids', list);
    } catch (_) {}
    try {
      await _db.setMeta('dismissed_flash_ids', jsonEncode(list));
    } catch (_) {}
  }

  Future<Set<String>> _getDismissedIds() async {
    final result = <String>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('dismissed_flash_ids');
      if (list != null && list.isNotEmpty) {
        result.addAll(list);
      }
    } catch (_) {}

    if (result.isEmpty) {
      try {
        final val = await _db.getMeta('dismissed_flash_ids');
        if (val != null && val.isNotEmpty) {
          final List<dynamic> list = jsonDecode(val);
          result.addAll(list.map((e) => e.toString()));
        }
      } catch (_) {}
    }
    return result;
  }
}

