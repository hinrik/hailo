#!/bin/bash

# Run this in hailo's checked out directory

gource \
    --stop-at-end \
    --file-idle-time 60 \
    --elasticity 0.3 \
    --auto-skip-seconds 1 \
    --highlight-all-users \
    --user-image-dir \
    ~/gource-img \
    --user-scale 0.8 \
    --camera-mode track \
    --output-ppm-stream - | pv | ffmpeg -y -b 3000K -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 hailo-gource.mp4
