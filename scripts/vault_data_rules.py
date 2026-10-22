#!/usr/bin/env python3
"""Shared helpers for the question-data audit, the repair and the validator.

The three tools must agree on what a defect is, otherwise the validator
would happily pass a state the repair script still considers broken.  All
detection logic therefore lives here.

The core idea of the *anchor* test
---------------------------------
Many Hindi stems and options carry the English term of the concept in
parentheses, e.g. ``मिट्टी का अपरदन (erosion)`` or ``गार्डनर (Gardner)``.
That Latin term is the bridge between the two languages: a faithful
translation has to keep it (or its expansion).  If the English side of a
question does not contain the anchor, the English text belongs to a
different question - which is exactly how the source rows got shifted
during the import.
"""

from __future__ import annotations

import re

# --- text helpers ----------------------------------------------------------

WHITESPACE = re.compile(r"\s+")


def normalize(value) -> str:
    """Collapse whitespace and strip; the canonical form of a text field."""
    return WHITESPACE.sub(" ", str(value or "")).strip()


def norm_lower(value) -> str:
    return normalize(value).lower()


def normalize_options(options) -> tuple:
    return tuple(norm_lower(option) for option in (options or []))


# --- anchor extraction -----------------------------------------------------

# English words that are too common to identify a concept.
COMMON_WORDS = set(
    """
the a an of in to and or is are was were for on at by with as be that this these those
no not any all none other more most less least such than then there here its his her
their our your my he she it we they from into between about both each other every some
what which who how why when where will would can could should may might must shall
has have had do does did been being
note table figure diagram chart image picture graph unit cm mm kg km sq mt mtr
year years part chapter section question answer options marks mark choose correct
incorrect true false above below left right new old best use used using given following
according passage poem line lines word words mean meaning translation antonym synonym
spelling grammar vocabulary sentence sentences
hindi english mathematics science evs social studies child development pedagogy
""".split()
)

# Acronyms that are normally spelled out in the English text.  The English
# side satisfies the anchor when it contains either the acronym itself or
# one of these expansions.
ACRONYM_EXPANSIONS: dict[str, tuple[str, ...]] = {
    "zpd": ("zone of proximal development",),
    "mko": ("more knowledgeable other",),
    "iq": ("intelligence quotient",),
    "asd": ("autism spectrum disorder",),
    "adhd": ("attention deficit hyperactivity disorder",),
    "evs": ("environmental studies",),
    "eia": ("environment impact assessment",),
    "cce": ("continuous and comprehensive evaluation",),
    "lcm": ("least common multiple", "common multiple"),
    "hcf": ("highest common factor", "common factor"),
    "tlm": ("teaching learning material",),
    "ncf": ("national curriculum framework",),
    "wii": ("wildlife institute of india",),
    "cdp": ("child development and pedagogy",),
    "ncert": ("national council of educational research and training",),
    "nios": ("national institute of open schooling",),
    "cbse": ("central board of secondary education",),
    "cra": ("concrete-representational-abstract",),
    "uv": ("ultraviolet",),
}

_PARENTHESISED = re.compile(r"\(([^)]*)\)")
_QUOTED = re.compile(r"'([^']*)'|\"([^\"]*)\"")
_LATIN_WORD = re.compile(r"[A-Za-z][A-Za-z'\-]{2,}")
_ALLCAPS_ACRONYM = re.compile(r"\b[A-Z]{2,5}\b")


def _words(chunk: str) -> list[str]:
    return [word.lower() for word in _LATIN_WORD.findall(chunk or "")]


def _is_acronym(word: str) -> bool:
    return word.isupper() and 2 <= len(word) <= 5


def anchor_terms(text) -> list[str]:
    """Latin anchor terms of a Hindi string.

    Only terms that were put in parentheses or in quotes are treated as
    anchors, plus isolated ALL-CAPS acronyms.  Free running English text
    inside a bilingual option is *not* an anchor - it is a translation of
    the option, not its identity.
    """
    text = str(text or "")
    found: list[str] = []
    for match in _PARENTHESISED.finditer(text):
        chunk = match.group(1)
        words = _words(chunk)
        if not words:
            continue
        # A long inline phrase is a translation of the option, not an anchor.
        if len(words) > 2:
            continue
        for word in words:
            if len(word) < 3 or word in COMMON_WORDS or word in found:
                continue
            found.append(word)
    for match in _QUOTED.finditer(text):
        chunk = match.group(1) or match.group(2) or ""
        words = _words(chunk)
        if len(words) > 3:
            continue
        for word in words:
            if len(word) < 3 or word in COMMON_WORDS or word in found:
                continue
            found.append(word)
    for match in _ALLCAPS_ACRONYM.finditer(text):
        word = match.group(0).lower()
        if len(word) < 3 or word in COMMON_WORDS or word in found:
            continue
        found.append(word)
    return found


_INFLECTIONS = ("ing", "ed", "al", "tion", "s", "es", "ity", "y")


def _contains_anchor(english_text: str, anchor: str) -> bool:
    """True when the English text keeps the meaning of the anchor."""
    english_text = (english_text or "").lower()
    if not english_text:
        return False
    if anchor in english_text:
        return True
    expansions = ACRONYM_EXPANSIONS.get(anchor)
    if expansions and any(expansion in english_text for expansion in expansions):
        return True
    # A morphological variant ("rehearsal" -> "rehearsed") is fine, but the
    # English word has to keep almost the whole anchor ("behaviorism" may
    # not become "behavior").
    for suffix_length in (3, 2, 1):
        if len(anchor) - suffix_length < 4:
            break
        tail = anchor[-suffix_length:]
        if tail not in _INFLECTIONS:
            continue
        prefix = anchor[:-suffix_length]
        if re.search(r"\b" + re.escape(prefix), english_text):
            return True
    return False


def stem_anchor_violation(hindi: str, english: str) -> list[str]:
    """Anchors of the Hindi stem that are missing from the English stem."""
    if not (english or "").strip():
        return []
    return [
        anchor
        for anchor in anchor_terms(hindi)
        if not _contains_anchor(english, anchor)
    ]


def option_anchor_violation(hindi_options, english_options) -> list[tuple[int, str]]:
    """Positions where the English option drops the anchor of the Hindi one."""
    if not hindi_options or not english_options:
        return []
    if len(hindi_options) != len(english_options):
        return []
    violations = []
    for index, (hindi, english) in enumerate(zip(hindi_options, english_options)):
        # A bilingual option ("equal grouping (inverse of multiplication) /
        # पुनरावृत घटाव ...") carries several translations at once; its Latin
        # words are not anchors.
        if "/" in str(hindi):
            continue
        anchors = anchor_terms(hindi)
        if not anchors:
            continue
        if not any(_contains_anchor(english, anchor) for anchor in anchors):
            violations.append((index, ",".join(anchors)))
    return violations


# --- answer key helpers ----------------------------------------------------

def option_text(options, answer) -> str:
    """The text of the option the answer key points at."""
    if options is None or answer is None:
        return ""
    if not isinstance(answer, int) or isinstance(answer, bool):
        return ""
    if answer < 0 or answer >= len(options):
        return ""
    return norm_lower(options[answer])
