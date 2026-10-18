target_file = r'C:\Users\pujariji\Desktop\tetmaster\Final_Mocks\UTET-1\UTET_Paper1_SET12_FreshMock.md'

with open(target_file, 'r', encoding='utf-8') as f:
    content = f.read()

old_block = """22. **Q.** कॉलम 'A' का मिलान कॉलम 'B' से कीजिए-
 (A) पहचानने योग्य भाषा बोलने की क्षमता (A) (1-a)(2-b)(3-c)(4-d)  (B) (1-b)(2-d)(3-c)(4-a)  (C) (1-a)(2-c)(3-d)(4-b)  (D) (1-c)(2-a)(3-d)(4-b) (A) ability to produce recognizable speech
 [EN] Match Column A with Column B — Column A: (1) Grammar (2) Semantic development (3) Babbling (4) Phonological development; Column B:
 [EN] (A) (1-a)(2-b)(3-c)(4-d)  (B) (1-b)(2-d)(3-c)(4-a)  (C) (1-a)(2-c)(3-d)(4-b)  (D) (1-c)(2-a)(3-d)(4-b)"""

new_block = """22. **Q.** कॉलम 'A' का मिलान कॉलम 'B' से कीजिए — कॉलम A: (1) व्याकरण (2) शब्दार्थ विकास (3) बबलाना (4) ध्वन्यात्मक विकास; कॉलम B: (a) पहचानने योग्य भाषा बोलने की क्षमता (b) भाषा के नियमों का उपयोग (c) भाषा की ध्वनियों का उत्पादन (d) शब्दों का अर्थ समझना
 (A) (1-a)(2-b)(3-c)(4-d)  (B) (1-b)(2-d)(3-c)(4-a)  (C) (1-a)(2-c)(3-d)(4-b)  (D) (1-c)(2-a)(3-d)(4-b)
 [EN] Match Column A with Column B — Column A: (1) Grammar (2) Semantic development (3) Babbling (4) Phonological development; Column B: (a) ability to produce recognizable speech (b) using rules of language (c) production of sounds of language (d) understanding meaning of words
 [EN] (A) (1-a)(2-b)(3-c)(4-d)  (B) (1-b)(2-d)(3-c)(4-a)  (C) (1-a)(2-c)(3-d)(4-b)  (D) (1-c)(2-a)(3-d)(4-b)"""

if old_block in content:
    content = content.replace(old_block, new_block)
    with open(target_file, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Successfully cleaned Q22 in SET12!")
else:
    print("Old block not found directly, checking partial...")
    # Find position
    pos = content.find("22. **Q.** कॉलम 'A'")
    print("Found at pos:", pos)
    print(repr(content[pos:pos+400]))
