import 'package:flutter/material.dart';
import '../design_system/app_radius.dart';
import '../design_system/app_typography.dart';
import '../models/passage.dart';
import '../database/db_helper.dart';
import '../data/official_pyq_repository.dart';

/// Master Premium Passage & Poem Display Card
/// Displays reading comprehension prose (गद्यांश) and poetry (पद्यांश/काव्यांश)
/// with exam-accurate formatting, clean Devanagari typography, and toggleable view.
class PassageDisplayCard extends StatefulWidget {
  final Passage passage;
  final int? seqInPassage;
  final int? startQNum;
  final int? endQNum;
  final bool isDark;
  final bool isCompactReference;
  final bool initiallyExpanded;

  const PassageDisplayCard({
    super.key,
    required this.passage,
    this.seqInPassage,
    this.startQNum,
    this.endQNum,
    required this.isDark,
    this.isCompactReference = false,
    this.initiallyExpanded = true,
  });

  @override
  State<PassageDisplayCard> createState() => _PassageDisplayCardState();
}

class _PassageDisplayCardState extends State<PassageDisplayCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isCompactReference ? false : widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final isPoem = widget.passage.isPoem;
    final isDark = widget.isDark;

    // Dynamic question range tag e.g. " (प्रश्न 31–38)"
    final String qRangeSuffix;
    if (widget.startQNum != null && widget.endQNum != null) {
      if (widget.startQNum == widget.endQNum) {
        qRangeSuffix = ' (प्रश्न ${widget.startQNum})';
      } else {
        qRangeSuffix = ' (प्रश्न ${widget.startQNum}–${widget.endQNum})';
      }
    } else {
      qRangeSuffix = '';
    }

    // Theme tokens
    final headerBg = isPoem
        ? (isDark ? const Color(0xFF2E1065).withValues(alpha: 0.6) : const Color(0xFFF5F3FF))
        : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.8) : const Color(0xFFEFF6FF));

    final borderColor = isPoem
        ? (isDark ? const Color(0xFF6B21A8) : const Color(0xFFDDD6FE))
        : (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE));

    final badgeColor = isPoem
        ? (isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));

    final badgeBg = badgeColor.withValues(alpha: isDark ? 0.2 : 0.12);

    final titleText = isPoem
        ? 'अपठित काव्यांश / कविता$qRangeSuffix'
        : 'अपठित गद्यांश$qRangeSuffix';

    final cardBg = isDark ? const Color(0xFF131B2E) : Colors.white;

    // Compact reference bar (used for subsequent questions in booklet mode)
    if (widget.isCompactReference && !_isExpanded) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: AppRadius.roundedBase,
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.roundedBase,
            onTap: () => setState(() => _isExpanded = true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    isPoem ? Icons.auto_stories_rounded : Icons.menu_book_rounded,
                    size: 18,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPoem
                          ? '📖 इस प्रश्न की कविता देखें$qRangeSuffix (टैप करें)'
                          : '📖 इस प्रश्न का गद्यांश देखें$qRangeSuffix (टैप करें)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: badgeColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: AppRadius.roundedBase,
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar with Tap to Collapse/Expand
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius: _isExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(10))
                      : AppRadius.roundedBase,
                  border: _isExpanded
                      ? Border(bottom: BorderSide(color: borderColor, width: 0.8))
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: AppRadius.roundedSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPoem ? Icons.auto_stories_rounded : Icons.menu_book_rounded,
                            size: 14,
                            color: badgeColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            titleText,
                            style: AppTypography.labelSmall(color: badgeColor).copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.seqInPassage != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'प्रश्न ${widget.seqInPassage}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Collapsible Content
          if (_isExpanded) ...[
            // Directive Instructions
            if (widget.passage.cleanDirText.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Text(
                  widget.passage.cleanDirText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
            ],

            // Body
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isPoem ? 20 : 16,
                vertical: isPoem ? 16 : 14,
              ),
              decoration: BoxDecoration(
                color: isPoem
                    ? (isDark ? const Color(0xFF1E1430).withValues(alpha: 0.5) : const Color(0xFFFCFAFF))
                    : (isDark ? const Color(0xFF0F172A).withValues(alpha: 0.3) : const Color(0xFFFFFFFF)),
              ),
              child: SelectableText(
                widget.passage.cleanBody,
                textAlign: isPoem ? TextAlign.center : TextAlign.justify,
                style: TextStyle(
                  fontSize: isPoem ? 16.0 : 15.0,
                  height: isPoem ? 2.0 : 1.7,
                  fontStyle: isPoem ? FontStyle.italic : FontStyle.normal,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                  letterSpacing: isPoem ? 0.3 : 0.1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Helper class to resolve Passage instances synchronously and asynchronously
class PassageResolver {
  static final Map<String, Passage> _memoryCache = {};

  static Future<Passage?> getPassageAsync(String? passageId, {Map<String, Passage>? sessionPassages}) async {
    if (passageId == null || passageId.trim().isEmpty) return null;
    final pid = passageId.trim();

    // 1. Check session passages
    if (sessionPassages != null && sessionPassages.containsKey(pid)) {
      return sessionPassages[pid];
    }

    // 2. Check memory cache
    if (_memoryCache.containsKey(pid)) {
      return _memoryCache[pid];
    }

    // 3. Check official pyq repository hardcoded passages
    final repoPassage = OfficialPyqRepository.allPassages[pid];
    if (repoPassage != null) {
      _memoryCache[pid] = repoPassage;
      return repoPassage;
    }

    // 4. Query SQLite database
    try {
      final dbPassage = await DbHelper.instance.getPassage(pid);
      if (dbPassage != null) {
        _memoryCache[pid] = dbPassage;
        return dbPassage;
      }
    } catch (_) {}

    return null;
  }

  static Passage? getPassageSync(String? passageId, {Map<String, Passage>? sessionPassages}) {
    if (passageId == null || passageId.trim().isEmpty) return null;
    final pid = passageId.trim();

    if (sessionPassages != null && sessionPassages.containsKey(pid)) {
      return sessionPassages[pid];
    }
    if (_memoryCache.containsKey(pid)) {
      return _memoryCache[pid];
    }
    final repoPassage = OfficialPyqRepository.allPassages[pid];
    if (repoPassage != null) {
      _memoryCache[pid] = repoPassage;
      return repoPassage;
    }
    return null;
  }
}
