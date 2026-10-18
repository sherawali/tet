# 📘 TET Mock Master: Complete Product Requirements Document (PRD) & Master Blueprint Prompt

> **System Blueprint & Architectural Specification Prompt**  
> *Target Stack: Flutter 3.11+, Dart 3, SQLite Offline-First, Impeller 120 FPS, GitHub Serverless CDN, Google Play Billing (IAP)*  
> *Target Examinations: UTET (Uttarakhand TET Paper 1 & Paper 2) & CTET (Central TET Paper 1 & Paper 2)*  
> *Database Vault: 9,720 Authentic Questions Across 62 Complete Pre-Assembled Papers*

---

## 1. 🌟 Product Vision & Executive Summary

### 1.1 Product Purpose
**TET Mock Master** is an ultra-premium, 100% offline-first educational preparation application designed specifically for aspirants appearing for **UTET** (Uttarakhand Teacher Eligibility Test) and **CTET** (Central Teacher Eligibility Test). The application provides aspirants with authentic previous year solved papers (2014–2026) and predicted model mock test papers matching the exact commission syllabus, time limits, and scoring rubrics.

### 1.2 Core Pillars
1. **100% Offline-First Reliability:** All 9,720 questions, 109 comprehension passages, answer keys, and detailed pedagogical explanations are pre-bundled in a local SQLite database (`tet_mock_vault.db`). Aspirants can practice in remote areas with zero internet connectivity.
2. **Dual Test Mode Engine:**
   - **📄 Question Booklet Mode (OMR Style):** Exact replica of the physical paper examination booklet with cover page, instructions, full 150-question scroll, and interactive OMR bubble marking.
   - **📱 CBT Mode (Computer-Based Test):** Realistic online testing interface featuring 1 question per screen, question palette (Answered, Marked, Unvisited), countdown timer, and pinch-to-zoom diagrams.
3. **100% Strict Bilingual Separation:**
   - **English Mode:** 100% pure English text across all headers, cards, badges, options, and explanations. Zero Hindi/Devanagari text leakage.
   - **Hindi Mode:** 100% pure standard Hindi (राजभाषा मानक हिन्दी). Zero Hinglish or English loanwords.
4. **Zero Government Impersonation & Copyright Compliance:** Pure educational mock examination simulator. Replaced all misleading claims ("Official Board Key") with legal educational disclaimers ("Complete Verified Solutions · Exam Practice Blueprint").
5. **GitHub Serverless CDN Remote Control:** Dynamic remote updates, live flash broadcast banners, patch updates, and free/paid access control via raw GitHub/jsDelivr endpoints without requiring store releases.
6. **High-Conversion Monetization (> ₹500 Net to Creator):** Google Play Billing integration with Master Pro Pass (₹599) and Single Paper Pass (₹299), backed by crash-proof error handling (UPI cancellation safety, 45-second watchdog timer).

---

## 2. 🏗️ High-Level Technical Architecture

