# WatchPost: MVP demo guide

**One-line pitch:** an old phone becomes a security camera that *talks*. It tells you who is at the door, in plain English, and your family is recognised by name.

**What the MVP proves:** (1) motion detection on cheap hardware, (2) an AI that describes the scene in a kind sentence, (3) face recognition for saved family members, (4) a mobile app that shows alerts and speaks them aloud.

---

## 1. Run the backend on your own PC (recommended for the demo)

n8n Cloud's trial has only 1,000 executions, and WatchPost polls. Running n8n on your laptop is free and unlimited.

**Requirements:** Node.js **20.19 to 24.x** (check with `node -v`; install from nodejs.org, LTS 22 is a good pick).

```powershell
npx n8n
```
Open `http://localhost:5678`, create the owner account, then:
1. **Import** `n8n/watchpost-api.workflow.json`.
2. API node: set `OWNER_EMAIL`, `OWNER_PASSWORD`, `INGEST_KEY`.
3. Describe node: create an **Anthropic credential with your own API key** (the Cloud "Gateway credits" one doesn't exist locally). No API key? Set `USE_AI = false` in the API node: everything still works, alerts just say "Person detected at ..." instead of a description. The Demo-tools alerts never need AI.
4. **Publish** the workflow.
5. Find your PC's Wi-Fi address with `ipconfig` (IPv4, e.g. `192.168.1.20`). Your URL is `http://192.168.1.20:5678/webhook/watchpost` (use the IP, **not** `localhost`, so the phone can reach it).
6. Windows asks to allow n8n through the firewall: tick **Private networks**. If the phone can't connect later, this is the usual reason.
7. Test:
   ```powershell
   Invoke-RestMethod -Method Post -Uri "http://192.168.1.20:5678/webhook/watchpost" -ContentType "application/json" -Body '{"action":"login","email":"YOUR_EMAIL","password":"YOUR_PASSWORD"}'
   ```
   You should get a `token`.

The terminal running `npx n8n` must stay open. For repeat use: `npm install n8n -g`, then `n8n start` (no re-download). Your data is kept in `~/.n8n`.

## 2. Night before

- [ ] Backend running and tested (above), workflow **Published**.
- [ ] Build the demo app (checks every 10 s, so alerts show up fast):
  ```bash
  flutter build apk --release --dart-define=WATCHPOST_API=http://192.168.1.20:5678/webhook/watchpost --dart-define=POLL_SECONDS=10
  ```
- [ ] **Backup phone** with a second APK built *without* any `--dart-define`. It runs fully offline (fake alerts + voice + Demo tools). If everything else dies, you can still show the app.
- [ ] Camera phone: IP Webcam running, plugged in, screen on, IP noted.
- [ ] In the app: add the camera + its address (Cameras tab), add 1-2 people with good photos (People tab).
- [ ] Start edge.py for the demo. It syncs people/cameras **once** at startup and then stops polling:
  ```powershell
  cd edge
  $env:WATCHPOST_URL = "http://192.168.1.20:5678/webhook/watchpost"
  $env:WATCHPOST_KEY = "your INGEST_KEY"
  python edge.py --auto --ai --faces faces --sync-interval 0 --cooldown 10
  ```
  Watch for `[faces] enrolled: <name>` and `[start] camera=...`. Changed something in the app? Restart edge.py.
- [ ] Rehearse the whole script twice. Walk past the camera as the "family member" and as the "stranger".

**Venue Wi-Fi often blocks device-to-device traffic.** Don't rely on it. Use your own phone hotspot or a small router, and put the PC, camera phone and app phone all on it. Set it up and test it on site before you start.

## 3. 30 minutes before

- [ ] All devices on the same network (hotspot/router), phone volume up, Do Not Disturb off.
- [ ] Camera aimed at a doorway/chair, good light on the face, 1-3 m away.
- [ ] App: Alerts tab -> **Demo tools -> Clear all alerts**. Sign-in already done.
- [ ] Fire one **Known person** demo alert to confirm the voice works. Clear again.

## 4. Six-minute script

| Time | Do | Say |
|---|---|---|
| 0:00 | Slide / talk | The problem: security cameras record, they don't *tell* you anything useful. Cost of smart cameras. |
| 0:40 | Show phone-as-camera + diagram | Old phone -> PC runs motion + face recognition -> n8n + AI writes the sentence -> app speaks it. |
| 1:30 | **Live:** walk in front of the camera | Motion detected, AI describes what it sees (clothes, bags). App banner + **voice**. |
| 2:30 | **Live:** family member walks in | Recognised by name: "Your wife Ada is at the front door...". Show People tab (photos added from the app). |
| 3:30 | Tap an alert | Snapshot, AI tags, time, camera. |
| 4:00 | Cameras tab -> open camera | Add/edit the camera IP from the app; live view (same Wi-Fi). |
| 4:45 | **Demo tools** -> Vehicle at the gate | "To save time I'll trigger a simulated alert for a scenario I can't stage here." (Say it is simulated.) |
| 5:15 | Limits + next steps | Below. |

**Be upfront about demo alerts.** The Demo tools are for scenarios you can't stage or as a fallback. Tell the audience when you use one.

## 5. If something goes wrong

| Problem | Fast fix |
|---|---|
| No alert after walking by | Use Demo tools to continue; fix after. Check edge.py terminal for `[sent]`. |
| App can't reach the backend | Same network? Windows firewall (Private)? Switch to the backup phone (offline demo). |
| Face shows "Unknown" | Lower `--face-threshold 0.30` and restart, or face the camera in better light. Say "it needs good light". |
| Voice silent | Phone volume, speaker icon on Alerts, TTS engine installed. |
| edge.py crashed | Re-run the same command (it re-syncs at startup). |

## 6. Likely questions (honest answers)

- **Does it work when I'm away?** Alerts and voice work while the app is open and has internet *if the backend is reachable from outside* (cloud n8n, or a tunnel such as Tailscale). Push notifications with the app closed (Firebase) are the next step.
- **Privacy?** Faces are matched on your own PC (OpenCV). Camera frames only leave the house when the AI description is on. Photos you add go through your backend to your PC.
- **Accuracy?** Face recognition needs decent light and a front-facing view; night and distance reduce it. The AI never names people, it only uses names the face matcher gave it.
- **Cost?** Hardware: an old phone + a PC. Software: free (n8n self-hosted, OpenCV). AI: a fraction of a cent per described alert.
- **Why not a commercial camera?** Open, hackable, runs on hardware you already own, and the spoken description is the product.

## 7. MVP scope

| Works now | Not yet (roadmap) |
|---|---|
| Motion detection, multi-camera | Push notifications when the app is closed |
| AI scene description + tags | Live view away from home |
| Face recognition, add people from the app | Multiple users / sharing |
| Alerts, voice, history, live view on home Wi-Fi | Video clips (snapshots only) |
| Camera IPs managed from the app | Hosted backend with real accounts |
