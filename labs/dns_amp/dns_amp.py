from time import sleep

from .ap import start_ap
from .microDNSSrv import MicroDNSSrv

SLEEP_TIME__S = 60

DOMAINS_LIST = {
    "test1.com": "1.1.1.1",
    "test2.com": "2.2.2.2",
    "test3.com": "3.3.3.3",
    "test4.com": "3.3.3.3",
}


def main():
    start_ap()
    mds = MicroDNSSrv.Create(DOMAINS_LIST)
    if mds is not None:
        print("[DNS] MicroDNSSrv started.")
    else:
        print("[DNS] Failed starting MicroDNSSrv")
    while True:
        sleep(SLEEP_TIME__S)
