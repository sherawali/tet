import sys
import re

sys.stdout.reconfigure(encoding='utf-8')

def parse_options_robust(block):
    opts_hi = ['', '', '', '']
    opts_en = ['', '', '', '']
    
    # Check if options start with bullet - (A), - (B), - (C), - (D)
    bullet_matches = list(re.finditer(r'(?:^|\n)\s*[-*]\s*\(([A-D])\)\s*', block))
    
    if len(bullet_matches) == 4 and [m.group(1).upper() for m in bullet_matches] == ['A', 'B', 'C', 'D']:
        # Extract content between bullets
        for i in range(4):
            start = bullet_matches[i].end()
            end = bullet_matches[i+1].start() if i < 3 else len(block)
            content = block[start:end].strip()
            
            # Remove any trailing next question or answer key
            content = re.split(r'\n\s*(?:\*\*Q|\*\*Answer|\|)', content)[0].strip()
            
            # Split English and Hindi lines
            if ' / ' in content:
                parts = content.split(' / ', 1)
                opts_en[i] = parts[0].strip()
                opts_hi[i] = parts[1].strip()
            elif '\n' in content:
                lines = [l.strip() for l in content.splitlines() if l.strip()]
                en_lines = [l for l in lines if not re.search(r'[\u0900-\u097F]', l)]
                hi_lines = [l for l in lines if re.search(r'[\u0900-\u097F]', l)]
                opts_en[i] = ' '.join(en_lines).strip() if en_lines else ' '.join(lines).strip()
                opts_hi[i] = ' '.join(hi_lines).strip() if hi_lines else opts_en[i]
            else:
                has_deva = bool(re.search(r'[\u0900-\u097F]', content))
                opts_hi[i] = content
                opts_en[i] = content
        return opts_hi, opts_en

    # Fallback to standard sequential search
    return None

test_block = '''
- (A) (A) is true but (R) is false.
      (A) सही है लेकिन (R) गलत है।
- (B) Both (A) and (R) are false.
      (A) और (R) दोनों गलत हैं।
- (C) Both (A) and (R) are true and (R) is the correct explanation of (A).
      (A) और (R) दोनों सही हैं और (A) की (R) सही व्याख्या करता है।
- (D) Both (A) and (R) are true but (R) is not the correct explanation of (A).
      (A) और (R) दोनों सही हैं लेकिन (A) की (R) सही व्याख्या नहीं करता है।
'''

opts_hi, opts_en = parse_options_robust(test_block)
print("OptsHi:")
for o in opts_hi: print(" ", repr(o))
print("OptsEn:")
for o in opts_en: print(" ", repr(o))
