#!/usr/bin/env python3
"""Renderuje warianty półtonowe sygnałów odchyłki dla iOS z próbek wariant1/.

Dlaczego SoX, a nie librosa:
  Android podnosi wysokość próbki w RUNTIME silnikiem Sonic
  (PlaybackParams.setPitch, time-domain WSOLA) — brzmi ostro, bez rozmycia.
  Pierwsza wersja iOS renderowała offline przez librosa.effects.pitch_shift
  (phase vocoder, okno FFT 2048). Na krótkich próbkach (40–200 ms) phase vocoder
  rozmazuje transjenty = słyszalne „zmiękczenie” (zgłoszone przez użytkownika:
  „na Androidzie słychać zdecydowanie lepiej”). SoX `pitch` z krótkim segmentem
  to time-domain WSOLA — ten sam typ przetwarzania co Sonic, więc brzmienie
  jest bliższe Androidowi.

Wynik: 51 plików w ios/BSE/BSE/Resources/Signals/
  sig_center.wav                — na kursie, naturalna wysokość
  sig_{left,right}_00..24.wav   — odchyłka, 0..24 półtony w górę

Uruchomienie (SoX musi być w PATH):
  python3 tools/render_signals.py
"""
import os
import subprocess
import tempfile
import wave

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "wariant1")
OUT = os.path.join(REPO, "ios", "BSE", "BSE", "Resources", "Signals")

# Długość segmentu WSOLA w ms. Mniejszy = ostrzej na krótkich próbkach, ale
# większe ryzyko artefaktów okresowości. 40 ms to kompromis dostrojony uchem.
SEGMENT_MS = "40"
MAX_SEMITONE = 24
# Normalizacja szczytu (-0.26 dBFS ≈ 0.97 FS) — jak decodeWav na Androidzie:
# wyrównuje głośność między 0/l1/r1 i podbija ciche nagrania.
NORM_DB = "-0.26"


def sox(args):
    r = subprocess.run(["sox"] + args, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError("SOX FAIL: " + " ".join(args) + "\n" + r.stderr)


def frames(path):
    w = wave.open(path)
    n = w.getnframes()
    w.close()
    return n


def render(mono_src, out_path, semitones):
    if semitones == 0:
        sox([mono_src, "-b", "16", out_path, "gain", "-n", NORM_DB])
    else:
        sox([mono_src, "-b", "16", out_path,
             "pitch", str(semitones * 100), SEGMENT_MS, "gain", "-n", NORM_DB])


def main():
    os.makedirs(OUT, exist_ok=True)
    tmp = tempfile.mkdtemp()
    mono = {}
    for name, src in [("center", "0.wav"), ("left", "l1.wav"), ("right", "r1.wav")]:
        d = os.path.join(tmp, f"{name}_mono.wav")
        # -c 1 downmiksuje ewentualne stereo (l1.wav bywa stereo) do mono.
        sox([os.path.join(SRC, src), "-c", "1", "-b", "16", "-r", "44100", d])
        mono[name] = d

    render(mono["center"], os.path.join(OUT, "sig_center.wav"), 0)

    for side in ("left", "right"):
        src = mono[side]
        sn = frames(src)
        for st in range(0, MAX_SEMITONE + 1):
            op = os.path.join(OUT, f"sig_{side}_{st:02d}.wav")
            render(src, op, st)
            on = frames(op)
            # WSOLA zachowuje długość z dokładnością do kilku %; ostrzegamy gdy
            # odchylenie przekracza 6% (parytet z Androidem = długość bez zmian).
            if abs(on - sn) / sn > 0.06:
                print(f"UWAGA {side} +{st}pt: długość {on} vs {sn} (>6%)")

    count = len([f for f in os.listdir(OUT) if f.endswith(".wav")])
    print(f"Gotowe: {count} plików w {OUT}")


if __name__ == "__main__":
    main()
