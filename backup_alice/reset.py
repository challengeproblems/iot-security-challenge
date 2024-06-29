import _thread
import random
import time

import machine

SLEEP_TIME_MIN__S = 10 * 60
SLEEP_TIME_MAX__S = 120 * 60
SLEEP_TIME__S = random.randrange(SLEEP_TIME_MIN__S, SLEEP_TIME_MAX__S)


def log(*args, **kwargs):
    print(f"[RST]", *args, **kwargs)


def _reset_thread():
    time.sleep(SLEEP_TIME__S)
    log(f"reset")
    machine.reset()


def start_reset_timer():
    log(f"reset in {SLEEP_TIME__S} seconds")
    _thread.start_new_thread(_reset_thread, ())
