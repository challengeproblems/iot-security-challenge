import hashlib
import json
import os
import random
import socket
import struct
import time
from binascii import hexlify, unhexlify

import machine
import network

import fw_meta
from fw_serve import FIRMWARE_FILE, FIRMWARE_META_FILE
from ufastrsa.rsa import RSA, genrsa
from webserver import read_file

OTA_RETRY = 0
MAX_OTA_RETRY = 3
SLEEP_TIME__S = 1
FETCH_SOCKET_TIMEOUT__S = 1.0

SSID_PREFIX = "IoT-Challenge-"
OTA_PORT = 880

SOCK_READ_SIZE = 100
FIRMWARE_META = fw_meta.get_firmware_meta()
NEW_FIRMWARE_FILE = f"new_{FIRMWARE_FILE}"
NEW_FIRMWARE_META_FILE = f"new_{FIRMWARE_META_FILE}"

PUBLIC_KEY = read_file("public_key.txt")
alg = RSA(2048, n=PUBLIC_KEY, e=65537)


def log(*args, **kwargs):
    print(f"[OTA {OTA_RETRY}/{MAX_OTA_RETRY}]", *args, **kwargs)


def _receive_file(sock, f_name, f_len=None):
    f_received = 0
    with open(f_name, "wb") as fd:
        while f_len is None or (f_received < f_len):

            to_read = SOCK_READ_SIZE
            if f_len is not None:
                to_read = min(SOCK_READ_SIZE, (f_len - f_received))

            f_part = sock.read(to_read)
            if not f_part:
                break

            fd.write(f_part)
            f_received += len(f_part)
            print(".", end="")
    print(f"")


def _fetch_fw(ip):
    sock_info = socket.getaddrinfo(ip, OTA_PORT, 0, socket.SOCK_STREAM)[0][-1]
    log(f"connecting to: {sock_info}")
    sock = socket.socket()
    sock.settimeout(FETCH_SOCKET_TIMEOUT__S)
    sock.connect(sock_info)

    log(f"fetching meta length")
    fw_meta_len = struct.unpack("<L", sock.read(4))[0]
    log(f"meta length: {fw_meta_len}")

    log(f"receiving meta: ", end="")
    _receive_file(sock, NEW_FIRMWARE_META_FILE, fw_meta_len)

    log(f"receiving firmware: ", end="")
    _receive_file(sock, NEW_FIRMWARE_FILE)

    log(f"closing socket")
    sock.close()


def _hash_sha256(string: str):
    hasher = hashlib.sha256()
    hasher.update(string)
    return hexlify(hasher.digest()).decode()


def _verify_fw(rsa_val, update_hash_contents):
    if alg:
        return alg.pkcs_verify(unhexlify(rsa_val)) == update_hash_contents
    return False


def _install_fw():
    with open(NEW_FIRMWARE_META_FILE, "r") as fd:
        new_firmware_meta = json.loads(fd.read())
    log(f"meta: {new_firmware_meta}")

    firmware_version = FIRMWARE_META["version"]
    new_firmware_version = new_firmware_meta["version"]
    new_firmware_signature = new_firmware_meta[
        "signature"
    ]  # Our RSA signature for verification to ota_firmware.json
    log(f"current: {firmware_version}, received: {new_firmware_version}")

    if firmware_version >= new_firmware_version:
        # no new version: do not update
        return

    hash_contents = _hash_sha256(read_file(NEW_FIRMWARE_FILE))

    log(f"Hash: {hash_contents}\nRSA Signature: {new_firmware_signature}")

    if not _verify_fw(new_firmware_signature, hash_contents):
        # firmware not legitimate: do not update
        return

    # Need to verify before this
    log(f"update: {firmware_version} -> {new_firmware_version}")
    import new_ota_firmware

    log(f"update completed")
    os.rename(NEW_FIRMWARE_META_FILE, FIRMWARE_META_FILE)
    os.rename(NEW_FIRMWARE_FILE, FIRMWARE_FILE)

    log(f"reset")
    machine.reset()


def _update_fom_station(sta_if, ssid):
    sta_if.connect(ssid)

    for _ in range(MAX_OTA_RETRY):
        if sta_if.isconnected():
            break
        log(f"waiting for connection")
        time.sleep(SLEEP_TIME__S)

    (ip, netmask, gateway, dns) = sta_if.ifconfig()
    log(f"connected: {sta_if.ifconfig()}")
    _fetch_fw(gateway)
    _install_fw()
    sta_if.disconnect()


def _do_update(sta_if):
    log(f"searching for OTA device")
    stations = sta_if.scan()

    station_ssids = []
    for ssid, bssid, channel, RSSI, security, hidden in stations:
        if ssid.startswith(SSID_PREFIX):
            station_ssids.append(ssid)

    if len(station_ssids) <= 0:
        log(f"no OTA devices found")
        return

    ssid = random.choice(station_ssids)
    log(f"connecting to network: {ssid}")
    _update_fom_station(sta_if, ssid)


def _reset_sta_if(sta_if):
    sta_if.active(False)
    while sta_if.active():
        pass

    sta_if.active(True)
    while not sta_if.active():
        pass

    sta_if.disconnect()
    while sta_if.isconnected():
        pass


def start_ota():
    global OTA_RETRY
    sta_if = network.WLAN(network.STA_IF)
    log(f"start OTA")
    for OTA_RETRY in range(MAX_OTA_RETRY):
        try:
            _reset_sta_if(sta_if)
            _do_update(sta_if)
        except Exception as ex:
            log(f"failed: {type(ex)} {ex}")
        finally:
            sta_if.active(False)
            while sta_if.active():
                pass

        time.sleep(SLEEP_TIME__S)
