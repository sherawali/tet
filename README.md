# Question Bank — ऐप का डेटा स्रोत

CTET/UTET Paper-1 का verified प्रश्न बैंक। ऐप (Flutter) सिर्फ़ `cdn/` पढ़ता है —
`runtime/` gitignored है, वो सिर्फ़ build का बीच का कदम है।

## तेरा काम सिर्फ़ इतना
1. `bank-v2/` में प्रश्न/अनुच्छेद ठीक कर (NDJSON, हर लाइन एक record)
2. commit + push → **main** पर merge हो
3. **बस।** GitHub Action बाकी सब करेगा

main पर push होते ही अपने-आप :
- `verify_all_questions.py` चलेगा — सातों जाँच पास न हों तो release रुक जाएगा, खराब डेटा live नहीं जाएगा
- `runtime/tet_mock_vault.db` बनेगा
- `cdn/packs/*.json` + `cdn/manifest.json` बनेंगे, पुराने packs prune होंगे
- `bank_version` अपने-आप बढ़ेगा (UTC `YYYYMMDDHH`)
- `v<stamp>` tag बनेगा → jsDelivr cache purge → ऐप को अपडेट दिख जाएगा

> ⚠️ **branch पर काम ऐप तक नहीं पहुँचता।** Action सिर्फ़ `main` पर release करता है और
> ऐप `@main` का manifest पढ़ता है। काम पूरा होते ही PR merge करना ज़रूरी है।

### locally build/जाँच करनी हो तो
```bash
python3 verify_all_questions.py                 # gate — 7/7 PASS चाहिए
python3 tools/v2/build_app_db.py                # bank-v2 → runtime/tet_mock_vault.db
python3 tools/v2/build_cdn_packs.py             # db → cdn/packs + manifest
python3 tools/v2/prune_stale_packs.py           # manifest में न बचे packs हटाओ
python3 tools/v2/audit_passage_gaps.py          # अनुच्छेद/कविता की स्थिति
```
`cdn/` में **कभी हाथ मत लगाना** — वो generated है।

---

## URL जो ऐप इस्तेमाल करेगा

> ⚠ `raw.githubusercontent.com` **मत** इस्तेमाल करना — वो CDN नहीं है, per-IP rate-limit
> लगती है और CGNAT वाले छात्र block हो जाते हैं
> ✅ **jsDelivr** इस्तेमाल कर — GitHub का मुफ़्त global CDN

```
manifest (हर बार नया, ~4 KB):
https://cdn.jsdelivr.net/gh/<USER>/<REPO>@main/cdn/manifest.json

pack (नाम में content hash है, हमेशा के लिए cache):
https://cdn.jsdelivr.net/gh/<USER>/<REPO>@v2026101100/cdn/packs/pack-0003-c8d6f19dd108.json
```

manifest का हर pack entry :
```json
{ "id": "0003-c8d6f19dd108", "file": "packs/pack-0003-c8d6f19dd108.json",
  "sha256": "…", "bytes": 148312, "count": 200, "sections": ["cdp","english"] }
```

**`id` में content का hash है — यही सबसे अहम बात है।** एक प्रश्न का उत्तर ठीक हुआ,
pack का payload बदला, hash बदला, `id` बदला। पहले `id` सिर्फ़ index (`"0003"`) था, तो
ठीक किया हुआ pack ऐप को "पहले से डाउनलोड है" लगता था और सुधार कभी डिवाइस तक नहीं
पहुँचता था।

---

## ऐप का sync एल्गोरिथ्म

