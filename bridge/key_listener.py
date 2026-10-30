import sys
import os
import time
import json
import ctypes

user32 = ctypes.windll.user32

# Collect all potential Cache directories
targets = set()
if len(sys.argv) > 1 and sys.argv[1]:
    targets.add(os.path.abspath(sys.argv[1]))

local_mod_cache = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "mod", "AI Assistant", "Cache"))
targets.add(local_mod_cache)

appdata = os.environ.get("APPDATA")
if appdata:
    sm_user = os.path.join(appdata, "Axolot Games", "Scrap Mechanic", "User")
    if os.path.isdir(sm_user):
        try:
            for entry in os.listdir(sm_user):
                if entry.startswith("User_"):
                    cand = os.path.join(sm_user, entry, "Mods", "AI Assistant", "Cache")
                    targets.add(os.path.abspath(cand))
        except Exception:
            pass

target_dirs = list(targets)
for d in target_dirs:
    try:
        os.makedirs(d, exist_ok=True)
    except Exception:
        pass

def is_scrap_mechanic_active():
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return False
    length = user32.GetWindowTextLengthW(hwnd)
    if length <= 0:
        return False
    buf = ctypes.create_unicode_buffer(length + 1)
    user32.GetWindowTextW(hwnd, buf, length + 1)
    title = buf.value.lower()
    return "scrap mechanic" in title

was_down = False

print(f"[key_listener] Listening for 'R' key when Scrap Mechanic is focused. Targets: {target_dirs}", flush=True)

while True:
    try:
        # VK_R = 0x52
        is_down = bool(user32.GetAsyncKeyState(0x52) & 0x8000)
        if is_down and not was_down:
            if is_scrap_mechanic_active():
                now = time.time()
                payload = json.dumps({"time": now, "key": "R"})
                for d in target_dirs:
                    try:
                        kfile = os.path.join(d, "ai_key_r.json")
                        tmp = kfile + ".tmp"
                        with open(tmp, "w", encoding="utf-8") as f:
                            f.write(payload)
                        os.replace(tmp, kfile)
                    except Exception:
                        pass
        was_down = is_down
        time.sleep(0.04)
    except Exception as e:
        time.sleep(0.1)
