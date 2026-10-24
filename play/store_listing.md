# TET Rank — Play Console Store Listing Kit

App: **TET Rank** · package `com.tetrank.pro` · version `1.0.0+1`

Everything below is copy-paste ready. Play Console → Grow → Store presence → Main store listing.

---

## 1. Assets checklist

| Asset | Where it is | Notes |
|---|---|---|
| App icon 512×512 | `play/play_icon_512.png` | PNG, no transparency issue (full-bleed navy) |
| Feature graphic 1024×500 | `play/feature_graphic_1024x500.png` | Required for promo placement |
| Phone screenshots (4) | `play/screenshots/01..04*.png` | 1080×2160, exactly 2:1 (Play max allowed) |
| Privacy policy URL | host `docs/privacy_policy.html` (below) | |
| AAB | `flutter build appbundle --release` | Build AFTER products exist (see §5) |

Screenshot files:
- `01_utet_papers_free.png` — UTET booklets, flagship free paper
- `02_ctet_papers_free.png` — CTET tab, Pro Pass lock
- `03_subject_drills_hindi.png` — Subject drills (Set-1 free)
- `04_history_weak_focus.png` — History + weak-spot focus card

> After the 2 subscription products are created in Play Console (§5), capture one more
> screenshot of the real paywall (real prices from Play, no offline banner) and upload
> it as screenshot 5. Suggested command: open the app → tap a locked paper → `adb shell screencap -p /sdcard/pw.png`.

---

## 2. Privacy policy URL

1. Push this repo; GitHub can serve from the `docs/` folder.
2. Repo → Settings → Pages → Build and deployment → Source: **Deploy from a branch** → Branch: `main`, Folder: **`/docs`** → Save.
3. After ~1 minute the page is live at:
   **https://sherawali.github.io/tet/privacy_policy.html**
4. Paste that URL in Play Console (App content → Privacy policy).

Migrate the content later if a custom domain is added — keep the URL stable, Play lists it inside the app entry.

---

## 3. Store listing text

### App title (≤ 30 chars) — 28 ✓
```
TET Rank: UTET & CTET Papers
```

### Short description (≤ 80 chars)

English (78 ✓):
```
63 solved UTET & CTET papers. Mocks, subject drills, weak-spot focus. First paper free.
```
✗ Hindi fallback (short, if you prefer Devanagari — 60 ✓):
```
UTET व CTET के 63 सुलझे पेपर। मॉक, ड्रिल, कमज़ोरी-फोकस। पहला पेपर मुफ़्त।
```

### Full description (≤ 4000 chars)

```
TET Rank — UTET (Uttarakhand) और CTET 2026 की पूरी तैयारी, एक ही ऐप में, पूरी तरह ऑफ़लाइन।

टार्गेट आपका है — सारा सामना हमारा:
• 63 सुलझे पेपर — 47 मॉक + 16 बोर्ड PYQ (2014–2026) — कुल 9,720 प्रश्न, हर प्रश्न का लिखा हल (solution) साथ
• UTET Paper-1 (Classes 1–5) और Paper-2 (Classes 6–8) दोनों
• CTET Paper-1 और Paper-2 दोनों — एक पास, चारों खुलेंगे
• हर विषय के अभ्यास-सेट: बाल विकास, गणित, पर्यावरण, हिंदी, अंग्रेज़ी आदि
• तय 150 प्रश्न · 150 मिनट · 150 अंक की बोर्ड-पैटर्न परीक्षा शैली

पहला पेपर सबके लिए निःशुल्क — UTET और CTET दोनों का। अभ्यास-सेट में हर विषय का पहला सेट भी मुफ़्त। निर्णय पहले, ख़रीद बाद में।

फीचर्स:
• हिंदी व अंग्रेज़ी दोनों में पूरा UI — एक टैप में भाषा बदलें
• ऑफ़लाइन परीक्षा: इंटरनेट का मोहताज नहीं — क्लास में, यात्रा में, कहीं भी
• रिज़ल्ट एनालिटिक्स: विषयवार स्कोर, समय, कटौती (negative marking) — सब दिखता है
• मिस्टेक बैंक: गलत किए हर प्रश्न एक जगह — "Today's focus" कमज़ोर विषय ढूंढकर अभ्यास का सुझाव देता है
• गोली-सही समाधान: हर सवाल का हल व्याख्या सहित
• कोई विज्ञापन नहीं। कोई व्यक्तिगत डेटा नहीं। कोई अकाउंट नहीं।

प्रो पास लेने पर क्या-क्या खुलता है:
• पूरी बैंक: सारे मॉक + सारे बोर्ड पेपर + सारे विषय-सेट
• UTET + CTET दोनों, Paper-1 + Paper-2 — एक ही पैक
• आने वाले हर नए पेपर अपने-आप खुलता है (CDN से अपडेट, बिना ऐप-अपडेट)
• 1 साल ₹2,500 (महीने ~₹208) या 6 महीने ₹1,499 (महीने ₹250) — Google Play ही से भुगतान
• पास समाप्त होने पर पेपर लॉक होते हैं, पर आपका रिज़ल्ट-इतिहास और मिस्टेक-डेटा कभी नहीं मिटता

English summary:
63 solved papers — 47 mocks + 16 board PYQs — 9,720 questions with written solutions, for UTET Paper-1/2 and CTET Paper-1/2. Works fully offline. First paper free for both exams; every subject's first drill set is free too. Pro Pass (₹2,500/1yr or ₹1,499/6mo) opens the whole bank — UTET + CTET — and every future paper unlocks automatically. History and mistake data are never erased. No ads, no accounts, no personal data.

पहली बार इस्तेमाल करने वालों के लिए: ऐप खोलते ही UTET व CTET का फ्लैगशिप पेपर निःशुल्क मिलता है। परीक्षा के दिन से पहले जितनी बार चाहें अभ्यास करें — इंटरनेट की चिंता छोड़ें।
```

