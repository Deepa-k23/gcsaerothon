path = '/home/deepa/AeroTHON-GCS-V2/custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js'
with open(path, 'r') as f:
    content = f.read()

# I want to replace `viewer.trackedEntity=entity}}}),e||(n.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(t.longitude,t.latitude,i+1e3)}),e=!0)}}const vce=`
# with `viewer.trackedEntity=entity}}}const vce=`
old = "viewer.trackedEntity=entity}}}),e||(n.camera.flyTo({destination:Cesium.Cartesian3.fromDegrees(t.longitude,t.latitude,i+1e3)}),e=!0)}}const vce="
new = "viewer.trackedEntity=entity}}}const vce="
content = content.replace(old, new)

with open(path, 'w') as f:
    f.write(content)
