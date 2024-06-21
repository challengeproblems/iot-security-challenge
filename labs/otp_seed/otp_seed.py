from time import sleep

from machine import reset
from otp.otp import seed_random

SLEEP_TIME__S = 1


def main():
    rnd_seed = seed_random()
    print(f"[OTP_SEED] rnd_seed: {hex(rnd_seed)}")
    sleep(SLEEP_TIME__S)
    reset()
