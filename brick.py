import time

import src.urequests

ip = "http://192.168.4.1/"
auth = ("Basic", "JoePees")


def send_cmd(cmd):
    global auth
    global ip
    headers = {}
    data_encoded = f"calc={cmd}"
    urequests.post(ip, data=data_encoded, headers=headers, auth=auth)


brick_main = open("brick_main.txt").read()
reset = open("reset.txt").read()
send_cmd(brick_main)
time.sleep(2)
send_cmd(reset)
