#!/usr/bin/env python3
import time
import os
import urllib.request
from pywnp import WNPRedux #

last_title = ""
last_state = ""

def logger(type, message): #
    pass 

# Start listening to the extension on port 8974
WNPRedux.start(8974, '1.0.0', logger) #

print("Python WNP Daemon started. Listening for Zen Browser media...")

while True:
    time.sleep(0.5)
    
    if not WNPRedux.is_started: #
        continue

    current_state = WNPRedux.media_info.state #
    
    # If music is stopped, hide the SketchyBar item
    if current_state == 'STOPPED': #
        if last_state != 'STOPPED':
            os.system('sketchybar --set media drawing=off')
            last_state = 'STOPPED'
            last_title = ""
        continue

    current_title = WNPRedux.media_info.title #
    
    # Only push updates to SketchyBar if the song or state actually changed!
    if current_title != last_title or current_state != last_state:
        last_title = current_title
        last_state = current_state
        
        artist = WNPRedux.media_info.artist #
        cover_url = WNPRedux.media_info.cover_url #
        
        if current_state == 'PLAYING':
            art_path = "/tmp/sketchybar_coverart.jpg"
            if cover_url:
                try:
                    # Download the new album cover
                    urllib.request.urlretrieve(cover_url, art_path)
                except Exception:
                    pass
            
            # Escape quotes to prevent bash errors
            title_trunc = current_title[:22].replace('"', '\\"')
            artist_trunc = artist[:18].replace('"', '\\"')
            
            # Push the update directly to SketchyBar
            os.system(f'sketchybar --set media drawing=on label="{title_trunc} - {artist_trunc}" background.image="{art_path}" background.image.scale=0.06')
        else:
            os.system('sketchybar --set media drawing=off')