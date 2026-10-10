# WatchPost: install guide (start to finish)

How it fits together:

```
Old Android phone (IP Webcam) --Wi-Fi--> PC running edge.py --internet--> n8n (webhook + AI)
                                                                              |
                                                       Flutter app polls n8n <-+  (speaks the alert)
```

You need: an old Android phone (the camera), a PC/laptop/Raspberry Pi on the **same Wi-Fi** that stays on (runs `edge.py`), an n8n account (cloud or self-hosted), an Anthropic API key (or n8n AI credits), and Flutter installed on your dev machine.

Do the steps **in order**. Each step ends with a check so you know it worked before moving on.

---

## Execution budget (read this, it decides cost)

n8n counts **every webhook call as one execution**, and WatchPost uses polling, so calls add up:

| Who calls n8n | Default | Executions |
|---|---|---|
| edge.py sync (people + cameras) | every 300 s | 288 / day |
| App while it is open | every 60 s | 60 / hour open |
| Each alert (motion event) | per event | 1 each (+1 AI call) |

n8n Cloud limits: free trial **1,000 total**, Starter about **2,500 / month** (about 83 / day). So on Cloud:
- Use `--sync-interval 1800` (30 min) or more, and `--dart-define=POLL_SECONDS=120` when building the app. Don't leave the app open all day. Pull down on the Alerts list to refresh by hand.
- Even then you have almost no room for alerts. **Cloud is a poor fit for this design.**

