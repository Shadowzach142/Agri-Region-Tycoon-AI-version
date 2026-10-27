"""
compose_soundtracks.py
Synthesizes authentic 8-bit / 16-bit retro chiptune peaceful farming soundtracks
for Agri-Region Tycoon in 44.1kHz 16-bit stereo PCM WAV.
"""

import math
import struct
import wave
import random
import os

SAMPLE_RATE = 44100

# Standard Note Frequencies (A4 = 440 Hz)
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
NOTE_FREQ = {}
for octave in range(0, 9):
    for i, name in enumerate(NOTE_NAMES):
        midi_num = (octave + 1) * 12 + i
        freq = 440.0 * (2.0 ** ((midi_num - 69) / 12.0))
        NOTE_FREQ[f"{name}{octave}"] = freq
        # Aliases
        if "#" in name:
            flat_name = NOTE_NAMES[(i + 1) % 12] + "b"
            NOTE_FREQ[f"{flat_name}{octave}"] = freq
NOTE_FREQ["REST"] = 0.0

def get_freq(note_str):
    if not note_str or note_str == "-" or note_str == "REST":
        return 0.0
    return NOTE_FREQ.get(note_str, 0.0)

def pulse_wave(phase, duty=0.5):
    """Generates an antialiased-like pulse/square wave."""
    norm_phase = phase % 1.0
    return 1.0 if norm_phase < duty else -1.0

def triangle_wave(phase):
    """Generates a smooth triangle wave (NES style)."""
    norm = phase % 1.0
    if norm < 0.5:
        return 4.0 * norm - 1.0
    else:
        return 3.0 - 4.0 * norm

def generate_envelope(total_samples, attack_s, decay_s, sustain_lvl, release_s, gate_s):
    """Generates an ADSR envelope array."""
    env = [0.0] * total_samples
    gate_samples = int(gate_s * SAMPLE_RATE)
    att_samples = max(1, int(attack_s * SAMPLE_RATE))
    dec_samples = max(1, int(decay_s * SAMPLE_RATE))
    rel_samples = max(1, int(release_s * SAMPLE_RATE))

    for i in range(total_samples):
        t = i / SAMPLE_RATE
        if i < gate_samples:
            if i < att_samples:
                val = i / att_samples
            elif i < att_samples + dec_samples:
                progress = (i - att_samples) / dec_samples
                val = 1.0 - (1.0 - sustain_lvl) * progress
            else:
                val = sustain_lvl
        else:
            rel_i = i - gate_samples
            if rel_i < rel_samples:
                val = sustain_lvl * (1.0 - rel_i / rel_samples)
            else:
                val = 0.0
        env[i] = val
    return env

