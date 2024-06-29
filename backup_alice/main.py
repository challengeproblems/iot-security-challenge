import gc

import esp

# Init
esp.osdebug(None)
gc.collect()

# Start reset counter
import reset

reset.start_reset_timer()


# Start OTA Update
import ota

ota.start_ota()

# Start access point
import ap

ap.start_ap()

# Start firmware serve
import fw_serve

fw_serve.serve_fw()

# Start webserver
import webserver

webserver.start_server()
