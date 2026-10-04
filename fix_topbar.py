import re

with open('custom/src/AeroTopBar.qml', 'r') as f:
    c = f.read()

# Delete AXON dot
c = re.sub(r'\s*AeroStatusDot\s*\{\s*visible:\s*!root\.veryCompact\s*label:\s*"AXON".*?\}\n', '\n', c, flags=re.DOTALL)
# Delete WFB dot
c = re.sub(r'\s*AeroStatusDot\s*\{\s*visible:\s*!root\.veryCompact\s*label:\s*"WFB".*?\}\n', '\n', c, flags=re.DOTALL)
# Delete armButton
c = re.sub(r'\s*Rectangle\s*\{\s*id:\s*armButton\s*Layout\.preferredWidth:\s*80.*?\n\s*\}\n', '\n', c, flags=re.DOTALL)

with open('custom/src/AeroTopBar.qml', 'w') as f:
    f.write(c)

