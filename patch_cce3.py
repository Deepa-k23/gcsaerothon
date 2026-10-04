import re

path = '/home/deepa/AeroTHON-GCS-V2/custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js'
with open(path, 'r') as f:
    content = f.read()

# Replace:
# entity.position=pos;entity.billboard.rotation=-headingRad}
# with:
# entity.position=pos;entity.billboard.rotation=-headingRad;console.log("GodsEye Marker Updated",t.latitude,t.longitude,t.heading)}

content = content.replace('entity.position=pos;entity.billboard.rotation=-headingRad}', 'entity.position=pos;entity.billboard.rotation=-headingRad;console.log("GodsEye Marker Updated",t.latitude,t.longitude,t.heading)}')

with open(path, 'w') as f:
    f.write(content)