```
                  ┌────────────────────────────────────────────────────────┐
                  │                 User Mobile Device                     │
                  │   (Flutter 3.11+ · Impeller Engine · 120 FPS UI)       │
                  └──────────────────────────┬─────────────────────────────┘
                                             │
                      ┌──────────────────────┴──────────────────────┐
                      ▼                                             ▼
       ┌───────────────────────────────┐             ┌───────────────────────────────┐
       │   Local SQLite Database       │             │   GitHub Serverless CDN       │
       │   (tet_mock_vault.db)         │             │   (jsDelivr / Raw GitHub)     │
       │   • 9,720 Pre-bundled Qs      │◄──Auto-Sync─│   • manifest.json (Patches)   │
       │   • 62 Full Paper Forms       │             │   • flash_messages.json       │
       │   • Offline History & Reports │             │   • config.json (Paywall)     │
       └───────────────────────────────┘             └───────────────────────────────┘
                      ▲                                             ▲
                      │                                             │
       ┌──────────────┴─────────────────────────────────────────────┴───────────────┐
       │                          Core Application Services                         │
       │  • ExamService (UTET/CTET Switcher, Stream Router, Language I & II)        │
       │  • MockEngine (Paper Loader, Adaptive Generator, Seeded Randomizer)        │
       │  • HtmlBookletBuilder (Universal 6-Archetype Question Parser & CSS Engine) │
       │  • PremiumService (Google Play Billing, Watchdog Timer, Free/Pro Gate)    │
       │  • SyncService (Incremental JSON Patch Sync, Asset Vault v16 Upgrader)     │
       │  • InAppUpdateService & InAppReviewService (Play Store Ecosystem)          │
       └────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Dependencies & Libraries (`pubspec.yaml`)
- `flutter`: Flutter SDK (Material 3 Adaptive Design)
- `sqflite` (`^2.4.2+1`) & `sqflite_common_ffi` (`^2.4.0+3`): High-performance offline database engine with transaction safety and indexed queries.
- `webview_flutter` (`^4.14.1`): High-fidelity rendering for HTML test booklets with native pinch-to-zoom and zero scroll lag.
- `flutter_math_fork` (`^0.7.4`): Rendering mathematical formulas, fractions, square roots, and algebraic equations in CBT and booklets.
- `in_app_purchase` (`^3.3.1`): Google Play Billing integration for Pro access.
- `in_app_update` (`^4.2.5`): Google Play In-App Updates (Immediate and Flexible flows).
- `in_app_review` (`^2.0.12`): Automated 5-star review prompts after test completions.
- `flutter_animate` (`^4.5.2`): Tactile micro-interactions, modal spring physics, and card animations.
- `google_fonts` (`^8.2.1`): Clean typography pairing (Outfit / Inter for English, Rozha One / Hind for Hindi).
- `http` (`^1.6.0`): CDN fetching and issue reporting.
- `shared_preferences` (`^2.5.5`): Instant persistence of user settings (active exam, stream, test mode, language).

---

## 3. 🗄️ Database Architecture & Schemas (SQLite)

The local SQLite vault (`tet_mock_vault.db`) contains **8 core tables** meticulously designed for relational integrity, rapid query times (< 15ms), and preservation of user data during cloud synchronizations.

```
       ┌────────────────┐             ┌────────────────┐
       │   passages     │             │  paper_forms   │
       │  (109 records) │             │  (62 records)  │
       └───────┬────────┘             └───────┬────────┘
               │ 1                            │ 1
               │                              │
               │ N                            │ N
       ┌───────┴────────┐             ┌───────┴────────┐
       │   questions    │◄───────────►│  appearances   │
       │ (9,720 records)│      N:M    │ (9,720 records)│
       └───────┬────────┘             └────────────────┘
               │ 1
               ├──────────────────────────────┐
               │ N                            │ N
       ┌───────┴────────┐             ┌───────┴────────┐
       │ mistake_records│             │question_reports│
       │ (User Reviews) │             │(Dispute Logs)  │
       └────────────────┘             └────────────────┘
