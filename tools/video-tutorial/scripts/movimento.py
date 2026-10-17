#!/usr/bin/env python3
"""Trechos com movimento numa gravação: movimento.py video.mp4

O início de cada trecho é o instante em que a tela reagiu a um toque.
"""
import cv2, sys, numpy as np
cap = cv2.VideoCapture(sys.argv[1]); prev=None; ativos=[]
while cap.grab():
    t = cap.get(cv2.CAP_PROP_POS_MSEC)/1000; ok, f = cap.retrieve()
    g = cv2.cvtColor(cv2.resize(f,(201,437)), cv2.COLOR_BGR2GRAY).astype(np.int16)
    if prev is not None and np.abs(g-prev).mean() > 0.15: ativos.append(t)
    prev = g
seg=[]
for t in ativos:
    if seg and t-seg[-1][1] < 0.35: seg[-1][1]=t
    else: seg.append([t,t])
print(' '.join(f'{a:.2f}-{b:.2f}' for a,b in seg))
