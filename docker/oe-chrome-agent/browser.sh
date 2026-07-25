#!/bin/bash -l
# Manpreet 23/07/2026
# $BROWSER target: hands a URL (e.g. the /login OAuth link) to the already-running
# Chrome via its ProcessSingleton, or cold-starts one if Chrome isn't up.
exec google-chrome-stable --no-sandbox --disable-dev-shm-usage "$@"
