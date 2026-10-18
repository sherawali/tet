import sys
import os
import re

sys.stdout.reconfigure(encoding='utf-8')

p = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-1\UTET_Paper1_SET3_FreshMock.md'
with open(p, 'r', encoding='utf-8') as f:
    txt = f.read()

pos = txt.find('उत्तर कुंजी')
if pos == -1:
    pos = txt.find('ANSWER KEY')

print("Found answer key section at pos:", pos)
print(txt[pos:])