```kotlin
suspend fun sync(): SyncResult {
    // 1) सिर्फ़ manifest लाओ — ~4 KB
    val remote = http.get("$CDN@main/cdn/manifest.json").parse<Manifest>()
    val localVersion = prefs.getInt("bank_version", 0)
    if (remote.bank_version <= localVersion) return SyncResult.UpToDate

    // 2) जो pack id पहले नहीं देखे, सिर्फ़ वही  ← यही असली बचत है
    val have = db.packIds()
    val need = remote.packs.filter { it.id !in have }

    // 3) डाउनलोड + sha256 जाँच + एक ही transaction में डालो
    db.withTransaction {
        for (p in need) {
            val bytes = http.getBytes("$CDN@v${remote.bank_version}/cdn/${p.file}")
            require(sha256(bytes) == p.sha256) { "pack खराब मिला" }   // भरोसा मत कर, जाँच कर
            db.insertPack(p.id, parse(bytes))
        }
        // 4) जो pack manifest से गायब है, उसे हटाओ  ← ये कदम छूटता रहा है
        //    वरना पुराना/गलत प्रश्न हमेशा के लिए device पर टिका रहता है
        db.deletePacksNotIn(remote.packs.map { it.id })

        db.putTopics(remote.topics)
        prefs.putInt("bank_version", remote.bank_version)
    }
    return SyncResult.Updated(added = need.sumOf { it.count })
}
```

**अनुच्छेद (passage) वाला नियम:** एक passage और उसके सारे प्रश्न **एक ही pack** में
जाते हैं (`build_cdn_packs.py` इसे assert करता है)। इसलिए `deletePacksNotIn` से कभी
अधूरा गद्यांश नहीं बनेगा — पूरा समूह एक साथ आता है और एक साथ जाता है।

**कब चले :**
- ऐप खुलने पर, पर 24 घंटे में एक बार से ज़्यादा नहीं
- `WorkManager` से रोज़ एक बार background में → `Updated` मिले तो local notification
- **किसी Firebase/push सर्वर की ज़रूरत नहीं।** manifest 4 KB का है, रोज़ माँगना मुफ़्त है

### ऐप के पास पुराना `bank_version` अटका हो तो
`prefs` से `bank_version` हटा दे (या app में "डेटा रीसेट" रख) — अगला sync पूरा बैंक
दोबारा उतार लेगा, क्योंकि हर pack का id content से बनता है।

---

## 🔑 सबसे अहम बात — मॉक ऐप में बनेंगे, यहाँ नहीं

repo में **मॉक कभी मत डालना। सिर्फ़ प्रश्न डालना।**

ऐप डिवाइस पर ही ब्लूप्रिंट के हिसाब से प्रश्न चुनकर मॉक बनाएगा :

```kotlin
fun newMock(seed: Long = System.currentTimeMillis()): Mock {
    val seen = db.seenQuestionIds()          // जो छात्र पहले हल कर चुका
    return blueprint.flatMap { (section, topics) ->
        topics.flatMap { (topic, need) ->
            // p_score से weighted pick — कभी random uniform मत चुनना
            db.pick(section, topic, need, avoid = seen, rnd = Random(seed))
        }
    }.let { Mock(seed, it) }
}
```

इसके तीन फ़ायदे :
1. **200 नए प्रश्न (40 KB) = दर्जनों नए मॉक** — मॉक की फाइल भेजनी ही नहीं पड़ती
2. **हर छात्र को अलग मॉक** मिलता है, क्योंकि `seen` सबका अलग है
3. **seed share करने लायक** — "SET-7001 लगाओ" कहो, सबको बिल्कुल वही पेपर मिलेगा

---

## फोल्डर
```
bank-v2/exams/<exam>/paper-N/<section>[/<lang>]/
    questions.ndjson   ← प्रश्न  (prompt/options ब्लॉक-सूची हैं, जोड़ना नहीं — recurse करो)
    stimuli.ndjson     ← गद्यांश/कविता  (text locale से keyed: hi / en / sa)
    section.json
bank-v2/paper-forms/<exam>/paper-N/appearances.ndjson   ← प्रश्न-संख्या, official key
bank-v2/sources/*.json      ← cycle metadata (तारीख़, set, counts)
tools/v2/                   ← builders, repair passes, audits
tools/v2/official_keys/     ← CBSE की असली answer-key grids (सबसे भरोसेमंद स्रोत)
cdn/                        ← generated, हाथ मत लगाना
docs/                       ← MEMORY.md, HANDOVER.md, audit notes
verify_all_questions.py     ← release gate (7 जाँच)
```