**Better: self-host n8n (free, no execution limit)** on the same PC that runs edge.py. Needs Docker Desktop, or Node.js 20+:
```bash
# Option 1: Docker
docker run -d --name n8n --restart unless-stopped -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n
# Option 2: Node.js (needs Node.js 20.19 to 24.x; check with: node -v)
npx n8n
```
(`npx n8n` keeps running in that terminal; close it and n8n stops. For repeat use: `npm install n8n -g`, then `n8n start`.)
Open `http://localhost:5678`, create the owner account (on Windows, allow n8n through the firewall for **Private networks** so your phone can reach it), import the workflow, **create your own Anthropic credential** (the Cloud "Gateway credits" one doesn't exist there), set the 3 values, and Publish. Then use your PC's LAN IP in place of the Cloud URL, e.g. `http://192.168.1.20:5678/webhook/watchpost`, for both edge.py (`WATCHPOST_URL`) and the app (`--dart-define=WATCHPOST_API=...`; plain http is already allowed by `setup_platforms.py`). With unlimited executions you can use `--sync-interval 60` and `--dart-define=POLL_SECONDS=15`.
Trade-off: the app then works **on your home Wi-Fi only**, unless you add a tunnel (Tailscale, or a Cloudflare named tunnel) to reach the PC from outside. The PC must stay on.

---

## Step 1: n8n (the backend)

1. n8n -> **Workflows -> Import from file** -> pick `n8n/watchpost-api.workflow.json`.
2. Open the **API** node. At the top of the code change these 3 lines:
   ```js
   const OWNER_EMAIL = 'you@example.com';       // login for the app
   const OWNER_PASSWORD = 'a-long-password';    // 6+ chars, not the sample one
   const INGEST_KEY = 'a-long-random-string';   // used by edge.py
   ```
   The workflow **refuses to work** until the password and key are changed (on purpose).
3. Open the **Describe** node -> pick your **Anthropic** credential (Credentials -> New -> Anthropic -> paste API key; on n8n Cloud you can use the built-in AI credits instead). If it fails later, alerts are still saved, just without the AI sentence. To skip AI completely set `USE_AI = false` in the API node.
4. Top-right: **Publish / Activate** the workflow. It must stay active; storage only persists when active.
5. Open the **Webhook** node and copy the **Production URL**:
   `https://YOUR-NAME.app.n8n.cloud/webhook/watchpost`
   (NOT the "Test URL", which has `webhook-test` in it.)

**Check:** in a terminal:
```bash
curl -X POST "YOUR_PRODUCTION_URL" -H "Content-Type: application/json" -d '{"action":"login","email":"you@example.com","password":"a-long-password"}'
```
You should get `{"token":"..."}`. `404` = workflow not active / wrong URL. `Setup not finished` = you didn't change the password/key. `Wrong email or password` = typo. (8 wrong logins locks it for 10 minutes.)

> Self-hosting n8n behind nginx/Caddy? Allow request bodies of at least **5 MB** (`client_max_body_size 5m;`), or adding people with photos will fail.

---

## Step 2: The camera phone (IP Webcam)

1. Install **IP Webcam** (Android) on the old phone, open it, scroll down, tap **Start server**.
2. Note the address on screen, e.g. `192.168.1.50:8080`. Phone and PC must be on the same Wi-Fi.
3. Keep the phone plugged into power and set the screen to stay on (or use the app's "Run in background"/"Prevent sleep"). Give the phone a fixed IP in your router (DHCP reservation), otherwise the address changes after a reboot and you must update it.

**Check:** open `http://192.168.1.50:8080/video` in the PC browser. You should see live video.

---

## Step 3: edge.py (the PC that watches the cameras)

Needs **Python 3.9+** (python.org; on Windows tick "Add Python to PATH").

```bash
cd edge
python -m venv .venv
# Windows:   .venv\Scripts\activate
# Linux/Mac: source .venv/bin/activate
pip install -r requirements.txt
```
(If `python` isn't found on Linux/Mac use `python3`.)

**Recommended: `--auto` mode.** You add cameras and type their IP in the app (Step 5). edge.py asks n8n for the list and watches every enabled camera by itself: no camera names or IPs on the command line, one edge.py for all cameras, and changes in the app apply within `--sync-interval` seconds (default 5 minutes, or restart edge.py to apply at once).

Set the two secrets, then start it:

- Windows PowerShell:
  ```powershell
  $env:WATCHPOST_URL = "https://YOUR-NAME.app.n8n.cloud/webhook/watchpost"
  $env:WATCHPOST_KEY = "your INGEST_KEY"
  python edge.py --auto --ai --faces faces
  ```
- Linux/Mac:
  ```bash
  export WATCHPOST_URL="https://YOUR-NAME.app.n8n.cloud/webhook/watchpost"
  export WATCHPOST_KEY="your INGEST_KEY"
  python edge.py --auto --ai --faces faces
  ```

Until you add a camera address in the app it prints `no cameras to watch yet`. That's normal.

Easier for daily use: copy `run_edge.example.bat` (Windows) or `run_edge.example.sh` (Linux/Mac) to `run_edge.bat` / `run_edge.sh`, fill in the 2 values, and run it. It restarts edge.py if it crashes. To start it when the PC boots, put a shortcut to `run_edge.bat` in `shell:startup` (Windows).

<details><summary>Old manual mode (one camera, no app control)</summary>

```bash
python edge.py --camera "Front door" --ip-webcam 192.168.1.50:8080 --ai --faces faces
```
`--camera` must match a camera name in the app. Test first with `--dry-run --show` (prints events instead of sending, preview window, `q` to quit).
</details>

Notes:
- First run with `--faces` downloads two small AI model files (~40 MB total) next to `edge.py`. If the download fails (firewall), download them by hand from https://github.com/opencv/opencv_zoo (`models/face_detection_yunet/face_detection_yunet_2023mar.onnx` and `models/face_recognition_sface/face_recognition_sface_2021dec.onnx`; use "Download raw file") and put both in `edge/`.
- Too many/few alerts? `--min-area 0.02` (less sensitive) / `0.005` (more), `--cooldown 30`. Each alert with `--ai` = one small AI call, so use the cooldown to control cost.
- Face matching: strangers get named -> `--face-threshold 0.45`; known people missed -> `--face-threshold 0.30`. Best in good light, face 1-3 m from the camera.
- `--sync-interval` (default 300 s) is how often edge.py asks n8n for new people **and** camera changes. **Each check is one n8n execution**, see "Execution budget" below. Restarting edge.py syncs immediately, so after changing something in the app you can just restart it.
- Camera passwords inside `rtsp://user:pass@...` addresses are hidden in edge.py's output, but they are stored in n8n, so use a camera-only account.

**Check:** the PC must be on the same Wi-Fi as the camera phone. After Step 5 you'll see `[start] camera='Front door' ...`, and when you wave at the camera `[sent] Front door: ...`.

---

## Step 4: The Flutter app

Install Flutter (https://docs.flutter.dev/get-started/install) and run `flutter doctor` until Android toolchain is green. Then, in the project folder (the one with `pubspec.yaml`):

```bash
flutter create --project-name watchpost --platforms=android,ios .
python tool/setup_platforms.py
flutter pub get
dart run flutter_launcher_icons
```
(On Windows use `python` or `py`.)

- **`setup_platforms.py` is required.** It adds the INTERNET permission (without it the release APK can't reach n8n), the text-to-speech setting (the app can't talk without it), plain-http access for the live view, names the app "WatchPost", and on iOS the photo/camera/local-network texts.
- **`dart run flutter_launcher_icons`** puts the WatchPost shield icon on the home screen (artwork in `assets/icon/`; `python tool/make_icon.py` redraws it, needs `pip install pillow`). Run it again after any icon change, then uninstall/reinstall the app to see the new icon.

Run on your phone (USB debugging on):
```bash
flutter run --dart-define=WATCHPOST_API=https://YOUR-NAME.app.n8n.cloud/webhook/watchpost
```
Sign in with `OWNER_EMAIL` / `OWNER_PASSWORD` from Step 1.

Build an installable APK to share/keep on the phone:
```bash
flutter build apk --release --dart-define=WATCHPOST_API=https://YOUR-NAME.app.n8n.cloud/webhook/watchpost
```
File: `build/app/outputs/flutter-apk/app-release.apk`. The URL is baked in at build time, so rebuild if it changes. Without `--dart-define` the app runs in local demo mode (fake alerts, no server).

Android release builds are signed with the debug key unless you set up a keystore. That's fine for personal use; you only need your own keystore for Play Store. Don't commit it.

**Check:** you can sign in and see the Alerts / People / Cameras tabs. (The "wave at the camera -> phone speaks" test comes after Step 5, once a camera address is set. Volume up; the speaker icon on Alerts toggles voice.)

---

## Step 5: Add your camera (IP address) in the app

1. App -> **Cameras** tab. Tap a camera (or **+** to add one) -> type the **Camera address**, exactly what IP Webcam shows: `192.168.1.50:8080` -> **Save**.
2. The app sends the address to n8n. Within `--sync-interval` seconds (default 5 min; restart edge.py to apply right now) edge.py prints `[start] camera='Front door' source=http://192.168.1.50:8080/video` and starts watching. Switching a camera off in the app stops it; switching it on starts it again.
3. The camera screen shows a **LIVE** picture (refreshed every second) while your phone is on the same Wi-Fi. Away from home it shows the last snapshot instead and says "Cannot reach the camera from here". Alerts and snapshots still arrive from anywhere.
4. **Test it:** wave at the camera. Within about a minute (the app's check interval) a banner appears in the app and the phone **speaks** the sentence.
5. The camera **name** is what alerts are filed under, so it can't be renamed. Remove and re-add if you need another name.

Other cameras (CCTV/ONVIF): put the full stream URL as the address, e.g. `rtsp://user:pass@192.168.1.20:554/stream1`. Alerts work; the in-app live picture only supports IP Webcam addresses.

> Want live view from outside the house too? The picture comes straight from the camera phone, so you'd need a private tunnel such as Tailscale on both phones. Not built in on purpose (streaming through n8n would eat your executions and data).

---

## Step 6: Add people (face recognition)

1. App -> **People** tab -> **+** -> name, relationship, 3-5 clear front-facing photos (different light/angle) -> Save.
2. Make sure `edge.py` is running with `--faces faces`. Within your `--sync-interval` (default 5 min; restart edge.py to apply at once) it prints `[sync] saved N photo(s)` then `[faces] enrolled: Ada (N photos)`, and the person flips to **Camera knows them**.
3. If it prints `no face found in ... - replace this photo`, delete the person and add better photos.

Alerts will then say things like "Your wife Ada is at the front door."

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| App: "Server not found (404)" | Workflow not Published, or you used the Test URL. Use the Production URL. |
| App: "Setup not finished..." | Change `OWNER_PASSWORD` + `INGEST_KEY` in the n8n API node. |
| App: "Cannot reach the server" | No internet, or the APK was built without INTERNET permission (run `setup_platforms.py`, rebuild). |
| App: "Too many wrong tries" | Wait 10 minutes. |
| edge.py: `[error] 401` | `WATCHPOST_KEY` doesn't match `INGEST_KEY`. |
| edge.py: `[error] 404 Unknown camera` | (manual mode) `--camera` name isn't a camera in the app. |
| edge.py: `no cameras to watch yet` / `has no address yet` | Open Cameras tab, tap the camera, enter its address, make sure its switch is on. |
| App: "Camera address ... looks wrong" | Use `192.168.1.50:8080` (no spaces) or a full `http://`/`rtsp://` URL. |
| Live view: "Cannot reach the camera" | Phone not on the camera's Wi-Fi, wrong IP/port, IP Webcam server stopped, or app built without `setup_platforms.py` (plain http blocked). |
| Icon is still the Flutter logo | Run `dart run flutter_launcher_icons`, then uninstall and reinstall the app. |
| edge.py: "lost the camera" | Phone asleep / IP changed / different Wi-Fi. |
| Alerts arrive but no AI sentence | Describe node has no valid credential or no credit. Alerts still work. |
| No voice | Phone volume, speaker icon on Alerts, and a TTS engine installed (Settings -> Accessibility -> Text-to-speech). |
| n8n says execution limit reached | See "Execution budget". Raise `--sync-interval` / `POLL_SECONDS`, or self-host n8n. |
| Voice/alerts stop when app is closed | Expected: the app polls only while open. Closed-app push needs Firebase Cloud Messaging. |
| Wrong name for strangers / misses family | Tune `--face-threshold` (see Step 3). |

## Good to know

- **Privacy:** photos of your family and camera frames pass through n8n and (with `--ai`) Anthropic. The workflow is set not to keep successful execution logs, so frames aren't stored in n8n's history. Keep `edge/faces/` and your `run_edge` file out of git (already in `.gitignore`).
- **Limits:** one owner account; 100 alerts kept, snapshots on the newest 30. The app re-downloads a snapshot only once, not every 15 s.
- Updating the workflow later: re-import the JSON, then set the Describe credential and the 3 values again. Saved alerts/people/cameras live in the workflow's storage, so a re-imported workflow starts empty. Deactivate the old one so two workflows don't share the same webhook path.
- This version added camera addresses to the backend, so if you already imported an older workflow you **must** re-import this one (and use `--auto` with the new edge.py).
