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

    // 3. If still empty, provide default welcome & advisory message
    if (allMessages.isEmpty) {
      allMessages = [
        const FlashMessage(
          id: 'welcome_board_bank',
          title: '🎯 UTET: 4,620 प्रामाणिक प्रश्नों का बैंक तैयार!',
          message: '20 मॉडल प्रश्न-पुस्तिकाएं और विगत वर्षों के सभी हल प्रश्न-पत्र 100% ऑफ़लाइन उपलब्ध हैं।',
          type: 'notice',
          actionLabel: 'मॉक सीरीज़ देखें',
        ),
      ];
    }

    // 4. Filter out dismissed message IDs
    final dismissedSet = await _getDismissedIds();
    final visible = allMessages.where((m) => !dismissedSet.contains(m.id)).toList();
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

