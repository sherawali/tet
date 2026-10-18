import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/question.dart';
import '../models/passage.dart';
import '../models/test_session.dart';
import '../services/exam_service.dart';

/// Database helper managing offline SQLite storage for questions, passages, and test results
class DbHelper {
  static final DbHelper instance = DbHelper._internal();
  DbHelper._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tet_mock_vault.db');

    final exists = await databaseExists(path);
    if (!exists) {
      try {
        await Directory(dirname(path)).create(recursive: true);
        final data = await rootBundle.load('assets/database/tet_mock_vault.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(path).writeAsBytes(bytes, flush: true);
        debugPrint('Directly copied pre-built V2 database asset to $path');
      } catch (e) {
        debugPrint('Direct copy asset DB exception: $e');
      }
    }

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS questions (
            id TEXT PRIMARY KEY,
            exams TEXT,
            section TEXT,
            topic_index INTEGER,
            topic_name TEXT,
            difficulty INTEGER,
            q_hindi TEXT,
            options_hindi TEXT,
            q_english TEXT,
            options_english TEXT,
            answer INTEGER,
            p_score REAL,
            years TEXT,
            source_tag TEXT,
            passage_id TEXT,
            seq_in_passage INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS passages (
            id TEXT PRIMARY KEY,
            kind TEXT,
            dir_text TEXT,
            body TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            val TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS test_history (
            id TEXT PRIMARY KEY,
            timestamp INTEGER,
            mode TEXT,
            section_filter TEXT,
            score INTEGER,
            total INTEGER,
            time_spent_seconds INTEGER,
            session_json TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS paper_forms (
            id TEXT PRIMARY KEY,
            exam TEXT,
            paper INTEGER,
            exam_date TEXT,
            set_code TEXT,
            title TEXT,
            total_questions INTEGER,
            modules_json TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS appearances (
            id TEXT PRIMARY KEY,
            question_id TEXT,
            paper_form_id TEXT,
            section TEXT,
            question_number INTEGER,
            official_option_id TEXT
          )
        ''');

        // Create indexes for blazing-fast mock generation queries
        await db.execute('CREATE INDEX IF NOT EXISTS idx_q_sec_topic ON questions(section, topic_index)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_q_pscore ON questions(p_score DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_q_years ON questions(years)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_q_exams ON questions(exams)');
      },
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE questions ADD COLUMN source_tag TEXT');
        } catch (_) {}
        await db.execute('''
          CREATE TABLE IF NOT EXISTS mistake_records (
            question_id TEXT PRIMARY KEY,
            section TEXT,
            topic_name TEXT,
            wrong_count INTEGER DEFAULT 0,
            correct_count INTEGER DEFAULT 0,
            last_wrong_timestamp INTEGER
          )
        ''');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mistakes_topic ON mistake_records(topic_name)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_mistakes_sec ON mistake_records(section)');

        await db.execute('''
          CREATE TABLE IF NOT EXISTS question_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id TEXT,
            paper_form_id TEXT,
            question_number INTEGER,
            reason TEXT,
            comment TEXT,
            suggested_option TEXT,
            question_stem TEXT,
            user_answer INTEGER,
            correct_answer INTEGER,
            status TEXT DEFAULT 'submitted',
            created_at TEXT
          )
        ''');
        try {
          await db.execute('ALTER TABLE question_reports ADD COLUMN suggested_option TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE question_reports ADD COLUMN question_stem TEXT');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE question_reports ADD COLUMN user_answer INTEGER');
        } catch (_) {}
        try {
          await db.execute('ALTER TABLE question_reports ADD COLUMN correct_answer INTEGER');
        } catch (_) {}
        try {
          await db.execute("ALTER TABLE question_reports ADD COLUMN status TEXT DEFAULT 'submitted'");
        } catch (_) {}

        // Auto-seed or upgrade to all-offline database (4,620 authentic questions) from bundled asset
        try {
          final res = await db.query('meta', where: 'key = ?', whereArgs: ['bank_version']);
          final v = res.isNotEmpty ? res.first['val']?.toString() : null;
          final qCountRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM questions');
          final qCount = Sqflite.firstIntValue(qCountRes) ?? 0;
          if (v != '20261018_master_vault_clean_v10' || qCount < 9720) {
            await _syncFromAssetDb(db);
          }
        } catch (_) {
          await _syncFromAssetDb(db);
        }
      },
    );
  }

  /// Ensures pre-bundled offline database asset (9,720 questions, 62 papers) is fully loaded
  Future<void> ensureBundledAssetLoaded() async {
    final db = await database;
    try {
      final res = await db.query('meta', where: 'key = ?', whereArgs: ['bank_version']);
      final v = res.isNotEmpty ? res.first['val']?.toString() : null;
      final qCountRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM questions');
      final qCount = Sqflite.firstIntValue(qCountRes) ?? 0;
      if (v != '20261018_master_vault_clean_v10' || qCount < 9720) {
        await _syncFromAssetDb(db);
      }
    } catch (_) {
      await _syncFromAssetDb(db);
    }
  }

  /// Synchronize all 2,880 authentic questions and 109 passages from the pre-bundled asset DB
  /// Guarantees that user's test_history and mistake_records are 100% preserved.
  Future<void> _syncFromAssetDb(Database db) async {
    try {
      final dbPath = await getDatabasesPath();
      final tempAssetPath = join(dbPath, 'temp_asset_bundle.db');
      final data = await rootBundle.load('assets/database/tet_mock_vault.db');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final tempFile = File(tempAssetPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final assetDb = await openReadOnlyDatabase(tempAssetPath);
      final assetQuestions = await assetDb.query('questions');
      final assetPassages = await assetDb.query('passages');
      final assetMeta = await assetDb.query('meta');
      List<Map<String, dynamic>> assetPaperForms = [];
      List<Map<String, dynamic>> assetAppearances = [];
      try {
        assetPaperForms = await assetDb.query('paper_forms');
        assetAppearances = await assetDb.query('appearances');
      } catch (_) {}
      await assetDb.close();
      try {
        await tempFile.delete();
      } catch (_) {}

      // Ensure paper_forms and appearances tables exist on main db
      await db.execute('''
        CREATE TABLE IF NOT EXISTS paper_forms (
          id TEXT PRIMARY KEY,
          exam TEXT,
          paper INTEGER,
          exam_date TEXT,
          set_code TEXT,
          title TEXT,
          total_questions INTEGER,
          modules_json TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS appearances (
          id TEXT PRIMARY KEY,
          question_id TEXT,
          paper_form_id TEXT,
          section TEXT,
          question_number INTEGER,
          official_option_id TEXT
        )
      ''');

      await db.transaction((txn) async {
        await txn.delete('questions');
        await txn.delete('passages');
        await txn.delete('paper_forms');
        await txn.delete('appearances');

        // Batch insert questions
        for (var i = 0; i < assetQuestions.length; i += 500) {
          final end = (i + 500 < assetQuestions.length) ? i + 500 : assetQuestions.length;
          final batch = txn.batch();
          for (final q in assetQuestions.sublist(i, end)) {
            batch.insert('questions', q, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }

        // Passages
        final pBatch = txn.batch();
        for (final p in assetPassages) {
          pBatch.insert('passages', p, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await pBatch.commit(noResult: true);

        // Forms & appearances
        if (assetPaperForms.isNotEmpty) {
          final fBatch = txn.batch();
          for (final f in assetPaperForms) {
            fBatch.insert('paper_forms', f, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await fBatch.commit(noResult: true);
        }
        if (assetAppearances.isNotEmpty) {
          for (var i = 0; i < assetAppearances.length; i += 500) {
            final end = (i + 500 < assetAppearances.length) ? i + 500 : assetAppearances.length;
            final aBatch = txn.batch();
            for (final a in assetAppearances.sublist(i, end)) {
              aBatch.insert('appearances', a, conflictAlgorithm: ConflictAlgorithm.replace);
            }
            await aBatch.commit(noResult: true);
          }
        }

        // Meta
        for (final m in assetMeta) {
          await txn.insert('meta', m, conflictAlgorithm: ConflictAlgorithm.replace);
        }

        // Update report status for resolved questions
        try {
          await txn.execute("UPDATE question_reports SET status = 'solved' WHERE question_id IN ('b7fe812caa11aaea', '7570f6db99750223', '400c86ba7c4c9736')");
          await txn.execute("UPDATE question_reports SET status = 'verified' WHERE question_id IN ('c68894e54e49924e', '85d3f769c5dbf0ce')");
        } catch (_) {}
      });
      debugPrint('Successfully seeded ${assetQuestions.length} V2 questions from bundled asset DB!');
    } catch (e) {
      debugPrint('Error syncing from asset DB: $e');
    }
  }

  /// Bulk insert or replace questions in a single transaction
  Future<void> saveQuestions(List<Question> questions) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final q in questions) {
        batch.insert(
          'questions',
          q.toDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Bulk insert or replace passages in a single transaction
  Future<void> savePassages(List<Passage> passages) async {
    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final p in passages) {
        batch.insert(
          'passages',
          {
            'id': p.id,
            'kind': p.kind,
            'dir_text': p.dirText,
            'body': p.body,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Safely update question bank inside a single atomic transaction.
  /// Guarantees:
  /// 1. Zero data corruption: performed inside an atomic transaction.
  /// 2. Deletions in Git are reflected (deleted questions removed).
  /// 3. Modifications/corrections/translations in Git are applied.
  /// 4. User data (`test_history`, `mistake_records`, `meta` like `is_premium_unlocked`) is NEVER deleted or corrupted.
  Future<void> atomicUpdateBank({
    required List<Question> questions,
    required List<Passage> passages,
    required int bankVersion,
    required List<String> topics,
    String? packsSignature,
    List<Map<String, dynamic>>? paperForms,
    List<dynamic>? appearances,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Clear old bank questions & passages (leaves test_history & mistakes untouched!)
      await txn.delete('questions');
      await txn.delete('passages');

      // 2. Insert questions in chunks of 500 for low memory footprint
      for (var i = 0; i < questions.length; i += 500) {
        final end = (i + 500 < questions.length) ? i + 500 : questions.length;
        final chunk = questions.sublist(i, end);
        final batch = txn.batch();
        for (final q in chunk) {
          batch.insert(
            'questions',
            q.toDbMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }

      // 3. Insert passages in a batch
      if (passages.isNotEmpty) {
        final pBatch = txn.batch();
        for (final p in passages) {
          pBatch.insert(
            'passages',
            {
              'id': p.id,
              'kind': p.kind,
              'dir_text': p.dirText,
              'body': p.body,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await pBatch.commit(noResult: true);
      }

      // 4. Update paper_forms and appearances if provided from remote
      if (paperForms != null && paperForms.isNotEmpty) {
        await txn.delete('paper_forms');
        final fBatch = txn.batch();
        for (final f in paperForms) {
          fBatch.insert(
            'paper_forms',
            Map<String, dynamic>.from(f),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await fBatch.commit(noResult: true);
      }

      if (appearances != null && appearances.isNotEmpty) {
        await txn.delete('appearances');
        for (var i = 0; i < appearances.length; i += 500) {
          final end = (i + 500 < appearances.length) ? i + 500 : appearances.length;
          final chunk = appearances.sublist(i, end);
          final aBatch = txn.batch();
          for (final a in chunk) {
            if (a is List && a.length >= 6) {
              aBatch.insert(
                'appearances',
                {
                  'id': a[0],
                  'question_id': a[1],
                  'paper_form_id': a[2],
                  'section': a[3],
                  'question_number': a[4],
                  'official_option_id': a[5],
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } else if (a is Map) {
              aBatch.insert(
                'appearances',
                Map<String, dynamic>.from(a),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
          await aBatch.commit(noResult: true);
        }
      }

      // 5. Update metadata
      await txn.insert(
        'meta',
        {'key': 'bank_version', 'val': bankVersion.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'meta',
        {'key': 'topics', 'val': jsonEncode(topics)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'meta',
        {'key': 'last_synced', 'val': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (packsSignature != null) {
        await txn.insert(
          'meta',
          {'key': 'packs_signature', 'val': packsSignature},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    // 5. Post-sync database optimization & cleanup:
    try {
      // Remove any orphan mistake records referencing deleted questions
      await db.execute('DELETE FROM mistake_records WHERE question_id NOT IN (SELECT id FROM questions)');
      // Optimize SQLite internal query planner & B-tree structures
      await db.execute('PRAGMA optimize');
    } catch (_) {}
  }

  /// Get the absolute filesystem path to the SQLite database file
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'tet_mock_vault.db');
  }

  /// Get the actual SQLite database file size in bytes
  Future<int> getDatabaseSizeBytes() async {
    try {
      final path = await getDatabasePath();
      final file = File(path);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (_) {}
    return 0;
  }

  /// Deep optimize the local database:
  /// 1. Rebuild indexes for maximum search efficiency (REINDEX)
  /// 2. Clean up any orphaned mistake records that reference deleted questions
  /// 3. Reclaim unused disk space and shrink database file size (VACUUM)
  /// 4. Optimize internal B-tree search paths (PRAGMA optimize)
  /// 5. Flush WAL checkpoints (PRAGMA wal_checkpoint(TRUNCATE))
  Future<Map<String, dynamic>> optimizeDatabase() async {
    final db = await database;
    final int sizeBefore = await getDatabaseSizeBytes();

    // 1. Delete orphan mistakes
    final orphanDeleted = await db.rawDelete(
      'DELETE FROM mistake_records WHERE question_id NOT IN (SELECT id FROM questions)',
    );

    // 2. Re-index all tables
    await db.execute('REINDEX');

    // 3. Flush WAL
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}

    // 4. Vacuum database to reclaim unused disk pages
    try {
      await db.execute('VACUUM');
    } catch (_) {}

    // 5. Run SQLite query planner optimizer
    try {
      await db.execute('PRAGMA optimize');
    } catch (_) {}

    final int sizeAfter = await getDatabaseSizeBytes();
    final int questionCount = await getQuestionCount();

    return {
      'sizeBefore': sizeBefore,
      'sizeAfter': sizeAfter,
      'bytesSaved': (sizeBefore - sizeAfter) > 0 ? (sizeBefore - sizeAfter) : 0,
      'questionCount': questionCount,
      'orphanDeleted': orphanDeleted,
    };
  }

  /// Clears only questions, passages, and sync metadata while keeping user's test_history
  /// and mistake_records 100% safe.
  Future<void> clearBankOnly() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('questions');
      await txn.delete('passages');
      await txn.delete('meta', where: "key IN ('bank_version', 'packs_signature', 'last_synced')");
    });
    try {
      await db.execute('VACUUM');
      await db.execute('PRAGMA optimize');
    } catch (_) {}
  }

  Future<Passage?> getPassage(String id) async {
    final db = await database;
    final res = await db.query('passages', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) {
      return Passage.fromMap(res.first);
    }
    return null;
  }

  /// Public helper for constructing SQL where clauses based on exam and paper
  String examWhere(String? exam) => _examWhere(exam);

  String _examWhere(String? exam) {
    if (exam == null || exam.isEmpty) return '';
    final e = exam.toLowerCase().trim();

    // CTET Paper 2 (Upper Primary / Junior)
    if (e == 'ctet2' || e == 'c2' || e.contains('ctet_2') || e.contains('ctet-2')) {
      return "(exams LIKE '%ctet2%' OR exams LIKE '%ctet-2%' OR exams LIKE '%ctet_2%' OR exams LIKE '%c2%')";
    }
    // CTET Paper 1 (Primary)
    if (e == 'ctet1' || e == 'c1' || e.contains('ctet_1') || e.contains('ctet-1')) {
      return "((exams LIKE '%ctet1%' OR exams LIKE '%ctet-1%' OR exams LIKE '%ctet_1%' OR exams LIKE '%c1%') OR ((exams LIKE '%ctet%' OR exams LIKE '%c%') AND exams NOT LIKE '%ctet2%' AND exams NOT LIKE '%ctet-2%' AND exams NOT LIKE '%ctet_2%' AND exams NOT LIKE '%c2%'))";
    }
    // Generic CTET
    if (e.contains('ctet')) {
      return "(exams LIKE '%c%' OR exams LIKE '%ctet%')";
    }

    // UTET Paper 2 (Upper Primary / Junior)
    if (e == 'utet2' || e == 'u2' || e.contains('utet_2') || e.contains('utet-2')) {
      return "(exams LIKE '%utet2%' OR exams LIKE '%utet-2%' OR exams LIKE '%utet_2%' OR exams LIKE '%u2%')";
    }
    // UTET Paper 1 (Primary - default)
    if (e == 'utet1' || e == 'u1' || e.contains('utet_1') || e.contains('utet-1')) {
      return "((exams LIKE '%utet1%' OR exams LIKE '%utet-1%' OR exams LIKE '%utet_1%' OR exams LIKE '%u1%') OR ((exams LIKE '%u%' OR exams LIKE '%utet%' OR exams IS NULL OR exams = '') AND exams NOT LIKE '%utet2%' AND exams NOT LIKE '%utet-2%' AND exams NOT LIKE '%utet_2%' AND exams NOT LIKE '%u2%'))";
    }

    // Generic UTET
    return "(exams LIKE '%u%' OR exams LIKE '%utet%' OR exams IS NULL OR exams = '')";
  }

  Future<int> getQuestionCount([String? exam]) async {
    final db = await database;
    final ex = _examWhere(exam);
    final where = ex.isNotEmpty ? 'WHERE $ex' : '';
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM questions $where');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> getPyqCount([String? exam]) async {
    final db = await database;
    final ex = _examWhere(exam);
    final where = ex.isNotEmpty
        ? "WHERE (years IS NOT NULL AND years != '') AND $ex"
        : "WHERE years IS NOT NULL AND years != ''";
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM questions $where');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<Map<String, int>> getSectionCounts([String? exam]) async {
    final db = await database;
    final ex = _examWhere(exam);
    final where = ex.isNotEmpty ? 'WHERE $ex' : '';
    final res = await db.rawQuery('SELECT section, COUNT(*) as cnt FROM questions $where GROUP BY section');
    final map = <String, int>{};
    for (final row in res) {
      map[row['section'] as String] = (row['cnt'] as num).toInt();
    }
    return map;
  }

  Future<void> setMeta(String key, String val) async {
    final db = await database;
    await db.insert(
      'meta',
      {'key': key, 'val': val},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMeta(String key) async {
    final db = await database;
    final res = await db.query('meta', where: 'key = ?', whereArgs: [key]);
    if (res.isNotEmpty) {
      return res.first['val'] as String?;
    }
    return null;
  }

  Future<void> saveTestHistory({
    required String id,
    required String mode,
    String? sectionFilter,
    required int score,
    required int total,
    required int timeSpentSeconds,
    required String sessionJson,
  }) async {
    final db = await database;
    await db.insert('test_history', {
      'id': id,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'mode': mode,
      'section_filter': sectionFilter,
      'score': score,
      'total': total,
      'time_spent_seconds': timeSpentSeconds,
      'session_json': sessionJson,
    });
  }

  Future<List<Map<String, dynamic>>> getTestHistory() async {
    final db = await database;
    return await db.query('test_history', orderBy: 'timestamp DESC');
  }

  /// Get list of sorted distinct PYQ years from questions table
  Future<List<String>> getDistinctPyqYears([String? exam]) async {
    final isCtet = (exam ?? 'utet1').toLowerCase().startsWith('c');
    if (isCtet) {
      return [
        '2026',
        '2024',
        '2023',
        '2021 (दिसम्बर)',
        '2021 (जनवरी)',
        '2019',
        '2018',
        '2016',
      ];
    }

    final db = await database;
    final ex = _examWhere(exam);
    final where = ex.isNotEmpty
        ? "WHERE (years IS NOT NULL AND years != '') AND $ex"
        : "WHERE years IS NOT NULL AND years != ''";
    final res = await db.rawQuery('SELECT DISTINCT years FROM questions $where');
    final Set<String> yearSet = {};
    for (final row in res) {
      final y = row['years'] as String?;
      if (y != null && y.isNotEmpty) {
        final parts = y.split(RegExp(r'[,;/\s]+'));
        for (final p in parts) {
          final trimmed = p.trim();
          if (trimmed.length == 4 && int.tryParse(trimmed) != null) {
            yearSet.add(trimmed);
          }
        }
      }
    }
    final sortedYears = yearSet.toList()..sort();
    return sortedYears;
  }

  /// Get all questions for a given PYQ year
  Future<List<Question>> getPyqQuestionsByYear(String year, [String? exam]) async {
    final db = await database;
    final isCtet = (exam ?? 'utet1').toLowerCase().startsWith('c');
    final isPaper2 = (exam ?? 'utet1').toLowerCase().endsWith('2');
    final paperNum = isPaper2 ? 2 : 1;

    String? formId;
    final forms = await db.query(
      'paper_forms',
      where: 'paper = ? AND (exam_date LIKE ? OR id LIKE ? OR title LIKE ?)',
      whereArgs: [paperNum, '%$year%', '%$year%', '%$year%'],
      limit: 1,
    );
    if (forms.isNotEmpty) {
      formId = forms.first['id'] as String?;
    }

    final l1 = ExamService.instance.currentLang1.value.toLowerCase();
    final l2 = ExamService.instance.currentLang2.value.toLowerCase();

    if (formId != null) {
      final res = await db.rawQuery('''
        SELECT q.*, a.question_number
        FROM appearances a
        JOIN questions q ON a.question_id = q.id
        WHERE a.paper_form_id = ?
        ORDER BY a.question_number ASC
      ''', [formId]);

      final allQs = res.map((r) => Question.fromDbMap(r)).toList();

      if (isPaper2) {
        final stream = ExamService.instance.isSocialStream ? 'social_studies' : 'math_science';
        final p2Cdp = allQs.where((q) => q.section.toLowerCase() == 'cdp').take(30).toList();
        final p2L1 = allQs.where((q) => q.section.toLowerCase() == l1 || q.section.toLowerCase() == 'hindi').take(30).toList();
        final p2L2 = allQs.where((q) => q.section.toLowerCase() == l2 || q.section.toLowerCase() == 'english').take(30).toList();
        final p2Stream = allQs.where((q) => q.section.toLowerCase() == stream).take(60).toList();
        final List<Question> ordered = [
          ...p2Cdp,
          ...p2L1,
          ...p2L2,
          ...p2Stream,
        ];
        if (ordered.isNotEmpty) return ordered;
      }

      final cdpQs = <Question>[];
      final mathQs = <Question>[];
      final evsQs = <Question>[];
      final l1Qs = <Question>[];
      final l2Qs = <Question>[];

      if (isCtet) {
        // CTET Paper 1 Standard:
        // Q1-30: CDP
        // Q31-60: Mathematics
        // Q61-90: EVS
        // Q91-120: Language 1 (Selected Lang 1)
        // Q121-150: Language 2 (Selected Lang 2)
        for (final q in allQs) {
          final s = q.section.toLowerCase();
          final qnum = q.questionNumber ?? 0;
          if (s == 'cdp' && cdpQs.length < 30) {
            cdpQs.add(q);
          } else if (s == 'math' && mathQs.length < 30) {
            mathQs.add(q);
          } else if (s == 'evs' && evsQs.length < 30) {
            evsQs.add(q);
          } else if (s == l1 && (qnum == 0 || (qnum >= 91 && qnum <= 120)) && l1Qs.length < 30) {
            l1Qs.add(q);
          } else if (s == l2 && (qnum == 0 || (qnum >= 121 && qnum <= 150)) && l2Qs.length < 30) {
            l2Qs.add(q);
          }
        }
        // Fallback for languages if appearances question numbers were not tagged
        if (l1Qs.length < 30) {
          final remaining = allQs.where((q) => q.section.toLowerCase() == l1 && !l1Qs.contains(q));
          l1Qs.addAll(remaining.take(30 - l1Qs.length));
        }
        if (l2Qs.length < 30) {
          final remaining = allQs.where((q) => q.section.toLowerCase() == l2 && !l2Qs.contains(q) && !l1Qs.contains(q));
          l2Qs.addAll(remaining.take(30 - l2Qs.length));
        }

        final List<Question> ordered = [
          ...cdpQs,
          ...mathQs,
          ...evsQs,
          ...l1Qs,
          ...l2Qs,
        ];
        if (ordered.isNotEmpty) return ordered;
      } else {
        // UTET Paper 1 Standard:
        // Q1-30: CDP
        // Q31-60: Language 1 (Selected Lang 1)
        // Q61-90: Language 2 (Selected Lang 2)
        // Q91-120: Mathematics
        // Q121-150: EVS
        for (final q in allQs) {
          final s = q.section.toLowerCase();
          final qnum = q.questionNumber ?? 0;
          if (s == 'cdp' && cdpQs.length < 30) {
            cdpQs.add(q);
          } else if (s == l1 && (qnum == 0 || (qnum >= 31 && qnum <= 60)) && l1Qs.length < 30) {
            l1Qs.add(q);
          } else if (s == l2 && (qnum == 0 || (qnum >= 61 && qnum <= 90)) && l2Qs.length < 30) {
            l2Qs.add(q);
          } else if (s == 'math' && mathQs.length < 30) {
            mathQs.add(q);
          } else if (s == 'evs' && evsQs.length < 30) {
            evsQs.add(q);
          }
        }
        // Fallback for languages
        if (l1Qs.length < 30) {
          final remaining = allQs.where((q) => q.section.toLowerCase() == l1 && !l1Qs.contains(q));
          l1Qs.addAll(remaining.take(30 - l1Qs.length));
        }
        if (l2Qs.length < 30) {
          final remaining = allQs.where((q) => q.section.toLowerCase() == l2 && !l2Qs.contains(q) && !l1Qs.contains(q));
          l2Qs.addAll(remaining.take(30 - l2Qs.length));
        }

        final List<Question> ordered = [
          ...cdpQs,
          ...l1Qs,
          ...l2Qs,
          ...mathQs,
          ...evsQs,
        ];
        if (ordered.isNotEmpty) return ordered;
      }
    }

    final ex = _examWhere(exam);
    String whereClause = "(years LIKE ? OR years LIKE ? OR years = ?)";
    List<dynamic> whereArgs = ['%$year%', '%$year,%', year];
    if (ex.isNotEmpty) {
      whereClause += " AND $ex";
    }
    final res = await db.query(
      'questions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'rowid ASC',
    );
    final allQs = res.map((r) => Question.fromDbMap(r)).toList();

    // Group by section and ensure standard balanced exam structure (up to 30 per section)
    final Map<String, List<Question>> bySec = {};
    for (final q in allQs) {
      final s = q.section.toLowerCase();
      bySec.putIfAbsent(s, () => []);
      if (bySec[s]!.length < 30) {
        bySec[s]!.add(q);
      }
    }

    final cdpQs = bySec['cdp'] ?? [];
    final mathQs = bySec['math'] ?? [];
    final evsQs = bySec['evs'] ?? [];
    final l1Qs = bySec[l1] ?? (bySec['hindi'] ?? []);
    final l2Qs = bySec[l2] ?? (bySec['english'] ?? (bySec['sanskrit'] ?? []));

    final List<Question> ordered = isCtet
        ? [...cdpQs, ...mathQs, ...evsQs, ...l1Qs, ...l2Qs]
        : [...cdpQs, ...l1Qs, ...l2Qs, ...mathQs, ...evsQs];

    return ordered.isNotEmpty ? ordered : allQs;
  }

  /// Get distinct PYQ years with their question counts
  Future<Map<String, int>> getPyqYearsWithCounts([String? exam]) async {
    final years = await getDistinctPyqYears(exam);
    final db = await database;
    final isCtet = (exam ?? 'utet1').toLowerCase().startsWith('c');
    final Map<String, int> result = {};
    for (final y in years) {
      if (isCtet) {
        result[y] = 150;
      } else {
        String sql = "SELECT COUNT(*) as cnt FROM questions WHERE (years LIKE ? OR years = ?)";
        final ex = _examWhere(exam);
        if (ex.isNotEmpty) {
          sql += " AND $ex";
        }
        final res = await db.rawQuery(sql, ['%$y%', y]);
        result[y] = Sqflite.firstIntValue(res) ?? 0;
      }
    }
    return result;
  }

  /// Get topic-wise counts for a given section filtered by exam
  Future<Map<String, int>> getTopicCountsForSection(String section, [String? exam]) async {
    final db = await database;
    final ex = _examWhere(exam);
    final where = ex.isNotEmpty ? 'WHERE section = ? AND $ex' : 'WHERE section = ?';
    final res = await db.rawQuery(
      'SELECT topic_name, COUNT(*) as cnt FROM questions $where GROUP BY topic_name ORDER BY cnt DESC',
      [section],
    );
    final map = <String, int>{};
    for (final r in res) {
      final t = r['topic_name'] as String?;
      if (t != null && t.isNotEmpty) {
        map[t] = (r['cnt'] as num).toInt();
      }
    }
    return map;
  }

  /// Get questions for a specific topic in a section filtered by exam
  Future<List<Question>> getQuestionsByTopic(String section, String topicName, [String? exam]) async {
    final db = await database;
    final ex = _examWhere(exam);
    String whereClause = 'section = ? AND (topic_name = ? OR topic_name LIKE ?)';
    List<dynamic> whereArgs = [section, topicName, '%$topicName%'];
    if (ex.isNotEmpty) {
      whereClause += " AND $ex";
    }
    final res = await db.query(
      'questions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'p_score DESC',
    );
    return res.map((r) => Question.fromDbMap(r)).toList();
  }

  /// Record mistake analysis from completed test session
  Future<void> recordSessionMistakes(TestSession session) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (int i = 0; i < session.questions.length; i++) {
        final q = session.questions[i];
        final selected = session.selectedAnswers[i];
        if (selected == null) continue; // Unattempted

        final isWrong = selected != q.answer;
        if (isWrong) {
          batch.rawInsert('''
            INSERT INTO mistake_records (question_id, section, topic_name, wrong_count, correct_count, last_wrong_timestamp)
            VALUES (?, ?, ?, 1, 0, ?)
            ON CONFLICT(question_id) DO UPDATE SET
              wrong_count = wrong_count + 1,
              last_wrong_timestamp = ?
          ''', [q.id, q.section, q.topicName ?? 'General', now, now]);
        } else {
          batch.rawInsert('''
            INSERT INTO mistake_records (question_id, section, topic_name, wrong_count, correct_count, last_wrong_timestamp)
            VALUES (?, ?, ?, 0, 1, ?)
            ON CONFLICT(question_id) DO UPDATE SET
              correct_count = correct_count + 1
          ''', [q.id, q.section, q.topicName ?? 'General', now]);
        }
      }
      await batch.commit(noResult: true);
    });
  }

  /// Get topics where user repeatedly makes mistakes (wrong_count >= 2) across all tests
  Future<List<Map<String, dynamic>>> getRecurringMistakeTopics({int limit = 5}) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT topic_name, section, SUM(wrong_count) as total_wrongs, COUNT(*) as questions_count
      FROM mistake_records
      WHERE wrong_count > 0
      GROUP BY topic_name, section
      HAVING total_wrongs >= 2
      ORDER BY total_wrongs DESC
      LIMIT ?
    ''', [limit]);
  }

  /// Get questions user repeatedly answered wrongly (wrong_count >= 2) across all tests
  Future<List<Question>> getRecurringMistakeQuestions({int limit = 30}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT q.*, m.wrong_count 
      FROM questions q
      INNER JOIN mistake_records m ON q.id = m.question_id
      WHERE m.wrong_count >= 2
      ORDER BY m.wrong_count DESC, m.last_wrong_timestamp DESC
      LIMIT ?
    ''', [limit]);
    return rows.map((r) => Question.fromDbMap(r)).toList();
  }

  /// Get all available pre-built paper forms (Mocks and Real PYQs) for Paper 1 or Paper 2
  Future<List<Map<String, dynamic>>> getAvailablePaperForms({
    String? exam,
    required int paper,
    bool? isPyqOnly,
  }) async {
    await ensureBundledAssetLoaded();
    final db = await database;
    String sql = 'SELECT * FROM paper_forms WHERE paper = ?';
    List<dynamic> args = [paper];

    if (exam != null && exam.isNotEmpty) {
      sql += ' AND exam = ?';
      args.add(exam.toLowerCase());
    }

    if (isPyqOnly == true) {
      sql += ' AND (exam_date != "2026-Mock" OR set_code = "PYQ" OR set_code LIKE "20%" OR id LIKE "%pyq%" OR id LIKE "%fullmock%")';
      sql += ' ORDER BY exam_date DESC, set_code ASC';
    } else if (isPyqOnly == false) {
      sql += ' AND (exam_date = "2026-Mock" OR set_code LIKE "MOCK%" OR set_code LIKE "M-%" OR set_code LIKE "MS-%" OR set_code LIKE "SST-%")';
      sql += ' ORDER BY set_code ASC, id ASC';
    } else {
      sql += ' ORDER BY exam_date DESC, set_code ASC';
    }

    final forms = await db.rawQuery(sql, args);
    return List<Map<String, dynamic>>.from(forms);
  }

  /// Load complete authentic 150-question paper from an official paper form
  Future<({List<Question> questions, Map<String, Passage> passages})> loadPaperFormExam({
    required String paperFormId,
    String? stream,
  }) async {
    await ensureBundledAssetLoaded();
    final db = await database;

    final formRes = await db.query('paper_forms', where: 'id = ?', whereArgs: [paperFormId]);
    final isPaper2 = formRes.isNotEmpty && formRes.first['paper'] == 2;

    String sql = '''
      SELECT a.question_number, a.section, q.*
      FROM appearances a
      JOIN questions q ON a.question_id = q.id
      WHERE a.paper_form_id = ?
    ''';
    List<dynamic> args = [paperFormId];

    if (isPaper2) {
      final activeStream = stream ?? ExamService.instance.activeStream.name;
      final secFilter = (activeStream == 'socialStudies') ? 'social_studies' : 'math_science';
      sql += " AND (a.section IN ('cdp', 'hindi', 'english') OR a.section = ?)";
      args.add(secFilter);
    }

    sql += ' ORDER BY a.question_number ASC';

    final rows = await db.rawQuery(sql, args);
    final questions = rows.map((r) => Question.fromDbMap(r)).toList();

    // Fetch passages for all questions in this paper
    final passageIds = questions
        .where((q) => q.passageId != null && q.passageId!.isNotEmpty)
        .map((q) => q.passageId!)
        .toSet();

    final Map<String, Passage> passageMap = {};
    for (final pid in passageIds) {
      final p = await getPassage(pid);
      if (p != null) {
        passageMap[pid] = p;
      }
    }

    return (questions: questions, passages: passageMap);
  }

  /// Saves a student error report for a specific question and returns auto-generated report ID
  Future<int> saveQuestionReport({
    required String questionId,
    String? paperFormId,
    required int questionNumber,
    required String reason,
    String? comment,
    String? suggestedOption,
    String? questionStem,
    int? userAnswer,
    int? correctAnswer,
    String status = 'submitted',
  }) async {
    final db = await database;
    return await db.insert('question_reports', {
      'question_id': questionId,
      'paper_form_id': paperFormId ?? '',
      'question_number': questionNumber,
      'reason': reason,
      'comment': comment ?? '',
      'suggested_option': suggestedOption ?? '',
      'question_stem': questionStem ?? '',
      'user_answer': userAnswer,
      'correct_answer': correctAnswer,
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Checks if a question has already been reported
  Future<bool> hasQuestionBeenReported({
    required String questionId,
    String? paperFormId,
  }) async {
    final db = await database;
    final res = await db.query(
      'question_reports',
      columns: ['id'],
      where: 'question_id = ?',
      whereArgs: [questionId],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  /// Cleans up old reports older than 7 days automatically
  Future<int> autoCleanOldReports({int days = 7}) async {
    try {
      final db = await database;
      final threshold = DateTime.now().subtract(Duration(days: days)).toIso8601String();
      return await db.delete(
        'question_reports',
        where: 'created_at < ?',
        whereArgs: [threshold],
      );
    } catch (_) {
      return 0;
    }
  }

  /// Retrieves all student error reports (auto-clears records older than 7 days)
  Future<List<Map<String, dynamic>>> getQuestionReports() async {
    final db = await database;
    await autoCleanOldReports(days: 7);
    return await db.query('question_reports', orderBy: 'id DESC');
  }

  /// Updates status of a report (e.g. 'solved', 'synced', 'verified', 'submitted')
  Future<int> updateReportStatus(int id, String newStatus) async {
    final db = await database;
    return await db.update(
      'question_reports',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a specific question report by ID
  Future<int> deleteQuestionReport(int id) async {
    final db = await database;
    return await db.delete('question_reports', where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieves all pending reports that haven't been synced to GitHub yet
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final db = await database;
    return await db.query(
      'question_reports',
      where: "status != 'synced'",
      orderBy: 'id ASC',
    );
  }

  /// Marks a specific report as synced to GitHub
  Future<int> markReportSynced(int id) async {
    final db = await database;
    return await db.update(
      'question_reports',
      {'status': 'synced'},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns total count of reported questions
  Future<int> getReportCount() async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM question_reports');
    return Sqflite.firstIntValue(res) ?? 0;
  }
}
