from random import seed
from time import sleep

from machine import ADC, Pin, reset
from otp.otp import rand_otp

SLEEP_TIME__S = 1
OTP_COUNT = 5

ADC_PIN_NUMBER = 34
ADC_PIN = ADC(Pin(ADC_PIN_NUMBER))

ADC_SAMPLE_RATE__Hz = 8 * (1000**2)
ADC_BITS_PER_SAMPLE = 2
ADC_SAMPLE_BITMASK = (1 << ADC_BITS_PER_SAMPLE) - 1

RND_DATA_REG_LEN = 32


def sample_adc() -> int:
    true_random = 0x0
    for _ in range(RND_DATA_REG_LEN // ADC_BITS_PER_SAMPLE):
        true_random <<= ADC_BITS_PER_SAMPLE

        adc_value = ADC_PIN.read()
        rnd_bits = adc_value & ADC_SAMPLE_BITMASK
        true_random |= rnd_bits

        sleep_time = 1 / ADC_SAMPLE_RATE__Hz
        sleep(sleep_time)

        print(f"[ATC]: {hex(adc_value)} -> {hex(rnd_bits)} = {hex(true_random)}")

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