class ChiptuneSynth:
    def __init__(self, bpm=100, total_beats=64):
        self.bpm = bpm
        self.seconds_per_beat = 60.0 / bpm
        self.total_seconds = total_beats * self.seconds_per_beat
        self.total_samples = int(self.total_seconds * SAMPLE_RATE)
        self.left_channel = [0.0] * self.total_samples
        self.right_channel = [0.0] * self.total_samples

    def add_note(self, start_beat, duration_beats, freq, duty=0.5, volume=0.5, pan=0.0,
                 vibrato_depth=0.015, vibrato_speed=4.8, wave_type="pulse",
                 attack=0.015, decay=0.08, sustain=0.75, release=0.04):
        if freq <= 0.0:
            return

        start_sample = int(start_beat * self.seconds_per_beat * SAMPLE_RATE)
        gate_seconds = duration_beats * self.seconds_per_beat * 0.92
        total_seconds = duration_beats * self.seconds_per_beat
        note_samples = int(total_seconds * SAMPLE_RATE)

        if start_sample >= self.total_samples:
            return
        actual_samples = min(note_samples, self.total_samples - start_sample)

        env = generate_envelope(actual_samples, attack, decay, sustain, release, gate_seconds)

        # Pan gains
        # pan in [-1.0 (left), 1.0 (right)]
        left_gain = volume * (0.707 * (1.0 - pan))
        right_gain = volume * (0.707 * (1.0 + pan))

        phase = 0.0
        vibrato_delay_samples = int(0.12 * SAMPLE_RATE)

        for i in range(actual_samples):
            # Vibrato calculation
            current_freq = freq
            if i > vibrato_delay_samples and vibrato_depth > 0.0:
                vib_t = (i - vibrato_delay_samples) / SAMPLE_RATE
                current_freq *= (1.0 + vibrato_depth * math.sin(2.0 * math.pi * vibrato_speed * vib_t))

            phase += current_freq / SAMPLE_RATE
            
            if wave_type == "pulse":
                s = pulse_wave(phase, duty)
            elif wave_type == "triangle":
                s = triangle_wave(phase)
            else:
                s = math.sin(2.0 * math.pi * phase)

            amp = s * env[i]
            idx = start_sample + i
            self.left_channel[idx] += amp * left_gain
            self.right_channel[idx] += amp * right_gain

    def add_drum_kick(self, start_beat, volume=0.45):
        start_sample = int(start_beat * self.seconds_per_beat * SAMPLE_RATE)
        dur_samples = int(0.12 * SAMPLE_RATE)
        if start_sample >= self.total_samples:
            return
        actual = min(dur_samples, self.total_samples - start_sample)
        phase = 0.0
        for i in range(actual):
            t = i / dur_samples
            cur_f = 120.0 * (1.0 - t * 0.75) + 35.0
            phase += cur_f / SAMPLE_RATE
            amp = math.sin(2.0 * math.pi * phase) * ((1.0 - t) ** 2.0) * volume
            idx = start_sample + i
            self.left_channel[idx] += amp * 0.7
            self.right_channel[idx] += amp * 0.7

    def add_drum_snare(self, start_beat, volume=0.28):
        start_sample = int(start_beat * self.seconds_per_beat * SAMPLE_RATE)
        dur_samples = int(0.10 * SAMPLE_RATE)
        if start_sample >= self.total_samples:
            return
        actual = min(dur_samples, self.total_samples - start_sample)
        # Random noise with decaying envelope + low tone
        rng = random.Random(start_beat * 1000)
        phase = 0.0
        for i in range(actual):
            t = i / dur_samples
            noise = (rng.random() * 2.0 - 1.0) * ((1.0 - t) ** 1.8)
            cur_f = 180.0 * (1.0 - t)
            phase += cur_f / SAMPLE_RATE
            tone = math.sin(2.0 * math.pi * phase) * ((1.0 - t) ** 2.5) * 0.5
            amp = (noise * 0.7 + tone * 0.3) * volume
            idx = start_sample + i
            self.left_channel[idx] += amp * 0.7
            self.right_channel[idx] += amp * 0.7

    def add_drum_hihat(self, start_beat, volume=0.14, is_open=False):
        start_sample = int(start_beat * self.seconds_per_beat * SAMPLE_RATE)
        dur_s = 0.06 if is_open else 0.025
        dur_samples = int(dur_s * SAMPLE_RATE)
        if start_sample >= self.total_samples:
            return
        actual = min(dur_samples, self.total_samples - start_sample)
        rng = random.Random(int(start_beat * 2000))
        # Highpass filtered noise
        last_val = 0.0
        for i in range(actual):
            t = i / dur_samples
            raw = rng.random() * 2.0 - 1.0
            hp = raw - last_val * 0.8
            last_val = raw
            amp = hp * ((1.0 - t) ** 2.0) * volume
            idx = start_sample + i
            self.left_channel[idx] += amp * 0.6
            self.right_channel[idx] += amp * 0.8

    def apply_subtle_stereo_delay(self, delay_ms=180, feedback=0.22, wet=0.25):
        """Adds vintage warmth and cozy atmosphere via a light chiptune ping-pong delay."""
        delay_samples = int(delay_ms * 0.001 * SAMPLE_RATE)
        for i in range(delay_samples, self.total_samples):
            # Left gets delayed right, right gets delayed left
            self.left_channel[i] += self.right_channel[i - delay_samples] * feedback * wet
            self.right_channel[i] += self.left_channel[i - delay_samples] * feedback * wet

    def export_wav(self, output_path):
        """Normalizes audio to -1.5 dB peak and writes 16-bit stereo WAV."""
        max_amp = 0.0001
        for i in range(self.total_samples):
            if abs(self.left_channel[i]) > max_amp:
                max_amp = abs(self.left_channel[i])
            if abs(self.right_channel[i]) > max_amp:
                max_amp = abs(self.right_channel[i])

        target_peak = 0.84  # -1.5 dB
        norm_factor = target_peak / max_amp if max_amp > target_peak else 1.0

        os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)
        with wave.open(output_path, "wb") as wf:
            wf.setnchannels(2)
            wf.setsampwidth(2)
            wf.setframerate(SAMPLE_RATE)
            frames = bytearray()
            for i in range(self.total_samples):
                l = int(max(-32767, min(32767, self.left_channel[i] * norm_factor * 32767.0)))
                r = int(max(-32767, min(32767, self.right_channel[i] * norm_factor * 32767.0)))
                frames.extend(struct.pack("<hh", l, r))
            wf.writeframes(frames)
        print(f"Exported: {output_path} ({self.total_seconds:.1f}s, {self.total_samples} samples)")

