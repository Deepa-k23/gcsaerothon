import re

path = '/home/deepa/AeroTHON-GCS-V2/custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js'
with open(path, 'r') as f:
    content = f.read()

# Replace:
# const f=await XZ(Cesium,{googleApiKey:t,cesiumToken:n})
# with:
# const f=await XZ(Cesium,{googleApiKey:t,cesiumToken:(n||(Cesium.Ion&&Cesium.Ion.defaultAccessToken)||"")})

content = re.sub(r'const f=await XZ\(Cesium,\{googleApiKey:t,cesiumToken:n\}\)', r'const f=await XZ(Cesium,{googleApiKey:t,cesiumToken:(n||(Cesium.Ion&&Cesium.Ion.defaultAccessToken)||"")})', content)

with open(path, 'w') as f:
    f.write(content)
