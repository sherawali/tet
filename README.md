# Question Bank — ऐप का डेटा स्रोत

## तेरा काम सिर्फ़ इतना
1. `content/q_<section>.csv` में नई पंक्तियाँ जोड़
2. commit + push
3. **बस।** GitHub Action बाकी सब करेगा

Push करते ही अपने-आप :
- CSV जाँचा जाएगा (गलत `ans`, अधूरे विकल्प → build फेल, खराब डेटा live नहीं जाएगा)
- डुप्लिकेट प्रश्न हटेंगे
- `cdn/packs/*.json` बनेंगे
- `cdn/manifest.json` का `bank_version` बढ़ेगा
- `v<N>` tag बनेगा → ऐप को अपडेट दिख जाएगा

---

## URL जो ऐप इस्तेमाल करेगा

> ⚠ `raw.githubusercontent.com` **मत** इस्तेमाल करना — वो CDN नहीं है, rate-limit लगती है
> ✅ **jsDelivr** इस्तेमाल कर — GitHub का मुफ़्त global CDN, कोई limit नहीं

```
manifest (हर बार नया):
https://cdn.jsdelivr.net/gh/<USER>/<REPO>@main/cdn/manifest.json

pack (हमेशा के लिए cache, नाम में hash है):
https://cdn.jsdelivr.net/gh/<USER>/<REPO>@v12/cdn/packs/pack-0003-a1b2c3d4e5f6.json
```

---

## ऐप का sync एल्गोरिथ्म

```kotlin
suspend fun sync(): SyncResult {
    // 1) सिर्फ़ manifest लाओ — ~3 KB
    val remote = http.get("$CDN@main/cdn/manifest.json").parse<Manifest>()
    val localVersion = prefs.getInt("bank_version", 0)
    if (remote.bank_version <= localVersion) return SyncResult.UpToDate

    // 2) सिर्फ़ वो pack जो पहले से नहीं हैं  ← यही असली बचत है
    val have = db.packIds()                       // पहले से डाउनलोड
    val need = remote.packs.filter { it.id !in have }
    if (need.isEmpty()) { prefs.putInt("bank_version", remote.bank_version); return UpToDate }

    // 3) डाउनलोड + sha256 जाँच + एक ही transaction में डालो
    db.withTransaction {
        for (p in need) {
            val bytes = http.getBytes("$CDN@v${remote.bank_version}/cdn/${p.file}")
            require(sha256(bytes) == p.sha256) { "pack खराब मिला" }   // भरोसा मत कर, जाँच कर
            db.insertPack(p.id, parse(bytes))
        }
        db.putTopics(remote.topics)
        prefs.putInt("bank_version", remote.bank_version)
    }
    return SyncResult.Added(need.sumOf { it.count })
}
```

**कब चले :**
- ऐप खुलने पर, पर 24 घंटे में एक बार से ज़्यादा नहीं
- `WorkManager` से रोज़ एक बार background में → `Added` मिले तो local notification
- **किसी Firebase/push सर्वर की ज़रूरत नहीं।** manifest 3 KB का है, रोज़ माँगना मुफ़्त है

---

## 🔑 सबसे अहम बात — मॉक ऐप में बनेंगे, यहाँ नहीं

repo में **मॉक कभी मत डालना। सिर्फ़ प्रश्न डालना।**

ऐप डिवाइस पर ही ब्लूप्रिंट के हिसाब से प्रश्न चुनकर मॉक बनाएगा :

```kotlin
fun newMock(seed: Long = System.currentTimeMillis()): Mock {
    val seen = db.seenQuestionIds()          // जो छात्र पहले हल कर चुका
    return blueprint.flatMap { (section, topics) ->
        topics.flatMap { (topic, need) ->
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
content/        ← सिर्फ़ यहाँ हाथ लगाना
  passages.csv
  q_cdp.csv  q_hindi.csv  q_english.csv  q_math.csv  q_evs.csv
tools/build.py  ← अपने-आप चलती है
cdn/           ← bot बनाता है, हाथ मत लगाना
```
