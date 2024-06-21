import random

import network

SSID_FILE = "ssid.txt"
SSID_PREFIX = "DNS-Lab-"


def log(*args, **kwargs):
    print(f"[AP]", *args, **kwargs)


def start_ap():
    try:
        with open(SSID_FILE, "r") as fd:
            SSID = fd.read().strip()
    except:
        # SSID file not found: generate new
        SSID = SSID_PREFIX + "".join(
            random.choice("0123456789abcdefghijklmnopqrstuvxxyz") for _ in range(6)
        )

    with open(SSID_FILE, "w") as fd:
        fd.write(SSID)

    log(f"ssid: {SSID}")

    ap = network.WLAN(network.AP_IF)
    ap.active(True)
    ap.config(essid=SSID)

    while ap.active() == False:
        pass
    log(f"started: {ap.ifconfig()}")