def compose_countryside_morning(synth):
    """
    Track 1: 'Awit ng Bukid' / Countryside Morning
    BPM 104, 4/4 time, G Major.
    A bright, uplifting, cozy morning farming theme with walking triangle bass,
    sparkling chiptune arpeggios, and a joyful whistling pulse melody.
    """
    total_bars = 32  # 128 beats
    
    # 1. Accompaniment & Bass Progression (32 bars)
    chord_chart = [
        # Intro (bars 1-4)
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),

        # Verse A (bars 5-12)
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("Em", ["G3", "B3", "E4", "G4"], "E2"),
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("Am", ["A3", "C4", "E4", "A4"], "A2"),
        ("D7", ["F#3", "C4", "D4", "F#4"], "D2"),

        # Verse B (bars 13-20)
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("Em", ["G3", "B3", "E4", "G4"], "E2"),
        ("D7", ["F#3", "A3", "C4", "D4"], "D2"),

        # Chorus (bars 21-28)
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("Em", ["G3", "B3", "E4", "G4"], "E2"),
        ("Am", ["A3", "C4", "E4", "A4"], "A2"),
        ("D7", ["F#3", "C4", "D4", "F#4"], "D2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),

        # Outro loopback (bars 29-32)
        ("C", ["G3", "C4", "E4", "G4"], "C2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("Am", ["A3", "C4", "E4", "A4"], "A2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
    ]

    # Generate Bass & Arpeggio layers
    for bar_idx, (chord_name, arp_notes, root_note) in enumerate(chord_chart):
        bar_start = bar_idx * 4.0

        # Bass (Triangle wave, bouncing root-fifth rhythm)
        fifth_note = arp_notes[2]
        fifth_name = fifth_note[:-1] + str(int(fifth_note[-1]) - 1)

        synth.add_note(bar_start + 0.0, 1.2, get_freq(root_note), wave_type="triangle", volume=0.48, pan=0.0)
        synth.add_note(bar_start + 1.5, 0.5, get_freq(root_note), wave_type="triangle", volume=0.42, pan=0.0)
        synth.add_note(bar_start + 2.0, 1.0, get_freq(fifth_name), wave_type="triangle", volume=0.45, pan=0.0)
        synth.add_note(bar_start + 3.0, 0.8, get_freq(root_note), wave_type="triangle", volume=0.40, pan=0.0)

        # Arpeggios (25% pulse, sparkling background texture, panned left)
        arp_pattern = [0, 1, 2, 3, 2, 1, 2, 3]
        for step in range(8):
            note_str = arp_notes[arp_pattern[step]]
            synth.add_note(bar_start + step * 0.5, 0.42, get_freq(note_str), duty=0.25,
                           volume=0.18, pan=-0.35, attack=0.01, decay=0.06, sustain=0.4, release=0.05)

        # Drums: Cozy brush & bass kick
        synth.add_drum_kick(bar_start + 0.0, volume=0.38)
        synth.add_drum_kick(bar_start + 2.0, volume=0.32)
        synth.add_drum_snare(bar_start + 1.0, volume=0.22)
        synth.add_drum_snare(bar_start + 3.0, volume=0.22)
        for h in range(8):
            synth.add_drum_hihat(bar_start + h * 0.5, volume=0.08 if h % 2 != 0 else 0.12)

    # Lead Melody (50% pulse wave with vibrato, panned slightly right)
    melody = [
        # Intro Lead motif (Bars 1-4: beats 0-16)
        (0.0, 1.0, "G4"), (1.0, 0.5, "B4"), (1.5, 0.5, "D5"), (2.0, 1.5, "B4"), (3.5, 0.5, "A4"),
        (4.0, 1.0, "G4"), (5.0, 0.5, "E4"), (5.5, 0.5, "G4"), (6.0, 2.0, "E4"),
        (8.0, 1.0, "G4"), (9.0, 0.5, "B4"), (9.5, 0.5, "D5"), (10.0, 1.5, "E5"), (11.5, 0.5, "D5"),
        (12.0, 2.0, "B4"), (14.0, 1.5, "A4"), (15.5, 0.5, "D4"),

        # Verse A (Bars 5-12: beats 16-48)
        (16.0, 1.0, "G4"), (17.0, 0.5, "A4"), (17.5, 0.5, "B4"), (18.0, 1.0, "D5"), (19.0, 1.0, "B4"),
        (20.0, 1.0, "C5"), (21.0, 0.5, "B4"), (21.5, 0.5, "A4"), (22.0, 2.0, "G4"),
        (24.0, 1.0, "F#4"), (25.0, 0.5, "G4"), (25.5, 0.5, "A4"), (26.0, 1.5, "D5"), (27.5, 0.5, "C5"),
        (28.0, 2.5, "B4"), (30.5, 0.5, "G4"), (31.0, 0.5, "B4"),
        (32.0, 1.0, "E5"), (33.0, 0.5, "D5"), (33.5, 0.5, "B4"), (34.0, 1.5, "G4"), (35.5, 0.5, "A4"),
        (36.0, 1.0, "C5"), (37.0, 0.5, "B4"), (37.5, 0.5, "A4"), (38.0, 2.0, "G4"),
        (40.0, 1.0, "A4"), (41.0, 0.5, "B4"), (41.5, 0.5, "C5"), (42.0, 1.0, "E5"), (43.0, 1.0, "D5"),
        (44.0, 2.0, "F#4"), (46.0, 1.5, "A4"), (47.5, 0.5, "B4"),

        # Verse B (Bars 13-20: beats 48-80)
        (48.0, 1.5, "G4"), (49.5, 0.5, "B4"), (50.0, 1.0, "D5"), (51.0, 1.0, "G5"),
        (52.0, 2.0, "F#5"), (54.0, 1.0, "D5"), (55.0, 1.0, "B4"),
        (56.0, 1.0, "C5"), (57.0, 0.5, "D5"), (57.5, 0.5, "E5"), (58.0, 1.5, "G5"), (59.5, 0.5, "E5"),
        (60.0, 2.5, "D5"), (62.5, 0.5, "B4"), (63.0, 0.5, "C5"),
        (64.0, 1.0, "D5"), (65.0, 0.5, "E5"), (65.5, 0.5, "D5"), (66.0, 1.0, "C5"), (67.0, 1.0, "B4"),
        (68.0, 1.5, "A4"), (69.5, 0.5, "G4"), (70.0, 2.0, "F#4"),
        (72.0, 1.0, "G4"), (73.0, 0.5, "A4"), (73.5, 0.5, "B4"), (74.0, 1.5, "D5"), (75.5, 0.5, "E5"),
        (76.0, 2.0, "D5"), (78.0, 1.5, "A4"), (79.5, 0.5, "D4"),

        # Chorus (Bars 21-28: beats 80-112)
        (80.0, 1.0, "E5"), (81.0, 0.5, "F#5"), (81.5, 0.5, "G5"), (82.0, 1.5, "G5"), (83.5, 0.5, "F#5"),
        (84.0, 1.0, "F#5"), (85.0, 0.5, "E5"), (85.5, 0.5, "D5"), (86.0, 2.0, "D5"),
        (88.0, 1.0, "D5"), (89.0, 0.5, "C5"), (89.5, 0.5, "B4"), (90.0, 1.5, "B4"), (91.5, 0.5, "A4"),
        (92.0, 2.0, "G4"), (94.0, 1.0, "B4"), (95.0, 1.0, "D5"),
        (96.0, 1.0, "C5"), (97.0, 0.5, "D5"), (97.5, 0.5, "E5"), (98.0, 1.5, "A5"), (99.5, 0.5, "G5"),
        (100.0, 2.0, "F#5"), (102.0, 1.0, "E5"), (103.0, 1.0, "F#5"),
        (104.0, 2.5, "G5"), (106.5, 0.5, "D5"), (107.0, 0.5, "B4"), (107.5, 0.5, "G4"),
        (108.0, 2.0, "A4"), (110.0, 1.5, "D5"), (111.5, 0.5, "C5"),

        # Outro loopback (Bars 29-32: beats 112-128)
        (112.0, 1.0, "B4"), (113.0, 0.5, "C5"), (113.5, 0.5, "D5"), (114.0, 1.5, "E5"), (115.5, 0.5, "D5"),
        (116.0, 2.0, "B4"), (118.0, 1.0, "G4"), (119.0, 1.0, "B4"),
        (120.0, 1.5, "A4"), (121.5, 0.5, "G4"), (122.0, 1.0, "E4"), (123.0, 1.0, "A4"),
        (124.0, 2.0, "G4"), (126.0, 1.5, "F#4"), (127.5, 0.5, "D4")
    ]

    for start_b, dur_b, n_str in melody:
        synth.add_note(start_b, dur_b, get_freq(n_str), duty=0.5, volume=0.44, pan=0.25,
                       vibrato_depth=0.018, vibrato_speed=4.8, attack=0.02, decay=0.06, sustain=0.8, release=0.05)


def compose_pastoral_breeze(synth):
    """
    Track 2: 'Hanging Habagat' / Pastoral Breeze
    BPM 92, 3/4 swaying waltz / pastoral dance, C Major / F Major.
    Gentle, swaying rhythm like coconut palms and green rice terraces in the breeze.
    """
    chords = [
        # Section A: Gentle morning breeze (bars 1-12)
        ("C", ["G3", "C4", "E4"], "C2"),
        ("G", ["G3", "B3", "D4"], "G2"),
        ("Am", ["A3", "C4", "E4"], "A2"),
        ("Em", ["G3", "B3", "E4"], "E2"),
        ("F", ["A3", "C4", "F4"], "F2"),
        ("C", ["G3", "C4", "E4"], "C2"),
        ("Dm", ["F3", "A3", "D4"], "D2"),
        ("G7", ["F3", "G3", "B3"], "G2"),
        ("C", ["G3", "C4", "E4"], "C2"),
        ("Em", ["G3", "B3", "E4"], "E2"),
        ("F", ["A3", "C4", "F4"], "F2"),
        ("G", ["G3", "B3", "D4"], "G2"),

        # Section B: Swaying tropical palms (bars 13-24)
        ("Fmaj7", ["A3", "C4", "E4", "F4"], "F2"),
        ("G", ["G3", "B3", "D4"], "G2"),
        ("Em7", ["G3", "B3", "D4", "E4"], "E2"),
        ("Am", ["A3", "C4", "E4"], "A2"),
        ("Dm7", ["F3", "A3", "C4", "D4"], "D2"),
        ("G7", ["F3", "G3", "B3", "D4"], "G2"),
        ("C", ["G3", "C4", "E4"], "C2"),
        ("C7", ["G3", "Bb3", "C4", "E4"], "C2"),
        ("Fmaj7", ["A3", "C4", "E4"], "F2"),
        ("G", ["G3", "B3", "D4"], "G2"),
        ("Em7", ["G3", "B3", "D4"], "E2"),
        ("Am", ["A3", "C4", "E4"], "A2"),

        # Section C: Sunset calm (bars 25-36)
        ("Dm", ["F3", "A3", "D4"], "D2"),
        ("G", ["G3", "B3", "D4"], "G2"),
        ("C", ["G3", "C4", "E4"], "C2"),
        ("Am", ["A3", "C4", "E4"], "A2"),
        ("Dm", ["F3", "A3", "D4"], "D2"),
        ("G7", ["F3", "G3", "B3"], "G2"),
        ("C", ["G3", "C4", "E4"], "C2"),
        ("Em", ["G3", "B3", "E4"], "E2"),
        ("F", ["A3", "C4", "F4"], "F2"),
        ("Dm7", ["F3", "A3", "C4"], "D2"),
        ("G7", ["F3", "G3", "B3"], "G2"),
        ("C", ["G3", "C4", "E4"], "C2"),
    ]

    for bar_idx, (name, arp_notes, root) in enumerate(chords):
        bar_start = bar_idx * 3.0

        # Bass: Beat 1 (Triangle wave)
        synth.add_note(bar_start + 0.0, 1.4, get_freq(root), wave_type="triangle", volume=0.52, pan=0.0)
        synth.add_note(bar_start + 2.0, 0.8, get_freq(root) * 1.5, wave_type="triangle", volume=0.36, pan=0.0)

        # Chiptune Harp Chords on beats 2 & 3 (25% pulse, panned left)
        for chord_beat in [1.0, 2.0]:
            for n_idx, n_str in enumerate(arp_notes[:3]):
                synth.add_note(bar_start + chord_beat + n_idx * 0.03, 0.65, get_freq(n_str),
                               duty=0.25, volume=0.17, pan=-0.3, attack=0.015, decay=0.08, sustain=0.45, release=0.06)

        # Delicate waltz rhythm: soft kick on 1, soft brush shaker on 2 & 3
        synth.add_drum_kick(bar_start + 0.0, volume=0.34)
        synth.add_drum_hihat(bar_start + 1.0, volume=0.10)
        synth.add_drum_hihat(bar_start + 2.0, volume=0.10)

    # Lead Melody (Pastoral waltz motif, 50% pulse wave with expressive vibrato)
    melody = [
        # Bars 1-4 (beats 0-12)
        (0.0, 1.5, "E4"), (1.5, 0.5, "G4"), (2.0, 1.0, "C5"),
        (3.0, 2.0, "B4"), (5.0, 1.0, "G4"),
        (6.0, 1.5, "A4"), (7.5, 0.5, "B4"), (8.0, 1.0, "C5"),
        (9.0, 2.0, "G4"), (11.0, 1.0, "E4"),

        # Bars 5-8 (beats 12-24)
        (12.0, 1.5, "F4"), (13.5, 0.5, "G4"), (14.0, 1.0, "A4"),
        (15.0, 2.0, "G4"), (17.0, 1.0, "E4"),
        (18.0, 1.5, "D4"), (19.5, 0.5, "E4"), (20.0, 1.0, "F4"),
        (21.0, 2.5, "G4"),

        # Bars 9-12 (beats 24-36)
        (24.0, 1.5, "E4"), (25.5, 0.5, "G4"), (26.0, 1.0, "C5"),
        (27.0, 2.0, "B4"), (29.0, 1.0, "D5"),
        (30.0, 1.5, "C5"), (31.5, 0.5, "B4"), (32.0, 1.0, "A4"),
        (33.0, 2.5, "G4"),

        # Bars 13-16 (beats 36-48)
        (36.0, 1.5, "A4"), (37.5, 0.5, "C5"), (38.0, 1.0, "E5"),
        (39.0, 2.0, "D5"), (41.0, 1.0, "B4"),
        (42.0, 1.5, "G4"), (43.5, 0.5, "B4"), (44.0, 1.0, "D5"),
        (45.0, 2.0, "C5"), (47.0, 1.0, "A4"),

        # Bars 17-20 (beats 48-60)
        (48.0, 1.5, "F4"), (49.5, 0.5, "A4"), (50.0, 1.0, "D5"),
        (51.0, 2.0, "B4"), (53.0, 1.0, "G4"),
        (54.0, 2.0, "C5"), (56.0, 1.0, "E5"),
        (57.0, 2.5, "G5"),

        # Bars 21-24 (beats 60-72)
        (60.0, 1.5, "F5"), (61.5, 0.5, "E5"), (62.0, 1.0, "D5"),
        (63.0, 2.0, "E5"), (65.0, 1.0, "D5"),
        (66.0, 1.5, "C5"), (67.5, 0.5, "B4"), (68.0, 1.0, "A4"),
        (69.0, 2.5, "G4"),

        # Bars 25-28 (beats 72-84)
        (72.0, 1.5, "A4"), (73.5, 0.5, "B4"), (74.0, 1.0, "C5"),
        (75.0, 2.0, "D5"), (77.0, 1.0, "B4"),
        (78.0, 2.0, "G4"), (80.0, 1.0, "E4"),
        (81.0, 2.5, "C4"),

        # Bars 29-32 (beats 84-96)
        (84.0, 1.5, "F4"), (85.5, 0.5, "G4"), (86.0, 1.0, "A4"),
        (87.0, 2.0, "G4"), (89.0, 1.0, "B4"),
        (90.0, 2.0, "C5"), (92.0, 1.0, "D5"),
        (93.0, 2.5, "E5"),

        # Bars 33-36 (beats 96-108)
        (96.0, 1.5, "D5"), (97.5, 0.5, "C5"), (98.0, 1.0, "B4"),
        (99.0, 1.5, "A4"), (100.5, 0.5, "G4"), (101.0, 1.0, "F4"),
        (102.0, 2.0, "E4"), (104.0, 1.0, "D4"),
        (105.0, 2.8, "C4"),
    ]

    for start_b, dur_b, n_str in melody:
        synth.add_note(start_b, dur_b, get_freq(n_str), duty=0.5, volume=0.42, pan=0.2,
                       vibrato_depth=0.016, vibrato_speed=4.5, attack=0.02, decay=0.07, sustain=0.78, release=0.06)


def compose_dusk_at_homestead(synth):
    """
    Track 3: 'Takipsilim' / Dusk at the Homestead
    BPM 76, 4/4 time, D Major / B minor pentatonic.
    A dreamy, serene music-box chiptune lullaby for peaceful twilight and starry night skies.
    """
    chords = [
        # Intro: Fireflies awaken (bars 1-4)
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("A", ["E3", "A3", "C#4", "E4"], "A2"),
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("F#m", ["F#3", "A3", "C#4", "F#4"], "F#2"),

        # Verse A: Twilight over the fields (bars 5-12)
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("Em7", ["G3", "B3", "D4", "E4"], "E2"),
        ("A7", ["E3", "G3", "A3", "C#4"], "A2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("F#m", ["F#3", "A3", "C#4", "F#4"], "F#2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("A", ["E3", "A3", "C#4", "E4"], "A2"),

        # Verse B: Stars reflect on the palay irrigation (bars 13-20)
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("F#m", ["F#3", "A3", "C#4", "F#4"], "F#2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("Em", ["G3", "B3", "E4", "G4"], "E2"),
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("A7", ["E3", "G3", "A3", "C#4"], "A2"),

        # Chorus: The warm kubo lantern (bars 21-28)
        ("Gmaj7", ["F#3", "B3", "D4", "G4"], "G2"),
        ("A", ["E3", "A3", "C#4", "E4"], "A2"),
        ("F#m7", ["E3", "A3", "C#4", "F#4"], "F#2"),
        ("Bm", ["F#3", "B3", "D4", "F#4"], "B2"),
        ("Em7", ["G3", "B3", "D4", "E4"], "E2"),
        ("A7", ["E3", "G3", "C#4", "E4"], "A2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("D7", ["F#3", "A3", "C4", "D4"], "D2"),

        # Outro: Night rest (bars 29-32)
        ("G", ["G3", "B3", "D4", "G4"], "G2"),
        ("A", ["E3", "A3", "C#4", "E4"], "A2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
        ("D", ["F#3", "A3", "D4", "F#4"], "D2"),
    ]

    for bar_idx, (name, arp_notes, root) in enumerate(chords):
        bar_start = bar_idx * 4.0

        synth.add_note(bar_start + 0.0, 2.2, get_freq(root), wave_type="triangle", volume=0.46, pan=0.0)
        synth.add_note(bar_start + 2.0, 1.8, get_freq(root) * 1.5, wave_type="triangle", volume=0.36, pan=0.0)

        pattern = [0, 1, 2, 3, 2, 3, 1, 2]
        for step in range(8):
            n_str = arp_notes[pattern[step]]
            synth.add_note(bar_start + step * 0.5, 0.45, get_freq(n_str), duty=0.125,
                           volume=0.15, pan=-0.35, attack=0.01, decay=0.12, sustain=0.3, release=0.08)

        synth.add_drum_kick(bar_start + 0.0, volume=0.25)
        synth.add_drum_hihat(bar_start + 1.0, volume=0.06)
        synth.add_drum_hihat(bar_start + 2.0, volume=0.06)
        synth.add_drum_hihat(bar_start + 3.0, volume=0.06)

    # Lead Melody: Soothing lullaby (25% pulse with soft decay and warm vibrato)
    melody = [
        # Intro (bars 1-4: beats 0-16)
        (0.0, 1.5, "F#4"), (1.5, 0.5, "A4"), (2.0, 1.0, "D5"), (3.0, 1.0, "C#5"),
        (4.0, 2.0, "A4"), (6.0, 1.5, "F#4"), (7.5, 0.5, "E4"),
        (8.0, 1.5, "D4"), (9.5, 0.5, "F#4"), (10.0, 1.5, "B4"), (11.5, 0.5, "A4"),
        (12.0, 3.5, "F#4"),

        # Verse A (bars 5-12: beats 16-48)
        (16.0, 1.5, "G4"), (17.5, 0.5, "A4"), (18.0, 1.0, "B4"), (19.0, 1.0, "D5"),
        (20.0, 2.0, "A4"), (22.0, 1.5, "F#4"), (23.5, 0.5, "D4"),
        (24.0, 1.5, "E4"), (25.5, 0.5, "F#4"), (26.0, 1.0, "G4"), (27.0, 1.0, "B4"),
        (28.0, 3.0, "A4"),
        (32.0, 1.5, "D5"), (33.5, 0.5, "C#5"), (34.0, 1.0, "B4"), (35.0, 1.0, "A4"),
        (36.0, 2.0, "F#4"), (38.0, 1.5, "E4"), (39.5, 0.5, "F#4"),
        (40.0, 1.5, "G4"), (41.5, 0.5, "F#4"), (42.0, 1.0, "E4"), (43.0, 1.0, "D4"),
        (44.0, 3.5, "E4"),

        # Verse B (bars 13-20: beats 48-80)
        (48.0, 1.5, "F#4"), (49.5, 0.5, "B4"), (50.0, 1.0, "D5"), (51.0, 1.0, "F#5"),
        (52.0, 2.0, "E5"), (54.0, 1.5, "C#5"), (55.5, 0.5, "A4"),
        (56.0, 1.5, "B4"), (57.5, 0.5, "D5"), (58.0, 1.0, "G5"), (59.0, 1.0, "F#5"),
        (60.0, 3.0, "D5"),
        (64.0, 1.5, "E5"), (65.5, 0.5, "D5"), (66.0, 1.0, "B4"), (67.0, 1.0, "G4"),
        (68.0, 2.0, "F#4"), (70.0, 1.5, "D4"), (71.5, 0.5, "F#4"),
        (72.0, 2.0, "G4"), (74.0, 1.5, "B4"), (75.5, 0.5, "C#5"),
        (76.0, 3.5, "A4"),

        # Chorus (bars 21-28: beats 80-112)
        (80.0, 1.5, "B4"), (81.5, 0.5, "C#5"), (82.0, 1.0, "D5"), (83.0, 1.0, "F#5"),
        (84.0, 2.0, "E5"), (86.0, 1.5, "C#5"), (87.5, 0.5, "A4"),
        (88.0, 1.5, "F#4"), (89.5, 0.5, "A4"), (90.0, 1.0, "D5"), (91.0, 1.0, "C#5"),
        (92.0, 3.0, "B4"),
        (96.0, 1.5, "G4"), (97.5, 0.5, "B4"), (98.0, 1.0, "E5"), (99.0, 1.0, "D5"),
        (100.0, 2.0, "C#5"), (102.0, 1.5, "A4"), (103.5, 0.5, "E4"),
        (104.0, 2.5, "D4"), (106.5, 0.5, "F#4"), (107.0, 1.0, "A4"),
        (108.0, 3.5, "D5"),

        # Outro (bars 29-32: beats 112-128)
        (112.0, 1.5, "B4"), (113.5, 0.5, "A4"), (114.0, 1.0, "G4"), (115.0, 1.0, "F#4"),
        (116.0, 2.0, "E4"), (118.0, 1.5, "F#4"), (119.5, 0.5, "E4"),
        (120.0, 2.5, "D4"), (122.5, 0.5, "F#4"), (123.0, 1.0, "A4"),
        (124.0, 3.8, "D4")
    ]

    for start_b, dur_b, n_str in melody:
        synth.add_note(start_b, dur_b, get_freq(n_str), duty=0.25, volume=0.38, pan=0.2,
                       vibrato_depth=0.015, vibrato_speed=4.2, attack=0.03, decay=0.1, sustain=0.72, release=0.08)


def main():
    tracks_dir = os.path.join(os.path.dirname(__file__), "..", "sounds", "soundtracks")
    tracks_dir = os.path.abspath(tracks_dir)
    os.makedirs(tracks_dir, exist_ok=True)
    print(f"Generating soundtracks into: {tracks_dir}")

    # Track 1: Countryside Morning
    print("\n--- Composing Track 1: Countryside Morning (Awit ng Bukid) ---")
    synth1 = ChiptuneSynth(bpm=104, total_beats=128)
    compose_countryside_morning(synth1)
    synth1.apply_subtle_stereo_delay(delay_ms=175, feedback=0.22, wet=0.22)
    track1_path = os.path.join(tracks_dir, "countryside_morning.wav")
    synth1.export_wav(track1_path)

    # Track 2: Pastoral Breeze
    print("\n--- Composing Track 2: Pastoral Breeze (Hanging Habagat) ---")
    synth2 = ChiptuneSynth(bpm=92, total_beats=108)
    compose_pastoral_breeze(synth2)
    synth2.apply_subtle_stereo_delay(delay_ms=190, feedback=0.20, wet=0.20)
    track2_path = os.path.join(tracks_dir, "pastoral_breeze.wav")
    synth2.export_wav(track2_path)

    # Track 3: Dusk at Homestead
    print("\n--- Composing Track 3: Dusk at Homestead (Takipsilim) ---")
    synth3 = ChiptuneSynth(bpm=76, total_beats=128)
    compose_dusk_at_homestead(synth3)
    synth3.apply_subtle_stereo_delay(delay_ms=210, feedback=0.24, wet=0.24)
    track3_path = os.path.join(tracks_dir, "dusk_at_homestead.wav")
    synth3.export_wav(track3_path)

    print("\n[SUCCESS] All 3 peaceful chiptune soundtracks generated successfully!")

if __name__ == "__main__":
    main()