```

### 3.1 Database Schemas

#### 1. `questions` (Master Question Vault - 9,720 Rows)
Stores every authentic question with bilingual stems, options, and pedagogical rationales.
```sql
CREATE TABLE questions (
  id TEXT PRIMARY KEY,
  exam TEXT NOT NULL,               -- 'utet1', 'utet2', 'ctet1', 'ctet2'
  paper INTEGER NOT NULL,            -- 1 (Primary) or 2 (Upper Primary)
  year INTEGER NOT NULL,             -- Exam Year (e.g., 2023, 2026)
  subject TEXT NOT NULL,            -- 'cdp', 'hindi', 'english', 'sanskrit', 'math', 'evs', 'science', 'social'
  topic TEXT,                       -- Specific syllabus node (e.g., 'Piaget', 'Fractions', 'Pedagogy')
  question_text TEXT NOT NULL,       -- Markdown/text stem with 6 question archetypes
  options_json TEXT NOT NULL,        -- JSON array of 4 option strings: '["(A) ...", "(B) ...", "(C) ...", "(D) ..."]'
  correct_answer INTEGER NOT NULL,   -- Integer index: 0 for (A), 1 for (B), 2 for (C), 3 for (D)
  explanation TEXT,                  -- Comprehensive pedagogical explanation
  exam_source TEXT,                 -- Source label (e.g., 'UTET-2023-Paper-I-Official')
  is_pyq INTEGER DEFAULT 0,         -- 1 for Real Board Paper, 0 for 2026 Predicted Mock
  marks INTEGER DEFAULT 1,          -- Default: 1 Mark
  negative_marks REAL DEFAULT 0.0,   -- Default: 0.0 (No negative marking in TET)
  passage_id TEXT,                  -- Foreign key referencing passages.id (nullable)
  has_diagram INTEGER DEFAULT 0,    -- 1 if question requires mathematical diagram
  diagram_type TEXT,                -- 'number_line', 'prism', 'shaded_area', 'geometry'
  diagram_data TEXT,                -- JSON parameters for procedural diagram rendering
  FOREIGN KEY (passage_id) REFERENCES passages(id)
);
CREATE INDEX idx_questions_exam_paper ON questions(exam, paper);
CREATE INDEX idx_questions_subject ON questions(subject);
CREATE INDEX idx_questions_is_pyq ON questions(is_pyq);
```

#### 2. `passages` (Reading Comprehension & Poetry Vault - 109 Rows)
```sql
CREATE TABLE passages (
  id TEXT PRIMARY KEY,
  exam TEXT NOT NULL,
  year INTEGER,
  subject TEXT NOT NULL,            -- 'hindi', 'english', 'sanskrit'
  passage_text TEXT NOT NULL,       -- Complete unedited prose or poem stanzas
  line_count INTEGER DEFAULT 0
);
```

#### 3. `paper_forms` (Pre-Assembled Exam Papers - 62 Rows)
```sql
CREATE TABLE paper_forms (
  id TEXT PRIMARY KEY,              -- e.g., 'utet-p1-set-b', 'ctet-p1-2026-pyq'
  exam TEXT NOT NULL,               -- 'utet' or 'ctet'
  paper INTEGER NOT NULL,           -- 1 or 2
  exam_date TEXT,                   -- Year/Date string (e.g., '2026', '2023')
  set_code TEXT,                    -- e.g., 'MOCK 01', 'SET-B', '2023', 'MS-01', 'SST-01'
  title TEXT NOT NULL,              -- Pure Hindi title in DB: 'UTET 2026 पेपर-1 मॉडल प्रश्न-पत्र 01'
  total_questions INTEGER DEFAULT 150,
  modules_json TEXT                 -- Sections structure breakdown
);
```

#### 4. `appearances` (Paper-to-Question Ordering - 9,720 Rows)
```sql
CREATE TABLE appearances (
  id TEXT PRIMARY KEY,
  question_id TEXT NOT NULL,
  paper_form_id TEXT NOT NULL,
  section TEXT NOT NULL,            -- 'cdp', 'hindi', 'english', 'math', 'evs', etc.
  question_number INTEGER NOT NULL, -- Sequential question number (1 to 150)
  official_option_id TEXT,
  FOREIGN KEY (question_id) REFERENCES questions(id),
  FOREIGN KEY (paper_form_id) REFERENCES paper_forms(id)
);
CREATE INDEX idx_app_paper_qnum ON appearances(paper_form_id, question_number);
```

#### 5. `test_history` (Past Attempts & Performance Analytics)
```sql
CREATE TABLE test_history (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL,
  mode TEXT NOT NULL,               -- 'cbt' or 'booklet'
  total_questions INTEGER NOT NULL,
  attempted INTEGER NOT NULL,
  correct INTEGER NOT NULL,
  wrong INTEGER NOT NULL,
  score REAL NOT NULL,
  percentage REAL NOT NULL,
  passed INTEGER NOT NULL,          -- 1 if score >= 90 (General 60%) or >= 82 (Reserved 55%)
  time_spent_seconds INTEGER NOT NULL,
  paper_title TEXT,
  set_code TEXT,
  section_scores_json TEXT,         -- Section breakdown: '{"cdp": 26, "math": 24, ...}'
  user_answers_json TEXT            -- Complete user selections: '{"0": 2, "1": 0, ...}'
);
```

#### 6. `mistake_records` (Targeted Revision Bank)
```sql
CREATE TABLE mistake_records (
  id TEXT PRIMARY KEY,
  question_id TEXT NOT NULL,
  test_session_id TEXT NOT NULL,
  user_answer INTEGER NOT NULL,
  correct_answer INTEGER NOT NULL,
  timestamp TEXT NOT NULL,
  is_reviewed INTEGER DEFAULT 0
);
```

#### 7. `question_reports` (In-App Objection & Error Reporting)
```sql
CREATE TABLE question_reports (
  id TEXT PRIMARY KEY,
  question_id TEXT NOT NULL,
  issue_type TEXT NOT NULL,         -- 'wrong_answer', 'incomplete_question', 'typo', 'other'
  custom_comment TEXT,
  reported_at TEXT NOT NULL,
  paper_form_id TEXT,
  question_number INTEGER,
  correct_answer INTEGER,
  status TEXT DEFAULT 'submitted'   -- 'submitted', 'under_review', 'resolved'
);
```

#### 8. `meta` (System State & Migration Flags)
```sql
CREATE TABLE meta (
  key TEXT PRIMARY KEY,
  val TEXT
);
```

### 3.2 Offline Vault Asset Upgrade Protocol (`DbHelper.dart`)
- **Version Flag:** `bank_version = '20261018_master_vault_clean_v16'`
- **Safety Mechanism:** Whenever the app launches, `ensureBundledAssetLoaded()` compares the local device version against the asset bundle. If outdated or question count < 9,720:
  - Opens `assets/database/tet_mock_vault.db` in read-only mode.
  - Performs an atomic SQLite transaction replacing `questions`, `passages`, `paper_forms`, and `appearances`.
  - **Zero Data Loss Guarantee:** Never deletes or alters `test_history`, `mistake_records`, or `question_reports`.

---

## 4. 🌐 GitHub Serverless CDN & Remote Orchestration

The application utilizes GitHub as an enterprise-grade, zero-cost, serverless CMS and CDN via jsDelivr and Raw GitHub endpoints.

### 4.1 Remote Endpoints
1. **Primary Raw GitHub (Instant Sync, 0 Cache Delay):**  
   `https://raw.githubusercontent.com/sherawali/tet/main/cdn/`