### Category & tags
- App category: **Education**
- Tags: Education → **Learning tools / Test preparation**
- Type: Application, free with in-app purchase

---

## 4. App content answers (Data safety & friends)

**Data safety form (Play Console → App content → Data safety):**
- Does the app collect or share user data? → **No**
  *(Everything sensitive is on-device; optional error reports are user-initiated — if you prefer declaring it, instead answer: Collects yes → "App activity → App interactions (error reports)", Shared: No, Transmitted encrypted: No, Deletion: request via app. The simplest consistent answer matching the policy is just "No" + the policy explanatory line.)*
- **Privacy policy URL:** https://sherawali.github.io/tet/privacy_policy.html
- **Ads:** App contains no ads.
- **Financial features:** No loans/investment features.
- **Target audience:** Adults (18+). *Not* designed for children.
- **Content rating:** Education, no user-generated content → questionnaire → ESRB "Everyone"/IARC result. Answer "No" across (no violence etc.).
- **News app declaration:** No.
- **COVID apps:** No.
- **Government apps:** No (practice app for a state exam, not the official board). Do NOT claim official affiliation anywhere.

---

## 5. In-app products (Play Console → Monetize → Products → Subscriptions + base plans/offers)

Create **exactly 2** prepaid subscriptions, nothing else:

| Product ID | Name shown | Base plan | Prepaid cycle | Price |
|---|---|---|---|---|
| `tet_all_access_1y` | Pro Pass — All-Open 1 Year | `tet-access-1y` | 1 year, prepaid | ₹2,500.00 |
| `tet_all_access_6m` | Pro Pass — All-Open 6 Months | `tet-access-6m` | 6 months, prepaid | ₹1,499.00 |

Steps:
1. Monetize → Subscriptions → Create product → paste Product **ID exactly** (`tet_all_access_1y`) — ID never editable.
2. Add one base plan (term = 1 year / 6 months), add ** prepaid ** offer availability for new buyers, activate plan.
3. Set INR prices above. (Other currencies follow automatically.)
4. Copy the exact ids from `docs/PLAY_STORE_PASS_SETUP.md` — the app queries these two ids only.

Until both products are **active**, the paywall shows the offline banner in builds — that is expected and disappears once products go live.

---

## 6. Release

1. `flutter build appbundle --release` → AAB in `build\app\outputs\bundle\release\`
2. Play Console → Release → Production → Create new release → upload AAB
3. Store listing: paste §3, upload assets from §1, submit privacy URL from §2
4. Submit for review.

Review notes (paste for reviewer):
```
This app is fully offline exam practice (UTET/CTET). Nothing is behind a server.
Free tier: first paper of UTET and CTET + first drill set of every subject is free.
To test the paid tier without creating a real purchase: the paywall opens from any
locked paper (lock icon). Two subscription products (tet_all_access_1y, tet_all_access_6m)
are live in this listing; use Play's license-tester account for a free test purchase.
"Restore Purchases" restores any past purchase. Entitlement is enforced on-device with
exact validity dates; expiry never deletes user history.
```
