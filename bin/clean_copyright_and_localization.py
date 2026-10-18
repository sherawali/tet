import re

def fix_pyq_vault():
    with open('lib/screens/pyq_vault_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    old_snippet = """const Text(
                                            '150 प्रामाणिक प्रश्न · 150 मिनट · आधिकारिक बोर्ड पेपर',"""
    new_snippet = """Text(
                                            AppStrings.isHindi
                                                ? '150 प्रश्न · 150 मिनट · सम्पूर्ण हल सहित'
                                                : '150 Questions · 150 Mins · Complete Solutions',"""
    
    # Try exact or normalized replacement
    if old_snippet in content:
        content = content.replace(old_snippet, new_snippet, 1)
        print("Replaced exact old_snippet in pyq_vault_screen.dart")
    else:
        # Regex replace
        pattern = r"const Text\(\s*'150 प्रामाणिक प्रश्न · 150 मिनट · आधिकारिक बोर्ड पेपर',\s*style:"
        replacement = r"""Text(
                                            AppStrings.isHindi
                                                ? '150 प्रश्न · 150 मिनट · सम्पूर्ण हल सहित'
                                                : '150 Questions · 150 Mins · Complete Solutions',
                                            style:"""
        content, count = re.subn(pattern, replacement, content, count=1)
        print(f"Regex replaced count: {count} in pyq_vault_screen.dart")
        
    with open('lib/screens/pyq_vault_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def fix_home_screen_paper_buttons():
    with open('lib/screens/home_screen.dart', 'r', encoding='utf-8') as f:
        content = f.read()
    
    pattern1 = r"'PAPER – I \(कक्षा 1-5\)'"
    repl1 = "AppStrings.isHindi ? 'पेपर – I (कक्षा 1-5)' : 'PAPER – I (Class 1-5)'"
    content, c1 = re.subn(pattern1, repl1, content, count=1)
    
    pattern2 = r"'PAPER – II \(कक्षा 6-8\)'"
    repl2 = "AppStrings.isHindi ? 'पेपर – II (कक्षा 6-8)' : 'PAPER – II (Class 6-8)'"
    content, c2 = re.subn(pattern2, repl2, content, count=1)
    
    print(f"home_screen paper buttons replaced: c1={c1}, c2={c2}")
    with open('lib/screens/home_screen.dart', 'w', encoding='utf-8') as f:
        f.write(content)

def fix_flash_and_exam():
    # 1. flash_message_service.dart
    with open('lib/services/flash_message_service.dart', 'r', encoding='utf-8') as f:
        fms = f.read()
    fms = fms.replace(
        "20 मॉडल प्रश्न-पुस्तिकाएं और विगत वर्षों के आधिकारिक बोर्ड पेपर्स 100% ऑफ़लाइन उपलब्ध हैं।",
        "20 मॉडल प्रश्न-पुस्तिकाएं और विगत वर्षों के सभी हल प्रश्न-पत्र 100% ऑफ़लाइन उपलब्ध हैं।"
    )
    with open('lib/services/flash_message_service.dart', 'w', encoding='utf-8') as f:
        f.write(fms)
    print("Fixed flash_message_service.dart")

    # 2. exam_service.dart
    with open('lib/services/exam_service.dart', 'r', encoding='utf-8') as f:
        es = f.read()
    es = es.replace(
        "★ 100% Based on Official Board Exam Pattern",
        "★ 100% Based on Exam Pattern & Standard Blueprint"
    )
    with open('lib/services/exam_service.dart', 'w', encoding='utf-8') as f:
        f.write(es)
    print("Fixed exam_service.dart")

    # 3. booklet_exam_screen.dart
    with open('lib/screens/booklet_exam_screen.dart', 'r', encoding='utf-8') as f:
        bes = f.read()
    bes = bes.replace(
        "'5. यह प्रश्न-पुस्तिका $examShort ${AppStrings.currentExamYear} आधिकारिक परीक्षा पैटर्न पर आधारित है।',",
        "'5. यह प्रश्न-पुस्तिका $examShort ${AppStrings.currentExamYear} परीक्षा पैटर्न पर आधारित है।',"
    )
    with open('lib/screens/booklet_exam_screen.dart', 'w', encoding='utf-8') as f:
        f.write(bes)
    print("Fixed booklet_exam_screen.dart")

if __name__ == '__main__':
    fix_pyq_vault()
    fix_home_screen_paper_buttons()
    fix_flash_and_exam()
