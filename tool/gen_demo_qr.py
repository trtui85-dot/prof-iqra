import os, sys, json, urllib.request
import qrcode

root = r"C:\Users\dell\Desktop\prof-iqra"
env = {}
with open(os.path.join(root, ".env"), encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            k, v = line.split("=", 1)
            env[k.strip()] = v.strip()

url = env["SUPABASE_URL"].rstrip("/")
key = env["SUPABASE_ANON_KEY"]

req = urllib.request.Request(
    url + "/rest/v1/app_settings?select=value&key=eq.qr_secret",
    headers={"apikey": key, "Authorization": "Bearer " + key,
             "Accept": "application/json"},
)
with urllib.request.urlopen(req, timeout=30) as r:
    rows = json.loads(r.read().decode("utf-8"))

if not rows or not rows[0].get("value"):
    sys.exit("qr_secret introuvable")

payload = "IQRA1:" + rows[0]["value"].strip()

img = qrcode.make(payload, box_size=18, border=4)
img = img.convert("RGB")
out = os.path.join(os.path.expanduser("~"), "Desktop", "demo_qr_code.png")
img.save(out, "PNG", optimize=True)

size = os.path.getsize(out)
print("fichier : " + out)
print("format   : %dx%d px, %d octets" % (img.width, img.height, size))
print("payload  : IQRA1:******** (masqué)")