2. **Secondary jsDelivr CDN (Edge-Cached, Global CDN Fallback):**  
   `https://cdn.jsdelivr.net/gh/sherawali/tet@main/cdn/`

### 4.2 Remote Control JSON Files (`cdn/`)
1. **`cdn/flash_messages.json` (Live Multi-Slide Banner):**
   Controls dynamic broadcasts sliding on the Home Screen. Supports bilingual payloads (`title`, `title_en`, `message`, `message_en`, `action_label`, `action_label_en`, `type`, `dismissible`).
2. **`cdn/config.json` (Remote Paywall & Mock Gate):**
   Allows instant adjustment of access policies without store review:
   ```json
   {
     "all_mocks_free": false,
     "free_mock_count": 1,
     "free_form_ids": ["utet-p1-fullmock", "utet-p2-set-b", "ctet-p1-2026-pyq", "ctet-p2-ms-mock-01", "ctet-p2-sst-mock-01"],
     "paid_form_ids": []
   }
   ```
3. **`cdn/manifest.json` (Incremental Question Bank Patches):**
   Broadcasts new question bank versions, question fixes, and additional papers. `SyncService` downloads only diff patches and merges them into the local SQLite database.

---

## 5. 🎯 Examination Specifications & Domain Rules

### 5.1 Supported Target Examinations
1. **UTET (Uttarakhand Teacher Eligibility Test):**
   - Conducted by: Uttarakhand Board of School Education (UBSE), Ramnagar.
   - Frequency: Annual.
2. **CTET (Central Teacher Eligibility Test):**
   - Conducted by: Central Board of Secondary Education (CBSE), Delhi.
   - Frequency: Bi-annual.

### 5.2 Examination Structure & Subject Matrix (150 Qs · 150 Mins · 150 Marks)

| Paper | Level | Section 1 (30 Qs) | Section 2 (30 Qs) | Section 3 (30 Qs) | Section 4 | Section 5 (30 Qs) | Total |
|---|---|---|---|---|---|---|---|
| **Paper 1** | Primary (Classes 1–5) | बाल विकास (CDP) | भाषा I (Hindi/English) | भाषा II (English/Hindi) | गणित (Mathematics) - 30 Qs | पर्यावरण (EVS) | 150 Qs |
| **Paper 2 (Math-Sci)** | Upper Primary (Classes 6–8) | बाल विकास (CDP) | भाषा I (Hindi/English) | भाषा II (English/Hindi) | गणित एवं विज्ञान (60 Qs) | *(Combined Section 4)* | 150 Qs |
| **Paper 2 (Social)** | Upper Primary (Classes 6–8) | बाल विकास (CDP) | भाषा I (Hindi/English) | भाषा II (English/Hindi) | सामाजिक अध्ययन / विज्ञान (60 Qs) | *(Combined Section 4)* | 150 Qs |

