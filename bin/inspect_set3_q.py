import sys
import re

sys.stdout.reconfigure(encoding='utf-8')

p = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-1\UTET_Paper1_SET3_FreshMock.md'
with open(p, 'r', encoding='utf-8') as f:
    txt = f.read()

# Let's find Q61 to Q70
for qn in range(61, 71):
    m = re.search(rf'(?:^|\n)\s*{qn}\.\s*(.*?)(?=(?:\n\s*{qn+1}\.|\Z))', txt, re.S)
    if m:
        print(f"--- Q{qn} ---")
        print(m.group(0).strip()[:300])
