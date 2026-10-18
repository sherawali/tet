import sys
import re

sys.stdout.reconfigure(encoding='utf-8')

print("1. Patching SET12 Q105 in UTET-1...")
set12_path = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-1\UTET_Paper1_SET12_FreshMock.md'
with open(set12_path, 'r', encoding='utf-8') as f:
    text = f.read()

old_q105 = """105. **Q.** यदि
 (A) x = 9; y = 3  (B) x = 3; y = 9  (C) x = 5; y = 8  (D) x = 4; y = 8
 [EN] If
 [EN] (A) x = 9; y = 3  (B) x = 3; y = 9  (C) x = 5; y = 8  (D) x = 4; y = 8
**Ans: (C)**"""

new_q105 = """105. **Q.** यदि
```
  9 x 7 6
− x 6 y 9
─────────
  3 y y 7
```
तो x और y के मान हैं —
 (A) x = 9; y = 3  (B) x = 3; y = 9  (C) x = 5; y = 8  (D) x = 4; y = 8
 [EN] If
```
  9 x 7 6
− x 6 y 9
─────────
  3 y y 7
```
then the values of x and y are:
 [EN] (A) x = 9; y = 3  (B) x = 3; y = 9  (C) x = 5; y = 8  (D) x = 4; y = 8
**Ans: (C)**"""

if old_q105 in text:
    text = text.replace(old_q105, new_q105)
    with open(set12_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print("  ✓ SET12 Q105 patched successfully!")
else:
    print("  ⚠️ Old Q105 pattern not found in SET12, check whitespace.")

print("2. Patching SET-D Q119 in UTET-2...")
setd_path = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-2\UTET_Paper2_SET-D_RealPYQ.md'
with open(setd_path, 'r', encoding='utf-8') as f:
    text = f.read()

old_q119 = """**119. अभिकथन (A): ऊँचाई के साथ तापमान में कमी आती है। तर्क (R): ऊँचाई के साथ वायुमंडल के घनत्व में भिन्नता आती है।**
(A) A और R दोनों सही है और R, A की सही व्याख्या है। (B) A और R दोनों सही है R, A की सही व्याख्या नहीं है। (C) A सही है और R गलत है। (D) A गलत है और R सही है।"""

new_q119 = """**119. Q.** अभिकथन (A): ऊँचाई के साथ तापमान में कमी आती है। तर्क (R): ऊँचाई के साथ वायुमंडल के घनत्व में भिन्नता आती है।
(A) A और R दोनों सही है और R, A की सही व्याख्या है।  (B) A और R दोनों सही है R, A की सही व्याख्या नहीं है।  (C) A सही है और R गलत है।  (D) A गलत है और R सही है।"""

if old_q119 in text:
    text = text.replace(old_q119, new_q119)
    with open(setd_path, 'w', encoding='utf-8') as f:
        f.write(text)
    print("  ✓ SET-D Q119 patched successfully!")
else:
    print("  ⚠️ Old Q119 pattern not found in SET-D, check whitespace.")

print("3. Patching SET-G English Questions in UTET-2...")
setg_path = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-2\UTET_Paper2_SET-G_RealPYQ.md'
with open(setg_path, 'r', encoding='utf-8') as f:
    text = f.read()

replacements = [
    (
        "**72.** (A) property (B) prosperity (C) resources (D) wealth",
        "**72. Q.** Fill in the blank (72) in the sentence: \"Our scientific spirit must be shocked not only by the contrasts of fabulous [72] and rampant poverty...\"\n(A) property  (B) prosperity  (C) resources  (D) wealth"
    ),
    (
        "**73.** (A) common (B) rampant (C) grovelling (D) growing",
        "**73. Q.** Fill in the blank (73) in the sentence: \"...contrasts of fabulous prosperity and [73] poverty, but also by those of intense holiness...\"\n(A) common  (B) rampant  (C) grovelling  (D) growing"
    ),
    (
        "**74.** (A) religious (B) blind (C) popular (D) prevailing",
        "**74. Q.** Fill in the blank (74) in the sentence: \"...intense holiness and [74] superstition.\"\n(A) religious  (B) blind  (C) popular  (D) prevailing"
    ),
    (
        "**80.** (A) Aesthetic (B) Asthetic (C) Aesthatic (D) Asethetic",
        "**80. Q.** Choose the correctly spelt word:\n(A) Aesthetic  (B) Asthetic  (C) Aesthatic  (D) Asethetic"
    ),
    (
        "**81.** (A) Recieved (B) Recieved (C) Resieved (D) Recived",
        "**81. Q.** Choose the correctly spelt word:\n(A) Received  (B) Recieved  (C) Resieved  (D) Recived"
    ),
    (
        "**84.** (A) The king said to his courtiers \"Is there no one who can venture an answer?",
        "**84. Q.** Choose the correctly punctuated sentence:\n(A) The king said to his courtiers \"Is there no one who can venture an answer?"
    ),
    (
        "**85.** (A) She said who is there?",
        "**85. Q.** Choose the correctly punctuated sentence:\n(A) She said who is there?"
    ),
    (
        "**86.** (A) It is strange that you don't know swimming.",
        "**86. Q.** Choose the grammatically correct sentence:\n(A) It is strange that you don't know swimming."
    ),
    (
        "**87.** (A) Everyone knows that he is nothing else but a cheat.",
        "**87. Q.** Choose the grammatically correct sentence:\n(A) Everyone knows that he is nothing else but a cheat."
    ),
]

patched_count = 0
for old_s, new_s in replacements:
    if old_s in text:
        text = text.replace(old_s, new_s)
        patched_count += 1
    else:
        print(f"  ⚠️ Could not match: {repr(old_s[:40])}")

with open(setg_path, 'w', encoding='utf-8') as f:
    f.write(text)
print(f"  ✓ SET-G: Patched {patched_count}/{len(replacements)} questions!")
