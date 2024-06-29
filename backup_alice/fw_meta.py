import json
import os

DEFAULT_FIRMWARE_META = {"version": 0}
FIRMWARE_META_FILE = f"ota_firmware.json"


def log(*args, **kwargs):
    print(f"[FW_META]", *args, **kwargs)


def get_firmware_meta() -> dict:
    try:
        log(f"reading firmware from: {FIRMWARE_META_FILE}")
        with open(FIRMWARE_META_FILE, "r") as fd:
            firmware_meta = fd.read()
            return json.loads(firmware_meta)
    except (FileNotFoundError, json.decoder.JSONDecodeError) as ex:
        log(f"exception {type(ex)}: '{ex}'")
        return DEFAULT_FIRMWARE_META


def update_firmware_meta():
    firmware_meta = get_firmware_meta()

    # increment version
    firmware_meta["version"] += 1

    log(f"new firmware meta: {firmware_meta}")
    with open(FIRMWARE_META_FILE, "w") as fd:
        fd.write(json.dumps(firmware_meta))


if __name__ == "__main__":
    update_firmware_meta()
