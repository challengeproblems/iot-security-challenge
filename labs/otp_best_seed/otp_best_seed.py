from random import seed
from time import sleep

from machine import reset
from otp.otp import rand_otp

SLEEP_TIME__S = 1
OTP_COUNT = 5


def seed_random():
    # TODO: Find and use a good random seed here
    seed(...)


def main():
    seed_random()
    for _ in range(OTP_COUNT):
        otp = rand_otp()
        print(f"[OTP] {otp}")
    sleep(SLEEP_TIME__S)
    reset()
