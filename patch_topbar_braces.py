with open('custom/src/AeroTopBar.qml', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if line.strip() == "}":
        pass # I'll do this better
