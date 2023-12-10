import os
import shutil
import subprocess

def build_and_rename(target):
    build_command = f'zig build-exe -O ReleaseFast src/main.zig -target {target}'
    subprocess.run(build_command, shell=True, check=True)


    if 'windows' in target:
        shutil.move('main.exe', 'vyq-windows.exe')
    elif 'macos' in target:
        shutil.move('main', f'vyq-macos_aarch64' if 'aarch64' in target else 'vyq-macos_x86_64')
    else:
        shutil.move('main', 'vyq-linux')

    for file in os.listdir('.'):
        if file.startswith('main.') or file.endswith('.o'):
            os.remove(file)

if __name__ == '__main__':
    targets = ['x86_64-linux', 'x86_64-windows', 'x86_64-macos', 'aarch64-macos']

    for target in targets:
        print(f'Building and processing for target: {target}')
        build_and_rename(target)

    print('Build and rename process completed.')

