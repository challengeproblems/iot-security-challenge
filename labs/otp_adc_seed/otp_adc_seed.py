from random import seed
from time import sleep

from machine import ADC, Pin, reset
from otp.otp import rand_otp

SLEEP_TIME__S = 1
OTP_COUNT = 5

# TODO: Find values for the following variables
ADC_PIN_NUMBER = ...
ADC_PIN = ADC(Pin(ADC_PIN_NUMBER))

ADC_SAMPLE_RATE__Hz = ...
ADC_BITS_PER_SAMPLE = ...
ADC_SAMPLE_BITMASK = (1 << ADC_BITS_PER_SAMPLE) - 1

RND_DATA_REG_LEN = ...  # = x


def sample_adc() -> int:
    true_random = ...

    # TODO: sample adc and fill true_random

    return true_random


def seed_random() -> int:
    rnd_seed = sample_adc()
    print(f"[OTP_SEED] rnd_seed: {hex(rnd_seed)}")
    seed(rnd_seed)
    return rnd_seed


def main():
    seed_random()
    for _ in range(OTP_COUNT):
        otp = rand_otp()
        print(f"[OTP] {otp}")
        sleep(SLEEP_TIME__S)
    reset()
