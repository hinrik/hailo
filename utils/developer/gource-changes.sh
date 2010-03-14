#!/bin/bash

# Run this in hailo's checked out directory

gource --stop-at-end --output-ppm-stream - | ffmpeg -y -b 3000K -r 60 -f image2pipe -vcodec ppm -i - -vcodec libx264 gource.mp4