### 5.3 Language Selection Rules (`ExamService.dart`)
- **Rule:** Aspirants must select two distinct languages (Language I ≠ Language II).
- **Available Languages:**
  - `Hindi` (हिन्दी)
  - `English` (अंग्रेजी)
  - `Sanskrit` (संस्कृत): **Status: Locked with Upcoming Notice Dialog (`🔒 संस्कृत`)** informing users that authentic Sanskrit Paper II papers are being curated for the next update.

---

## 6. 📝 The 6 Universal Question Archetypes & Parser Engine (`HtmlBookletBuilder.dart`)

`HtmlBookletBuilder` contains a deterministic universal parser that transforms raw database strings into structured, beautiful, responsive HTML cards with zero formatting errors.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Universal Question Parser                         │
├─────────────────┬──────────────────┬─────────────────┬─────────────────┤
│ 1. Standard MCQ │ 2. Match Columns │ 3. Assertion-   │ 4. Multi-       │
│    (4 Distinct  │    (Tabular 2-   │    Reason (A-R) │    Statement    │
│     Clean Opts) │     Column Grid) │    (Strict Card)│    (I, II, III) │
├─────────────────┴──────────────────┴─────────────────┴─────────────────┤
│ 5. Fill-in-the-Blank           │ 6. Comprehension & Poem Passages      │
│    (Clear Underline Cloze)     │    (Left Passage, Linked Qs Right)    │
└────────────────────────────────┴───────────────────────────────────────┘
```

### 6.1 Archetype Specifications
1. **Standard Multiple Choice Questions (MCQ):** Clean problem stem with exactly 4 options labeled (A), (B), (C), (D).
2. **2-Column Match the Following (Tabular):**
   - Automatically detects Column I / List A (`कॉलम-I`, `सूची-I`, `A-E`) and Column II / List B (`कॉलम-II`, `सूची-II`, `i-v`, `1-5`).
   - Renders as a 2-column comparative table with subtle alternating row shading.
3. **Assertion-Reason (A-R):**
   - Strictly triggered ONLY when both genuine Assertion terms (`अभिकथन`, `दावा`, `Assertion`) and Reason terms (`कारण`, `तर्क`, `Reason`) exist.
   - Formatted into distinct assertion and reason cards with amber/indigo side badges.
4. **Multi-Statement Evaluation:**
   - Detects roman numerals `(i)`, `(ii)`, `(iii)` or alphabetical statements `(A)`, `(B)`, `(C)`.
   - Protects introductory instructions (`निम्नलिखित कथनों पर विचार कीजिए...`) and renders statements as ordered sub-cards.
5. **Fill in the Blank (Cloze):**
   - Automatically renders dashes/dots as highlighted inline blank boxes (`[ _____ ]`).
6. **Reading Comprehension & Poetry Passages:**
   - Detects `passage_id` and renders prose with paragraph indentation or poetry with centered stanza formatting.
   - Displays passage container pinned above or alongside related questions.

---

## 7. 📱 Complete Screen Specifications & UI/UX

### 7.1 Screen 1: Home Screen (`lib/screens/home_screen.dart`)
- **Header:**
  - Target Exam badge: `UTET पेपर-1` / `CTET Paper-1` (clickable exam switcher).
  - Flags icon: Opens `ReportedQuestionsSheet` (user's dispute tracking).
  - Sync icon: Triggers `_syncNow` (fetches new patches from GitHub).
- **Banner 1: Remote Update Notification:**
  - Appears automatically if GitHub reports updated question counts or fresh papers.
- **Banner 2: Remote Flash Message Carousel (`FlashMessageBanner`):**
  - Auto-slides every 5s across 3 active announcements.
  - Fully bilingual: switches instantly between English and Hindi.
- **Section 1: Hero Carousel (`_buildHeroPyqCarousel`):**
  - Auto-rotating and swipeable carousel featuring Paper 1 (Flagship PYQ + top 5 model papers) or Paper 2 (all authentic PYQs).
  - Displays: Adaptive Stamp Badge (`AppStrings.getStampParts`), Class level badge (`कक्षा 1-5`), Full 2-line title, 3 meta chips (`150 प्रश्न`, `150 मिनट`, `150 अंक`), and "Start Test Booklet" CTA.
- **Section 2: Examination Booklets List:**
  - Lists all available 20 Model Mock Papers and PYQs.
  - Card includes: Stamp box (`मॉडल` / `01`), Title, Subtitle, Free vs Pro badge, and lock icon.
- **Bottom Navigation Bar (4 Tabs):**
  1. `📖 Booklets` (Home)
  2. `📚 Subjects` (Section-wise practice)
  3. `📊 History` (Attempt records)
  4. `⚙️ Settings` (Language, sync, storage optimization, update check)

### 7.2 Screen 2: Mock Series Screen (`lib/screens/mock_series_screen.dart`)
- Dedicated gateway listing all **20 full-length 2026 Model Test Papers**.
- Filter header displaying total test count, time limit (150 Mins), and qualifying score target.
- Free vs Locked indicators with instant paywall trigger on locked tests.

### 7.3 Screen 3: PYQ Vault Screen (`lib/screens/pyq_vault_screen.dart`)
- Dedicated archive of authentic board examination papers from **2014 to 2026**.
- Stream switch button (`स्ट्रीम बदलें ⇄`) for Paper 2 candidates.
- Year badge stamps (`वर्ष 2023`, `वर्ष 2022`, `वर्ष 2021`).

### 7.4 Screen 4: Question Booklet Examination Mode (`lib/screens/html_booklet_screen.dart`)
- Authentic simulation of physical OMR paper booklet.
- **Cover Page:** Formal instructions, seal, candidate details placeholder.
- **Navigation Toolbar:** Floating timer, Section quick-jump drawer (CDP, Hindi, English, Math, EVS), Submit button.
- **OMR Bubble Sheet:** Tapping an option fills the circular OMR bubble with tactile feedback.

### 7.5 Screen 5: CBT Computer Test Mode (`lib/screens/cbt_exam_screen.dart`)
- 1 question per screen with large high-contrast typography.
- **Question Palette Drawer:** Visual grid of 150 questions color-coded by state:
  - 🟢 Green: Answered (उत्तर दिया)
  - 🟣 Purple: Marked for Review (समीक्षा हेतु चिन्हित)
  - 🟠 Orange: Unanswered (उत्तर नहीं दिया)
  - ⚪ Gray: Not Visited (नहीं देखा)
- **Controls:** Clear Response, Mark for Review, Previous, Save & Next.
- Mathematical equation rendering via `flutter_math_fork`.

### 7.6 Screen 6: Result & Performance Analytics Screen (`lib/screens/result_screen.dart`)
- **Score Card:** Total Score out of 150, Accuracy percentage, Qualifying Status (`उत्तीर्ण` / `Qualified` if score >= 90 / 60%).
- **Time Analytics:** Total time spent, average time per question.
- **Section-by-Section Breakdown:** Horizontal bar charts showing scores across CDP, Languages, Mathematics, and Science/Social.
- **Action Buttons:** `Detailed Solutions` (विस्तृत हल) and `Practice Weak Areas` (कमजोर विषय अभ्यास).

### 7.7 Screen 7: Detailed Solutions & Explanations Screen (`lib/screens/solution_screen.dart`)
- Review of all 150 questions.
- Color highlights: Correct option in Green, User's incorrect choice in Red.
- In-depth pedagogical reasoning for why the correct option is right.
- `Report Error` button opening `QuestionReportSheet`.

### 7.8 Screen 8: Settings & Database Management Screen
- **App Language Switcher:** Instant single-tap switch between Hindi and English with full reactive UI rebuild.
- **Storage Optimization:** `VACUUM` and `REINDEX` button reclaiming unused space and reporting reclaimed KB.
- **Database Re-Sync:** Clean re-sync button resetting local cache from bundled asset vault.
- **In-App Update (IAU) Card:** Manual "Check for Updates" trigger communicating with Google Play.
- **Play Store Rating Prompt:** Opens Play Store in-app review sheet.

### 7.9 Screen 9: Question Report Bottom Sheet (`lib/widgets/question_report_sheet.dart`)
- Allows aspirants to report questions with options:
  - ❌ Wrong Answer Key (उत्तर गलत है)
  - ❓ Incomplete/Unclear Question (अधूरा या अस्पष्ट प्रश्न)
  - ✏️ Typo or Spelling Mistake (टाइपिंग या वर्तनी की अशुद्धि)
  - 💬 Other (अन्य समस्या) with custom feedback text field.
- Saves locally and syncs to GitHub Issue tracker.

---

## 8. 🎨 Design System & Visual Hierarchy

### 8.1 Palette & Color Tokens (`lib/design_system/app_colors.dart`)
- **Paper 1 Theme (Classes 1–5 / Primary):**
  - Royal Sapphire Ocean Blue: `#0284C7` (Light) / `#0C4A6E` (Dark Gradient)
