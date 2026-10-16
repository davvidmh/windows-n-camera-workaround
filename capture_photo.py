"""Explicit local webcam capture for Windows; saves one photo, never uploads it."""
import argparse
import json
import os
from pathlib import Path
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--index', type=int, default=0, help='Camera index (default: 0)')
    parser.add_argument('--output', type=Path, default=Path('foto-prueba.jpg'))
    parser.add_argument('--overwrite', action='store_true')
    args = parser.parse_args()
    if os.name != 'nt':
        parser.error('This diagnostic uses Windows DirectShow.')
    if args.index < 0:
        parser.error('--index must be nonnegative')
    if args.output.exists() and not args.overwrite:
        parser.error('Output already exists; choose another path or use --overwrite.')
    if args.output.suffix.lower() not in {'.jpg', '.jpeg', '.png'}:
        parser.error('Use a .jpg, .jpeg, or .png output path.')
    if not args.output.parent.is_dir():
        parser.error('Output directory does not exist.')

    try:
        import cv2
    except ImportError:
        parser.error('OpenCV is missing. Install requirements.txt first.')

    capture = cv2.VideoCapture(args.index, cv2.CAP_DSHOW)
    try:
        if not capture.isOpened():
            raise RuntimeError('Cannot open camera with DirectShow.')
        capture.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        capture.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        deadline = time.monotonic() + 12
        frame = None
        frames = 0
        while time.monotonic() < deadline:
            ok, candidate = capture.read()
            if ok and candidate is not None and candidate.size:
                frame = candidate
                frames += 1
                if frames >= 45:
                    break
            else:
                time.sleep(0.1)
        if frame is None:
            raise RuntimeError('Camera opened but delivered no valid frames.')
        ok, encoded = cv2.imencode(args.output.suffix, frame)
        if not ok:
            raise RuntimeError('Cannot encode captured photo.')
        # Exclusive creation prevents accidental replacement, including races.
        with args.output.open('wb' if args.overwrite else 'xb') as output:
            output.write(encoded.tobytes())
        print(json.dumps({
            'file': str(args.output.resolve()),
            'width': int(frame.shape[1]),
            'height': int(frame.shape[0]),
            'frames': frames,
            'next_step': 'Open the photo and verify the real scene visually.',
        }))
    finally:
        capture.release()


if __name__ == '__main__':
    main()
