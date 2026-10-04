import re

path = '/home/deepa/AeroTHON-GCS-V2/custom/src/gods-eye-view-dist/assets/index-CSHkOiP6.js'
with open(path, 'r') as f:
    content = f.read()

replacement = '''
function Cce() {
    let hasFollowed = false;
    let manualPan = false;

    window.updateAeroTHONTelemetry = function(t) {
        if (!window.__godsEyeView || !window.__godsEyeView.viewer) return;
        const viewer = window.__godsEyeView.viewer;

        // Disconnected or invalid
        if (!t) {
            let entity = viewer.entities.getById("aerothon-vehicle");
            if (entity) {
                viewer.entities.remove(entity);
            }
            hasFollowed = false;
            return;
        }

        if (typeof t.latitude != "number" || typeof t.longitude != "number" || isNaN(t.latitude) || isNaN(t.longitude)) return;
        
        const alt = (typeof t.altitude == "number" && !isNaN(t.altitude)) ? t.altitude : 0;
        const hdg = (typeof t.heading == "number" && !isNaN(t.heading)) ? t.heading : 0;
        
        const pos = Cesium.Cartesian3.fromDegrees(t.longitude, t.latitude, alt);
        const headingRad = Cesium.Math.toRadians(hdg);
        
        // Use an Orientation property based on heading. We'll use a billboard with rotation, 
        // or a model. Billboard rotation is easiest for an SVG arrow.
        // Wait, for Billboard in Cesium, rotation is clockwise from up.
        
        let entity = viewer.entities.getById("aerothon-vehicle");
        if (!entity) {
            entity = viewer.entities.add({
                id: "aerothon-vehicle",
                position: pos,
                billboard: {
                    image: "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iIzAwZmZmZiIgZD0iTTEyIDJMNCAyMmw4LTggOCA4TDEyIDJ6Ii8+PC9zdmc+",
                    scale: 2,
                    color: Cesium.Color.CYAN,
                    rotation: headingRad,
                    alignedAxis: Cesium.Cartesian3.UNIT_Z,
                    heightReference: Cesium.HeightReference.RELATIVE_TO_GROUND
                }
            });
            
            // Add listener to detect user pan (cancels follow)
            if (!viewer.__aeroPanListenerAdded) {
                viewer.__aeroPanListenerAdded = true;
                viewer.scene.camera.moveStart.addEventListener(() => {
                    manualPan = true;
                    viewer.trackedEntity = undefined;
                });
            }
        } else {
            entity.position = pos;
            entity.billboard.rotation = headingRad;
        }

        // Auto-follow
        if (!hasFollowed) {
            hasFollowed = true;
            manualPan = false;
            viewer.trackedEntity = entity;
        }
    };
}
'''
# I need to be careful with minification. The existing function Cce() is quite compact.
# Let's just find `function Cce(){let e=!1;window.updateAeroTHONTelemetry=function(t){...}` and replace it.

match = re.search(r'function Cce\(\)\{let e=!1;window\.updateAeroTHONTelemetry=function\(t\)\{.*?\}\}', content)
if match:
    # Need to minify my replacement a bit to not break anything
    minified = 'function Cce(){let hasFollowed=!1,manualPan=!1;window.updateAeroTHONTelemetry=function(t){if(!window.__godsEyeView||!window.__godsEyeView.viewer)return;const viewer=window.__godsEyeView.viewer;if(!t){let e=viewer.entities.getById("aerothon-vehicle");e&&viewer.entities.remove(e),hasFollowed=!1;return}if(typeof t.latitude!="number"||typeof t.longitude!="number"||isNaN(t.latitude)||isNaN(t.longitude))return;const alt=typeof t.altitude=="number"&&!isNaN(t.altitude)?t.altitude:0,hdg=typeof t.heading=="number"&&!isNaN(t.heading)?t.heading:0,pos=Cesium.Cartesian3.fromDegrees(t.longitude,t.latitude,alt),headingRad=Cesium.Math.toRadians(hdg);let entity=viewer.entities.getById("aerothon-vehicle");if(!entity){entity=viewer.entities.add({id:"aerothon-vehicle",position:pos,billboard:{image:"data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0iIzAwZmZmZiIgZD0iTTEyIDJMNCAyMmw4LTggOCA4TDEyIDJ6Ii8+PC9zdmc+",scale:2,color:Cesium.Color.CYAN,rotation:headingRad,alignedAxis:Cesium.Cartesian3.UNIT_Z,heightReference:Cesium.HeightReference.RELATIVE_TO_GROUND}});if(!viewer.__aeroPanListenerAdded){viewer.__aeroPanListenerAdded=!0;viewer.scene.camera.moveStart.addEventListener(()=>{manualPan=!0;viewer.trackedEntity=void 0})}}else{entity.position=pos;entity.billboard.rotation=headingRad}if(!hasFollowed){hasFollowed=!0;manualPan=!1;viewer.trackedEntity=entity}}}'
    content = content[:match.start()] + minified + content[match.end():]
    with open(path, 'w') as f:
        f.write(content)
    print("Patched Cce")
else:
    print("Could not find Cce function")

