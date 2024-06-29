import _thread
import os
import socket
import struct

OTA_PORT = 880
ADDR = socket.getaddrinfo("0.0.0.0", OTA_PORT)[0][-1]
SOCK_WRITE_SIZE = 100
SOCK_TIMEOUT = 3
FIRMWARE_FILE = f"ota_firmware.py"
FIRMWARE_META_FILE = f"ota_firmware.json"


def log(*args, **kwargs):
    print(f"[FW]", *args, **kwargs)


def _send_file(cl, f_name):
    with open(f_name, "rb") as fd:
        while True:
            data = fd.read(SOCK_WRITE_SIZE)
            if not data:
                break
            sent_data = cl.write(data)
            print(".", end="")
    print("")


def _send_fw(cl):
    # sending firmware meta
    fw_meta_len = os.stat(FIRMWARE_META_FILE)[6]
    log(f"sending firmware meta len: {fw_meta_len}")
    cl.write(struct.pack("<L", fw_meta_len))

    # sending firmware meta
    log(f"sending firmware meta: ", end="")
    _send_file(cl, FIRMWARE_META_FILE)

    # send firmware
    log(f"sending firmware: ", end="")
    _send_file(cl, FIRMWARE_FILE)


def _accept_connection(sock):
    cl, addr = sock.accept()
    cl.settimeout(SOCK_TIMEOUT)

    log(f"client connected from: {addr}")

    _send_fw(cl)

    log(f"closing socket")
    cl.close()


def _bind_socket():
    sock = socket.socket()
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(ADDR)
    sock.listen(10)
    return sock


def _serve_fw_thread():
    log(f"binding socket")
    sock = None
    while sock is None:
        try:
            sock = _bind_socket()
        except Exception as ex:
            log(f"failed: {type(ex)} {ex}")

    log(f"accepting connection")
    while True:
        try:
            _accept_connection(sock)
        except Exception as ex:
            log(f"failed: {type(ex)} {ex}")


def serve_fw():
    log(f"start serving firmware")
    _thread.start_new_thread(_serve_fw_thread, ())
