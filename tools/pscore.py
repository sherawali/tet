# -*- coding: utf-8 -*-
"""
«आने की संभावना» का formula।
यही वो गणित है जिससे बने मॉक से UTET 29-सित-2026 के असली पेपर में 5–10 प्रश्न मिले।
build.py इसे अपने-आप चलाता है — हाथ से कुछ नहीं भरना, सिर्फ़ CSV में `years` लिखना है।
"""
import math

YEAR_W = {"2021":0.08, "2022":0.12, "2023":0.20, "2024":0.30, "2025":0.50, "2026":0.60}
N_YEARS = 3

def concept_score(years):
    years=[y for y in years if y]
    k=len(years)
    laplace=(k+1)/(N_YEARS+2)
    lam=sum(YEAR_W.get(y,0.25) for y in years)
    recency=1-math.exp(-2.2*lam) if lam else 0.0
    return 0.55*laplace + 0.45*recency

def topic_score(topic_years):
    return (topic_years+1)/(N_YEARS+2)

def p_score(years, topic_years, is_pyq):
    s = 0.60*concept_score(years) + 0.40*topic_score(topic_years)
    if is_pyq: s = min(1.0, s*1.15)
    return round(s, 4)
