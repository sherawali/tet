import re

with open(r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-1\UTET_Paper1_SET12_FreshMock.md', 'r', encoding='utf-8') as f:
    text12 = f.read()

m = re.search(r'कॉलम', text12)
if m:
    with open('bin/mock12_q.txt', 'w', encoding='utf-8') as out:
        out.write(text12[max(0, m.start()-50):min(len(text12), m.start()+1200)])
    print("Found MOCK12 match")

with open(r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-2\UTET_Paper2_SET-G_RealPYQ.md', 'r', encoding='utf-8') as f:
    text14 = f.read()

m2 = re.search(r'equilibrium constant', text14, re.IGNORECASE)
if m2:
    with open('bin/mock14_q.txt', 'w', encoding='utf-8') as out:
        out.write(text14[max(0, m2.start()-50):min(len(text14), m2.start()+1000)])
    print("Found 2014-G match")
