"""Generate the remaining curated English families and patch the fix table.

The script reads the exact Hindi stems / options from the database and
writes the curated table into scripts/vault_content_fixes.py.  It contains
no Devanagari in its own source, so it can be written with a plain editor.
"""
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
from vault_data_rules import norm_lower, normalize_options, stem_anchor_violation  # noqa: E402

# target question id -> (english stem, english option list)
TARGETS = {
    '56cdb70928728afb': ("According to Piaget, 'Conservation' develops in which stage?",
        ['sensorimotor', 'pre-operational', 'concrete operational', 'formal operational']),
    '5d135614decf86f6': ("What is the most important aspect in math teaching?",
        ['remembering procedures', 'memorizing formulas', 'getting correct answer', 'conceptual understanding']),
    '652b8fdbd555559c': ("What should a teacher do for a poor child in inclusive education?",
        ['seat outside classroom', 'scold', 'provide alternative material/book-bank', 'exclude from exam']),
    '6a1076b107fdac05': ("Which type of forest covers the largest area in India?",
        ['tropical moist deciduous forests', 'tropical dry deciduous forests', 'temperate mixed forests', 'alpine forests']),
    '6f1e2284ec4704a2': ("Froebel developed which teaching method?",
        ['montessori method', 'kindergarten method', 'project method', 'play-way method']),
    '783ba4dcf60ef5dd': ("When using TLM, the first thing to consider is:",
        ['attractive', 'bright', 'related to the subject', 'cheap']),
    '836ba6140bc32312': ("Skinner's 'Shaping' means:",
        ['teaching behavior in one go', 'teaching behavior in small steps', 'punishing behavior', 'ignoring behavior']),
    '8bfbd3f46f6c874f': ("Main cause of math anxiety is:",
        ['gender', 'nature of subject', 'exam method', 'socio-cultural background']),
    '9786205656f79ab7': ("When the graph of a linear equation in two variables is drawn, it is:",
        ['parabola', 'ellipse', 'straight line', 'circle']),
    '9bb44deffab7625f': ("Best way to overcome math fear is:",
        ['more homework', 'punishment', 'more exams', 'games, puzzles and real life connections']),
    'bc89765b0fc9e5df': ("Kohlberg's third level (Post-conventional level) of moral development is based on:",
        ['punishment and reward', "society's rules", 'universal moral principles', "parent's guidance"]),
    'bcee502b3481f28a': ("Area of a rectangle = length x width. If the length is 8 cm and the width is 5 cm, the area is:",
        ['35 cm\u00b2', '40 cm\u00b2', '45 cm\u00b2', '50 cm\u00b2']),
    'c3b6e6b955565dc1': ("The purpose of Formative Assessment is:",
        ['giving grades', 'identifying learning gaps', 'giving promotion', 'comparison']),
    'c95a99b42e3ab4a2': ("In which country was Jean Piaget born?",
        ['France', 'Switzerland', 'Germany', 'England']),
    'd37143f11d3b3af4': ("The purpose of Summative Assessment is:",
        ['for improvement', 'for grades/promotion', 'to identify errors', 'to identify learning gaps']),
    'd4ad9aceff6df064': ("The main element of Montessori education is:",
        ['sensory training', 'rote learning', 'exam', 'punishment']),
    'd7825c92237d1b8e': ("Suitable seating arrangement for hearing impaired children in inclusive education is:",
        ['semi-circular', 'single row', 'circular', 'square']),
    'd8fa17e7c7341ab1': ("'Barrier-free' in inclusive education means:",
        ['environment without barriers', 'environment with barriers', 'only physical barriers', 'only mental barriers']),
    'dac6988f3a874bd6': ("The flow of energy in an ecosystem is:",
        ['bidirectional (in both directions)', 'unidirectional (in one direction)', 'cyclic', 'directionless']),
    'dc51df25065bcb91': ("Play-way method is most suitable for which age?",
        ['adult', 'adolescent', 'childhood', 'old age']),
    'e24369f5d1bb0ad7': ("India's first national park (1936) was:",
        ['Kanha National Park', 'Bharatpur National Park', 'Hailley (Corbett) National Park', 'Rajaji National Park']),
    'efd8fc1425a456ea': ("If an article costs Rs 500 and a 10% discount is offered, the selling price is:",
        ['\u20b9400', '\u20b9425', '\u20b9450', '\u20b9475']),
    'fa94007a4d66735b': ("Vygotsky's 'More Knowledgeable Other' (MKO) means:",
        ['child', 'teacher/peer', 'parent', 'textbook']),
    'fd28b210f229b94f': ("Purpose of error analysis in math is:",
        ['punishing students', 'diagnosis and treatment of errors', 'comparing students', 'taking exams']),
    '5643f946ff0c0cf0': ("If 20% of a number is 50, the number is:",
        ['200', '250', '300', '350']),
    '4991d5c06e1fca19': ("The product of a rational and an irrational number is:",
        ['rational', 'irrational', 'integer', 'divisor']),
    '11c9edfda7d33aec': ("What is the importance of math at primary level?",
        ['cultural', 'social', 'religious', 'mental']),
    'ctet-p2-sst-mock-07_q132': ("In the Puttaswamy case of 2017 the Supreme Court of India held that the right to privacy is:",
        ['not protected by the constitution',
         'a fundamental right under the constitution',
         'only a legal right',
         'limited only to written communication']),
    '0c77ebf98c33182e': ("An example of interaction between biotic and abiotic components is:",
        ['a grasshopper eats a leaf',
         'rain water flows into a lake',
         'an earthworm makes a burrow in the soil',
         'a rat fights with another rat']),
    '475c7eea1ca3caf7': ("Formative assessment in mathematics does:",
        ['gives grades/promotion',
         'identifies learning gaps',
         'compares students',
         'takes final exam']),
    'b888c246ba2456fe': ("An example of musical intelligence according to Gardner is:",
        ['singer', 'painter', 'writer', 'athlete']),
}

