import sys
with open('custom/CMakeLists.txt', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'file(COPY' in line or 'install(DIRECTORY' in line or 'Copy Gods Eye View dist' in line:
        continue
    new_lines.append(line)
    if 'set(QGC_RESOURCES' in line:
        new_lines.append('\n# Copy Gods Eye View dist to build directory at build time\n')
        new_lines.append('add_custom_target(CopyGodsEyeView ALL\n')
        new_lines.append('    COMMAND ${CMAKE_COMMAND} -E copy_directory\n')
        new_lines.append('    ${CMAKE_CURRENT_SOURCE_DIR}/src/gods-eye-view-dist\n')
        new_lines.append('    ${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/gods-eye-view-dist\n')
        new_lines.append(')\n')
        new_lines.append('install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/src/gods-eye-view-dist DESTINATION ${CMAKE_INSTALL_BINDIR})\n')

with open('custom/CMakeLists.txt', 'w') as f:
    f.writelines(new_lines)
