import esp
import gc

# Init
esp.osdebug(None)
gc.collect()

# Select Lab
LAB_SELECTOR = open("labselector.txt").read().lower().strip()
print(f"[MAIN]: Selecting Lab: '{LAB_SELECTOR}'")
exec(f"from {LAB_SELECTOR}.{LAB_SELECTOR} import main; main()", {} )
