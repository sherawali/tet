# -*- coding: utf-8 -*-
"""आने की संभावना का formula (build.py इसे खुद इस्तेमाल करता है)"""
import math
YEAR_W={"2019":0.04,"2020":0.06,"2021":0.08,"2022":0.12,"2023":0.20,"2024":0.30,"2025":0.50,"2026":0.60}
N_YEARS=3

def p_score(years, topic_years, is_pyq):
    years=[y for y in years if y]
    laplace=(len(years)+1)/(N_YEARS+2)
    lam=sum(YEAR_W.get(y,0.25) for y in years)
    recency=1-math.exp(-2.2*lam) if lam else 0.0
    concept=0.55*laplace+0.45*recency
    topic=(topic_years+1)/(N_YEARS+2)
    s=0.60*concept+0.40*topic
    if is_pyq: s=min(1.0, s*1.15)
    return round(s,4)
