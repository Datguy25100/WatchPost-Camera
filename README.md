# WatchPost (Flutter + n8n + AI)

**Full step-by-step setup: see [INSTALL.md](INSTALL.md). Presenting it? See [DEMO.md](DEMO.md).**

```
Phone running "IP Webcam"  ->  edge.py (motion)  ->  n8n cloud webhook  ->  vision LLM writes a sentence
                                                          |
                                         stored in n8n workflow storage
                                                          |
                                     Flutter app polls, shows the alert and SPEAKS the sentence
```

## 1. IP Webcam (the camera)
1. Install **IP Webcam** (Android) on the old phone, open it, tap **Start server**.
2. Note the address shown, e.g. `192.168.1.50:8080` (phone and computer must be on the same Wi-Fi).
3. Check `http://192.168.1.50:8080/video` shows video in a browser.

## 2. n8n (web / cloud)
1. Workflows -> **Import from file** -> `n8n/watchpost-api.workflow.json`
2. Open the **Describe** node and pick an **Anthropic** credential (Credentials -> New -> Anthropic, paste your API key; on n8n Cloud you can use the built-in AI credits).
3. If the Describe node fails (no credit, bad key), the alert is still saved without the AI sentence.
4. Open the **API** node and change `OWNER_EMAIL`, `OWNER_PASSWORD`, `INGEST_KEY` at the top.
   (Set `USE_AI = false` to skip the LLM; events are then stored as plain "Person detected at ...".)
5. **Publish / Activate** the workflow (storage only persists when active).
6. Copy the Webhook node's **Production URL**: `https://YOUR-NAME.app.n8n.cloud/webhook/watchpost`

The model is `claude-haiku-4-5-20251001` (fast, cheap). Each alert = one small image call. Use `--cooldown` to control cost.
You can swap the **Describe** node for OpenAI/Gemini; keep the same JSON reply format (see `SYSTEM_PROMPT` in the API node).

## 3. Motion detector (edge.py)
**New: `--auto` mode.** `python edge.py --auto --ai --faces faces` reads the camera list (names + IP addresses typed in the app's Cameras tab) from n8n and watches every enabled camera. The manual `--camera/--ip-webcam` flags below still work.
 — run on a PC / Raspberry Pi on the same Wi-Fi
```bash
cd edge
pip install -r requirements.txt
export WATCHPOST_URL="https://YOUR-NAME.app.n8n.cloud/webhook/watchpost"
export WATCHPOST_KEY="<INGEST_KEY from the n8n API node>"
python edge.py --camera "Front door" --ip-webcam 192.168.1.50:8080 --ai
```
- `--camera` must match a camera name in the app (case-insensitive). One script per camera.
- `--ai` sends a 640px frame for the LLM and a small thumbnail for the app.
- `--people` tags motion as "person" with a basic detector; with `--ai` the LLM decides the type anyway.
- Tuning: `--min-area 0.02` (less sensitive) / `0.005` (more), `--cooldown 30`, `--dry-run`, `--show`.
- The LLM can answer "nothing" (shadows, lighting) and n8n then drops the alert.
- **Face recognition (optional):** add `--faces faces` and put photos in `edge/faces/<Name>/1.jpg, 2.jpg, 3.jpg` (3-5 clear, front-facing photos per person, different light/angle). The folder name is what the app speaks. The two models (`face_detection_yunet_2023mar.onnx`, `face_recognition_sface_2021dec.onnx`) download automatically on first run, or place them next to `edge.py`.
  - Startup prints `[faces] enrolled: Mum (3 photos)`. On motion it prints `[faces] saw 1 face(s): Mum`. If a photo says "no face found", replace it.
  - Strangers get named? `--face-threshold 0.45`. Known people missed? `--face-threshold 0.30`.
  - Best results: good light, face 1-3 m from the camera. Night/far away often shows "Unknown".
  - Known people produce "Mum is at the front door."; strangers still get the normal AI description. (The n8n Save and API nodes in this workflow already include the changes for this.)
- Without `--faces`, names stay "Unknown" unless a name is written in the picture. The LLM is told not to identify people by face.

## 4. Flutter app
```bash
flutter create --project-name watchpost --platforms=android,ios .
python tool/setup_platforms.py     # adds INTERNET + text-to-speech (+ iOS photo texts)
flutter pub get
flutter run --dart-define=WATCHPOST_API=https://YOUR-NAME.app.n8n.cloud/webhook/watchpost
```
- The app checks n8n every 60 s (`--dart-define=POLL_SECONDS=...`; pull down on Alerts to refresh now). On a new alert it shows a banner and **reads the sentence aloud**. The speaker icon on the Alerts screen turns voice on/off.
- Without `--dart-define` the app runs in local demo mode (simulated alerts, voice still works).

## 5. People and AI tags (new)
- **People tab** in the app: tap **+**, enter a name, pick a relationship (wife, husband, mum...), add 1-5 clear photos (the app shrinks them to about 150 KB each) and save. The photos go to n8n.
- **edge.py** checks n8n every 60 s (`--sync-interval`, 0 = off) when you use `--faces faces`. It downloads new photos into `faces/<folder>/`, deletes removed people, confirms to n8n, and reloads the faces by itself. No restart needed. The person shows "Camera knows them" in the app once this has happened.
- Alerts now show AI **tags** (e.g. `#person #shopping bags`) and, for saved people, the name and relationship ("Ada · wife").
- iOS photo-picker texts are added by `tool/setup_platforms.py`.
- Set `OWNER_PASSWORD` and `INGEST_KEY` only in the n8n **API** node. The Save node no longer has its own copy.
- `n8n/watchpost-api.workflow.json` is the current workflow (people, tags and AI). Re-import it after pulling updates, then set the Describe credential and the three values in the API node again.

## Limits
- n8n counts every webhook call as an execution: the app polls every 15 s while it is open (it pauses in the background) and `edge.py` checks for new people every `--sync-interval` seconds. On a small n8n Cloud plan raise `--sync-interval` (e.g. 300) or self-host n8n.
- Voice and alerts work while the app is open (polling). Speaking/notifying when the app is closed needs Firebase Cloud Messaging.
- Single owner account; credentials live in the n8n Code node. Alerts capped at 100; snapshots kept on the newest 30.
