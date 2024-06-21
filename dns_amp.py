#! /usr/bin/env python3

import sys

from scapy.all import DNS, DNSQR, IP, UDP, send

DNS_SERVER = "192.168.4.1"
DNS_QUERY = "test1.com"

if len(sys.argv) < 2:
    print(f"[!] Missing TARGET")
    print(f"usage:")
    print(f"    {sys.argv[0]} TARGET")
    sys.exit(1)

dns_target = sys.argv[1]
print(f"Targeting: {dns_target}")

while True:
    send(
        # TODO: build DNS packet here using scapy
        # Hint: Check imports of this file
    )