MARKER = "    # --- generated entries (scripts/generate_foreign_families.py) ---"

# A family can hold several Hindi wordings of the same question; they need
# their own English stem.
STEM_OVERRIDES = {
    'गणित में कम उपलब्धि (Underachievement) का मुख्य कारण है :':
        'Main cause of underachievement in math is:',
}


def opts(raw):
    try:
        value = json.loads(raw or 'null')
    except (TypeError, ValueError):
        return None
    return value if isinstance(value, list) else None


conn = sqlite3.connect(ROOT / 'assets' / 'database' / 'tet_mock_vault.db')
conn.row_factory = sqlite3.Row
rows = [dict(r) for r in conn.execute('SELECT * FROM questions')]

by_option_set = {}
for r in rows:
    hindi = opts(r['options_hindi']) or []
    by_option_set.setdefault(frozenset(normalize_options(hindi)), []).append(r)

entries = {}
for qid, (english_stem, english) in TARGETS.items():
    row = conn.execute('SELECT * FROM questions WHERE id = ?', (qid,)).fetchone()
    if row is None:
        print('MISSING', qid)
        continue
    hindi = opts(row['options_hindi'])
    if len(hindi) != len(english):
        print('LENGTH MISMATCH', qid, len(hindi), len(english))
        continue
    key = frozenset(normalize_options(hindi))
    for member in by_option_set[key]:
        member_hi = opts(member['options_hindi'])
        mapping = {}
        for h, e in zip(member_hi, english):
            mapping[norm_lower(h)] = e
        stem = norm_lower(member['q_hindi'])
        stem_text = STEM_OVERRIDES.get(stem)
        if stem_text is None:
            # The English stem of the curated entry is the human verified
            # translation.  The stem that is stored in the vault may belong
            # to a neighbouring question (the import shifted the English
            # column), so it must never be reused here.
            stem_text = english_stem
        if stem in entries and entries[stem]['options'] != mapping:
            print('CONFLICT for', stem)
        entries[stem] = {'en_stem': stem_text, 'options': mapping}

def render_entry(stem, entry):
    lines = ['    %r: {' % stem]
    lines.append('        "en_stem": %r,' % entry['en_stem'])
    lines.append('        "options": {')
    for h, e in entry['options'].items():
        lines.append('            %r: %r,' % (h, e))
    lines.append('        },')
    lines.append('    },')
    return '\n'.join(lines) + '\n'


fixes = ROOT / 'scripts' / 'vault_content_fixes.py'
source = fixes.read_text(encoding='utf-8')
dict_start = source.index('FOREIGN_EN_FAMILIES: dict[str, dict] = {')
# The table ends before the next top level block; the closing brace of the
# dictionary is the last character of that block.
block_end = source.index('\n\n\n', dict_start)
head = source[:block_end + 1]
tail = source[block_end + 1:]

# The table is updated in place, but an entry that already exists is never
# overwritten: the curated entries are maintained by hand and carry the
# human verified English text.  Only a missing entry is added.
added = 0
skipped = 0
for stem in sorted(entries):
    entry = entries[stem]
    marker = '    %r: {' % stem
    if marker in head:
        skipped += 1
        continue
    insert_at = head.rfind('}')
    head = head[:insert_at] + render_entry(stem, entry) + head[insert_at:]
    added += 1

fixes.write_text(head + tail, encoding='utf-8')
print(
    'patched %s: %d entries added, %d left untouched'
    % (fixes.name, added, skipped)
)