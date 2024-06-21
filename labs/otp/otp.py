from random import random, randrange, seed
from time import sleep, ticks_cpu

SLEEP_TIME__S = 3
KEYS = "1234567890"


def seed_random() -> int:
    rnd_seed = ticks_cpu()
    seed(rnd_seed)
    return rnd_seed


def rand_str(length=10) -> str:
    return "".join(KEYS[randrange(len(KEYS))] for _ in range(length))


def rand_otp() -> str:
    pw1 = rand_str(3)
    pw2 = rand_str(3)
    return f"{pw1} {pw2}"


def main():
    seed_random()
    while True:
        otp = rand_otp()
        print(f"[OTP] {otp}")
        sleep(SLEEP_TIME__S)
