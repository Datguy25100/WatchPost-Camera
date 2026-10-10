#!/usr/bin/env python3
"""
WatchPost edge detector (with optional face recognition).

Watches a camera (USB webcam, RTSP/HTTP stream or video file), detects motion,
optionally recognises known faces, and posts an event to your n8n WatchPost
webhook. The Flutter app picks it up and speaks it ("Mum is at the front door.").

Quick start:
    pip install -r requirements.txt
    export WATCHPOST_URL="https://nweke.app.n8n.cloud/webhook-test/watchpost"
    export WATCHPOST_KEY="@@@@0000"
    python edge.py --camera "Front door" --source 0

IP Webcam (Android app) + AI descriptions + face recognition:
    python edge.py --camera "Front door" --ip-webcam 192.168.1.50:8080 --ai --faces faces

Face photos live in a folder, one sub-folder per person (folder name = spoken name):
    faces/Mum/1.jpg 2.jpg 3.jpg
    faces/Dad/1.jpg 2.jpg 3.jpg

The two face models are downloaded automatically on first run (or put
face_detection_yunet_2023mar.onnx and face_recognition_sface_2021dec.onnx next
to this script).

Examples:
    python edge.py --camera Gate --source rtsp://user:pass@192.168.1.20:554/stream1 --people --snapshots
    python edge.py --camera Backyard --source clip.mp4 --show
"""
import argparse
import base64
import os
import queue
import signal
import sys
import threading
import time

import cv2
import numpy as np
import requests

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
YUNET_FILE = "face_detection_yunet_2023mar.onnx"
SFACE_FILE = "face_recognition_sface_2021dec.onnx"
MODEL_URLS = {
    YUNET_FILE: "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/" + YUNET_FILE,
    SFACE_FILE: "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/" + SFACE_FILE,
}
IMG_EXT = (".jpg", ".jpeg", ".png", ".bmp", ".webp")


def parse_args():
    p = argparse.ArgumentParser(description="WatchPost motion detector -> n8n")
    p.add_argument("--url", default=os.getenv("WATCHPOST_URL"),
                   help="n8n PRODUCTION webhook URL (or env WATCHPOST_URL)")
    p.add_argument("--key", default=os.getenv("WATCHPOST_KEY"),
                   help="INGEST_KEY set in the n8n API node (or env WATCHPOST_KEY)")
    p.add_argument("--camera", required=True,
                   help="Camera name exactly as shown in the app, e.g. 'Front door'")
    p.add_argument("--source", default="0",
                   help="0/1 for a webcam, an rtsp:// or http:// URL, or a video file")
    p.add_argument("--ip-webcam", metavar="IP:PORT",
                   help="Shortcut for the Android 'IP Webcam' app, e.g. 192.168.1.50:8080")
    p.add_argument("--ai", action="store_true",
                   help="Send a larger frame so n8n's LLM can describe what it sees (implies --snapshots)")
    p.add_argument("--faces", metavar="FOLDER",
                   help="Folder of known people (faces/Mum/1.jpg ...). Turns on face recognition")
    p.add_argument("--face-threshold", type=float, default=0.363,
                   help="Match strictness 0-1 (default 0.363). Raise (0.45) if strangers get named, "
                        "lower (0.30) if known people are missed")
    p.add_argument("--face-tries", type=int, default=8,
                   help="Frames to try for a clear face after motion is detected (default 8)")
    p.add_argument("--models-dir", default=SCRIPT_DIR,
                   help="Where the two .onnx face models are (default: next to edge.py)")
    p.add_argument("--min-area", type=float, default=0.01,
                   help="Fraction of the frame that must move to count (default 0.01 = 1%%)")
    p.add_argument("--confirm-frames", type=int, default=3,
                   help="Consecutive frames with motion before triggering (default 3)")
    p.add_argument("--cooldown", type=float, default=20.0,
                   help="Seconds to wait after an alert before sending another (default 20)")
    p.add_argument("--people", action="store_true",
                   help="Run a person detector on motion frames and tag them 'person'")
    p.add_argument("--snapshots", action="store_true",
                   help="Attach a small JPEG snapshot to each alert")
    p.add_argument("--width", type=int, default=480,
                   help="Frames are downscaled to this width for analysis (default 480)")
    p.add_argument("--show", action="store_true", help="Preview window (needs a display)")
    p.add_argument("--warmup", type=int, default=30,
                   help="Frames used to learn the background at start (default 30)")
    p.add_argument("--dry-run", action="store_true",
                   help="Print events instead of sending them")
    args = p.parse_args()
    if args.ip_webcam:
        host = args.ip_webcam.rstrip("/")
        if not host.startswith("http"):
            host = "http://" + host
        args.source = host + "/video"
    if args.ai:
        args.snapshots = True
    if args.faces and not os.path.isdir(args.faces):
        p.error(f"--faces folder not found: {args.faces}")
    if not args.dry_run and (not args.url or not args.key):
        p.error("--url and --key are required (or set WATCHPOST_URL / WATCHPOST_KEY)")
    if args.url and "webhook-test" in args.url:
        p.error("That is the TEST url. Use the Production URL (…/webhook/watchpost) "
                "and activate the workflow.")
    return args


