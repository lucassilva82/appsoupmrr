#!/usr/bin/env python3
"""Folha de quadros para conferir cortes: folha.py video.mp4 saida.png 1.0 2.5 ...

Lê o vídeo em sequência (o seek do OpenCV falha nas gravações do simulador).
"""
import sys

import cv2
import numpy as np

video, saida, tempos = sys.argv[1], sys.argv[2], sorted(float(x) for x in sys.argv[3:])
cap, quadros, j = cv2.VideoCapture(video), [], 0
while j < len(tempos) and cap.grab():
    t = cap.get(cv2.CAP_PROP_POS_MSEC) / 1000
    ok, f = cap.retrieve()
    while j < len(tempos) and t >= tempos[j]:
        g = cv2.resize(f, (300, int(300 * f.shape[0] / f.shape[1])))
        cv2.putText(g, f'{tempos[j]:.2f}', (8, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 255), 2)
        quadros.append(g)
        j += 1
cv2.imwrite(saida, np.hstack(quadros))
