from time import sleep

SLEEP_TIME__S = 1

i = 0
while True:
    print(f"[HELLO {i}] Hello world!")
    sleep(SLEEP_TIME__S)
    i += 1