def open_source(src):
    cap = cv2.VideoCapture(int(src) if src.isdigit() else src)
    if cap.isOpened():
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
    return cap


def make_snapshot(frame, max_w=240, quality=55, max_bytes=45_000):
    """Small JPEG as a data URI (kept tiny: n8n stores it in workflow storage)."""
    h, w = frame.shape[:2]
    scale = max_w / float(w)
    small = cv2.resize(frame, (max_w, int(h * scale)))
    for q in (quality, 45, 35):
        ok, buf = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, q])
        if ok and len(buf) <= max_bytes:
            return "data:image/jpeg;base64," + base64.b64encode(buf).decode()
    return None


def make_analysis_frame(frame, max_w=640, quality=70, max_bytes=300_000):
    """Larger JPEG (raw base64) sent to the LLM. Not stored by n8n."""
    h, w = frame.shape[:2]
    if w > max_w:
        frame = cv2.resize(frame, (max_w, int(h * max_w / w)))
    for q in (quality, 55, 40):
        ok, buf = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, q])
        if ok and len(buf) <= max_bytes:
            return base64.b64encode(buf).decode()
    return None


# --------------------------------------------------------------------------
# Face recognition (OpenCV YuNet detector + SFace recogniser, runs on CPU)
# --------------------------------------------------------------------------
def ensure_model(models_dir, filename):
    path = os.path.join(models_dir, filename)
    if os.path.isfile(path) and os.path.getsize(path) > 100_000:
        return path
    print(f"[faces] downloading {filename} (first run only)…", flush=True)
    try:
        r = requests.get(MODEL_URLS[filename], timeout=180)
        r.raise_for_status()
        if len(r.content) < 100_000:
            raise RuntimeError("download was too small (probably a Git LFS pointer)")
        os.makedirs(models_dir, exist_ok=True)
        with open(path, "wb") as f:
            f.write(r.content)
    except Exception as e:  # noqa: BLE001
        sys.exit(f"[faces] could not download {filename}: {e}\n"
                 f"Download it manually from https://github.com/opencv/opencv_zoo "
                 f"(models/face_detection_yunet and models/face_recognition_sface)\n"
                 f"and put it in: {models_dir}")
    return path


