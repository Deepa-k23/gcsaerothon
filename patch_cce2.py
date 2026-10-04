import re

path = '/home/deepa/AeroTHON-GCS-V2/custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js'
with open(path, 'r') as f:
    content = f.read()

# Replace rotation:headingRad with rotation:-headingRad
content = content.replace('rotation:headingRad', 'rotation:-headingRad')

with open(path, 'w') as f:
    f.write(content)
