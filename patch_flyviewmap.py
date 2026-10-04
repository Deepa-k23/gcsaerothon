with open("src/FlyView/FlyViewMap.qml", "r") as f:
    c = f.read()

import re
# Replace Item { id: _pipState } with proper PipState
replacement = """
    PipState {
        id:         _pipState
        pipView:    _root.pipView
        isDark:     _isFullWindowItemDark
    }
"""
c = re.sub(r'Item \{ id: _pipState \}', replacement, c)

with open("src/FlyView/FlyViewMap.qml", "w") as f:
    f.write(c)
