target_file = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-2\UTET_Paper2_SET-E_RealPYQ.md'

with open(target_file, 'r', encoding='utf-8') as f:
    content = f.read()

bad_str = "[HI] (A) नहपान (B) रूद्रदमन (C) कनिष्क (D) हुविष्क [EN] Who among the following rulers had the Sudarshan lake repaired in the second century CE? [EN] (A) Nahapana (B) Rudradaman (C) Kanishka (D) Huvishka"
good_str = "[HI] (A) नहपान (B) रूद्रदमन (C) कनिष्क (D) हुविष्क"

if bad_str in content:
    content = content.replace(bad_str, good_str)
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Cleaned Q96 in SET-E successfully!")
else:
    print("bad_str not found!")
