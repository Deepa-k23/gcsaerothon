with open("src/FlyView/FlyViewMap.qml", "r") as f:
    c = f.read()

import re
c = re.sub(r'// A prominent debug text.*?}\n\n', '', c, flags=re.DOTALL)
with open("src/FlyView/FlyViewMap.qml", "w") as f:
    f.write(c)