- **Paper 2 Theme (Classes 6–8 / Upper Primary):**
  - Royal Amethyst Purple: `#8B5CF6` (Light) / `#3B0764` (Dark Gradient)
- **Universal Accents:**
  - Seal Gold: `#D97706` / `#F59E0B`
  - Success Green: `#10B981`
  - Error Red: `#EF4444`
  - Dark Surface / OLED Card: `#0F172A` / `#1E293B`
  - Light Surface / Card: `#FFFFFF` / `#F8FAFC`

### 8.2 Stamp Architecture (`AppStrings.getStampParts`)
To eliminate awkward overlapping like "सेट मॉडल 01", stamps are decomposed into structured pairs:
- **Model Papers:** `{top: 'मॉडल' / 'MOCK', bottom: '01'}`
- **Previous Year Papers:** `{top: 'वर्ष' / 'YEAR', bottom: '2023'}`
- **Lettered Sets:** `{top: 'सेट' / 'SET', bottom: 'B'}`
- **Math-Science:** `{top: 'गणित-वि.' / 'M&S', bottom: '01'}`
- **Social Science:** `{top: 'सामाजिक' / 'SST', bottom: '01'}`

---

## 9. 💰 Monetization, IAP & Safety Architecture

### 9.1 Product Hierarchy & Google Play SKUs
1. **Master All-Access Pro Pass (Best Value):**
   - **SKU:** `tet_master_all_access_599`
   - **Price:** ₹599 (Net > ₹500 to creator after Google's 15% tier fee).
   - **Access:** Unlocks both UTET and CTET (Paper 1 & Paper 2), all 62 full mock booklets, 9,720 questions, and lifetime updates.
2. **Single Paper Pro Pass (Affordable Student Tier):**
   - **SKU:** `tet_single_paper_299`
   - **Price:** ₹299.
   - **Access:** Unlocks all 28+ papers for the selected exam paper.

### 9.2 Strict Free vs Pro Policy
- **Free Tier:** Exactly **1 designated flagship paper** per exam/paper is 100% free (`defaultFreePaperIds`):
  - UTET Paper 1: `utet-p1-fullmock`
  - UTET Paper 2: `utet-p2-set-b`
  - CTET Paper 1: `ctet-p1-2026-pyq`
  - CTET Paper 2 Math-Sci: `ctet-p2-ms-mock-01`
  - CTET Paper 2 Social: `ctet-p2-sst-mock-01`
- **Pro Tier:** All remaining 57+ papers require an active Pro Pass.

### 9.3 Crash-Proof & Hang-Proof Purchase Protocol
- **UPI / Payment App Cancellation Safety:** When a user navigates to GPay/PhonePe and cancels, the app immediately cancels the loading spinner and displays a non-intrusive toast (`भुगतान रद्द कर दिया गया` / `Payment canceled`).
- **45-Second Watchdog Timer:** `_purchaseTimeoutTimer` ensures that even if Google Play hangs, the UI unlocks automatically within 45 seconds.
- **Celebratory Success Modal:** Successful purchases fire `onPurchaseSuccess` broadcast stream, presenting a celebration dialog (`🎉 बधाई हो! प्रो सदस्यता सक्रिय हो गई`).

---

## 10. 🔒 Security, Signing Keys & Release Safety

1. **Android Signing Keys Protection:**
   - Keystore location: `android/app/` (`*.jks`, `key.properties`).
   - Strict rule: **Never delete, modify, or overwrite signing keys.**
2. **Deterministic Build Verification:**
   - Static Analysis: `dart analyze lib/` must maintain **0 errors, 0 warnings**.
   - Unit Tests: `flutter test` must pass **100% of test suites**.
3. **Google Play Policy Compliance:**
   - Strict educational categorization.
   - Zero copyright infringements.
   - Clear terms of service, privacy policy, and offline data handling.

---
*End of Complete PRD Specification Prompt.*