class FaceID:
    def __init__(self, faces_dir, models_dir, threshold):
        if not hasattr(cv2, "FaceDetectorYN") or not hasattr(cv2, "FaceRecognizerSF"):
            sys.exit("[faces] your OpenCV is too old. Run: pip install -U opencv-python")
        yunet = ensure_model(models_dir, YUNET_FILE)
        sface = ensure_model(models_dir, SFACE_FILE)
        self.det = cv2.FaceDetectorYN.create(yunet, "", (320, 320), 0.8, 0.3, 5000)
        self.rec = cv2.FaceRecognizerSF.create(sface, "")
        self.threshold = threshold
        self.db = {}  # name -> [feature, ...]
        self._enroll(faces_dir)

    @staticmethod
    def _prep(img, max_side=1280):
        h, w = img.shape[:2]
        m = max(h, w)
        if m > max_side:
            s = max_side / float(m)
            img = cv2.resize(img, (int(w * s), int(h * s)))
        return img

    def _faces_in(self, img):
        h, w = img.shape[:2]
        self.det.setInputSize((w, h))
        _, faces = self.det.detect(img)
        return [] if faces is None else list(faces)

    def _embed(self, img, face):
        return self.rec.feature(self.rec.alignCrop(img, face)).copy()

    def _enroll(self, faces_dir):
        for person in sorted(os.listdir(faces_dir)):
            pdir = os.path.join(faces_dir, person)
            if not os.path.isdir(pdir):
                continue
            feats = []
            for fn in sorted(os.listdir(pdir)):
                if not fn.lower().endswith(IMG_EXT):
                    continue
                img = cv2.imread(os.path.join(pdir, fn))
                if img is None:
                    print(f"[faces] cannot read {person}/{fn}, skipping", flush=True)
                    continue
                img = self._prep(img)
                faces = self._faces_in(img)
                if not faces:
                    print(f"[faces] no face found in {person}/{fn} - replace this photo", flush=True)
                    continue
                face = max(faces, key=lambda f: f[2] * f[3])  # largest face
                feats.append(self._embed(img, face))
            if feats:
                self.db[person] = feats
                print(f"[faces] enrolled: {person} ({len(feats)} photos)", flush=True)
            else:
                print(f"[faces] WARNING: no usable photos for {person}", flush=True)
        if not self.db:
            print("[faces] WARNING: nobody enrolled, everyone will show as Unknown", flush=True)

    def identify(self, frame):
        """Returns a list of (label, score) for every face in the frame."""
        frame = self._prep(frame)
        out = []
        for face in self._faces_in(frame):
            feat = self._embed(frame, face)
            best_name, best = None, -1.0
            for name, feats in self.db.items():
                s = max(float(self.rec.match(feat, f, cv2.FaceRecognizerSF_FR_COSINE)) for f in feats)
                if s > best:
                    best, best_name = s, name
            label = best_name if (best_name and best >= self.threshold) else "Unknown"
            out.append((label, best))
        return out


def look_for_faces(face_id, cap, first_frame, tries):
    """Try a few frames to catch a clear face. Returns (name, face_seen, frame_to_send)."""
    frame, best_frame = first_frame, first_frame
    seen, last = False, []
    for i in range(max(1, tries)):
        if i > 0:
            cap.grab()
            cap.grab()  # skip ahead a little so the person has moved
            ok, f = cap.read()
            if not ok:
                break
            frame = f
        results = face_id.identify(frame)
        if results:
            seen, last, best_frame = True, results, frame
            known = [r for r in results if r[0] != "Unknown"]
            if known:
                print(f"[faces] saw {len(results)} face(s): " + ", ".join(r[0] for r in results), flush=True)
                return max(known, key=lambda r: r[1])[0], True, frame
    if seen:
        print(f"[faces] saw {len(last)} face(s): " + ", ".join(r[0] for r in last), flush=True)
    else:
        print("[faces] no face visible (motion only)", flush=True)
    return "Unknown", seen, best_frame


