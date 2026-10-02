# 🚀 इसे GitHub पर कैसे चढ़ाएँ

## तरीका 1 — ब्राउज़र से (सबसे आसान, git सीखने की ज़रूरत नहीं)

1. github.com खोल → ऊपर दाएँ **«+» → «New repository»**
2. नाम : `tet-qbank` · **Public** चुन · «Add a README» पर टिक **मत** करना
3. **«Create repository»** दबा
4. अगले पन्ने पर **«uploading an existing file»** लिंक दबा
5. `qbank-repo` फोल्डर की **सारी फाइलें और फोल्डर** खींचकर छोड़ दे
6. नीचे हरा **«Commit changes»** दबा
7. ऊपर **«Actions»** टैब खोल — एक मिनट में हरा ✅ आ जाना चाहिए

## तरीका 2 — कमांड से

```bash
cd qbank-repo
git init
git add -A
git commit -m "पहला कमिट — 300 प्रश्न"
git branch -M main
git remote add origin https://github.com/तेरा-नाम/tet-qbank.git
git push -u origin main
```

---

## ✅ चढ़ने के बाद ये जाँच

ब्राउज़र में यह खोल (अपना नाम डालकर) :

```
https://cdn.jsdelivr.net/gh/तेरा-नाम/tet-qbank@main/cdn/manifest.json
```

JSON दिखे तो **सब सही है** — ऐप इसी पते से डेटा लेगा।

> पहली बार में थोड़ी देर लग सकती है (CDN को फाइल खींचनी पड़ती है)। न खुले तो 2 मिनट बाद दोबारा।

---

## ⚠️ तीन बातें

1. repo **Public** ही रखना — private पर jsDelivr काम नहीं करता
2. **LICENSE** फाइल मत हटाना — jsDelivr की शर्त है
3. `cdn/` फोल्डर **कभी हाथ से मत बदलना** — रोबोट खुद बनाता है