class Sender(threading.Thread):
    """Posts events in the background so the camera loop never blocks."""

    def __init__(self, url, key, dry_run):
        super().__init__(daemon=True)
        self.url, self.key, self.dry_run = url, key, dry_run
        self.q = queue.Queue(maxsize=50)

    def send(self, payload):
        try:
            self.q.put_nowait(payload)
        except queue.Full:
            print("[warn] send queue full, dropping event", flush=True)

    def run(self):
        while True:
            payload = self.q.get()
            if self.dry_run:
                shown = {k: (v[:30] + "…" if k in ("image", "analysisImage") and v else v)
                         for k, v in payload.items()}
                print("[dry-run]", shown, flush=True)
                continue
            for attempt in range(1, 4):
                try:
                    r = requests.post(
                        self.url, json=payload, timeout=60,
                        headers={"x-api-key": self.key, "Content-Type": "application/json"},
                    )
                    if r.status_code == 200:
                        body = r.json()
                        if body.get("ignored"):
                            print(f"[skip] n8n ignored it: {body['ignored']}", flush=True)
                        else:
                            what = body.get("summary") or payload["kind"]
                            print(f"[sent] {payload['camera']}: {what}", flush=True)
                        break
                    if r.status_code in (401, 404):  # config problem, retrying won't help
                        print(f"[error] {r.status_code}: {r.text.strip()}", flush=True)
                        break
                    print(f"[warn] HTTP {r.status_code} (attempt {attempt}): {r.text[:120]}", flush=True)
                except requests.RequestException as e:
                    print(f"[warn] network error (attempt {attempt}): {e}", flush=True)
                time.sleep(2 * attempt)


def main():
    args = parse_args()
    stop = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop.set())
    signal.signal(signal.SIGTERM, lambda *_: stop.set())

    face_id = FaceID(args.faces, args.models_dir, args.face_threshold) if args.faces else None

    sender = Sender(args.url, args.key, args.dry_run)
    sender.start()

    hog = None
    if args.people:
        hog = cv2.HOGDescriptor()
        hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())

    is_file = os.path.isfile(args.source)
    cap = open_source(args.source)
    bg = cv2.createBackgroundSubtractorMOG2(history=300, varThreshold=36, detectShadows=False)
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
    frames_seen, motion_run, last_alert = 0, 0, 0.0

    print(f"[start] camera='{args.camera}' source={args.source} "
          f"min_area={args.min_area:.1%} cooldown={args.cooldown}s people={args.people} "
          f"faces={'on' if face_id else 'off'}", flush=True)

    while not stop.is_set():
        ok, frame = cap.read()
        if not ok:
            if is_file:
                print("[end] video file finished", flush=True)
                break
            print("[warn] lost the camera, reconnecting in 5s…", flush=True)
            cap.release()
            stop.wait(5)
            cap = open_source(args.source)
            continue

        h, w = frame.shape[:2]
        small = cv2.resize(frame, (args.width, int(h * args.width / w)))
        blur = cv2.GaussianBlur(small, (5, 5), 0)
        mask = bg.apply(blur)
        frames_seen += 1
        if frames_seen <= args.warmup:
            continue

        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.dilate(mask, kernel, iterations=2)
        moving = cv2.countNonZero(mask) / float(mask.size)
        motion_run = motion_run + 1 if moving >= args.min_area else 0

        now = time.time()
        if motion_run >= args.confirm_frames and now - last_alert >= args.cooldown:
            kind = "motion"
            if hog is not None:
                rects, _ = hog.detectMultiScale(small, winStride=(8, 8), padding=(8, 8), scale=1.05)
                if len(rects) > 0:
                    kind = "person"

            name, send_frame = "Unknown", frame
            if face_id is not None:
                name, face_seen, send_frame = look_for_faces(face_id, cap, frame, args.face_tries)
                if face_seen:
                    kind = "person"

            payload = {
                "action": "ingest",
                "camera": args.camera,
                "kind": kind,
                "name": name,
                "ts": int(now * 1000),
            }
            if args.snapshots:
                img = make_snapshot(send_frame)
                if img:
                    payload["image"] = img
            if args.ai:
                frame_b64 = make_analysis_frame(send_frame)
                if frame_b64:
                    payload["analysisImage"] = frame_b64
            sender.send(payload)
            last_alert, motion_run = now, 0

        if args.show:
            cv2.imshow("WatchPost edge (q to quit)", small)
            if cv2.waitKey(1) & 0xFF == ord("q"):
                break

    cap.release()
    if args.show:
        cv2.destroyAllWindows()
    # let queued events flush
    t0 = time.time()
    while not sender.q.empty() and time.time() - t0 < 10:
        time.sleep(0.2)
    print("[stop] bye", flush=True)


if __name__ == "__main__":
    sys.exit(main())
