import os
import subprocess
import tempfile
from colorama import init, Fore, Style

init(autoreset=True)
import sys
if sys.platform == "win32":
    sys.stdout.reconfigure(encoding='utf-8')

def build_project():
    try:
        build_command = "zig build"
        subprocess.run(build_command, shell=True, check=True)
        print(f"Project built {Fore.GREEN}successfully.{Style.RESET_ALL}\n")
    except Exception as e:
        print(f"{Fore.RED}Error building project: {Style.RESET_ALL} {str(e)}")
        exit(1)

def run_test(test_filepath):
    temp_path = None
    command = None
    try:
        with open(test_filepath, "r", encoding="utf-8") as file:
            content = file.read()
            if "---" in content:
                parts = content.split("---")
                user_input = parts[0].strip()
                expected_output = parts[1].lstrip() # Keep newlines in expected output, but trim leading newline after ---
            else:
                # Legacy support: line 1 is code, rest is output
                lines = content.splitlines(keepends=True)
                if lines:
                    user_input = lines[0].strip()
                    expected_output = "".join(lines[1:])
                else:
                    user_input = ""
                    expected_output = ""

        with tempfile.NamedTemporaryFile(mode="w", delete=False, encoding="utf-8") as temp_input_file:
            temp_input_file.write(user_input)
            temp_path = temp_input_file.name

        if os.environ.get("DEBUG_TESTS"):
            exe_name = "vyq.exe" if os.name == "nt" else "vyq"
            print(f"CWD: {os.getcwd()}")
            print(f"Looking for executable: {exe_name}")
        else:
            exe_name = "vyq.exe" if os.name == "nt" else "vyq"

        search_paths = [
            os.path.join(".", exe_name),
            os.path.join(".", "zig-out", "bin", exe_name),
        ]

        exe_path = None
        for path in search_paths:
            if os.path.exists(path):
                exe_path = path
                break
        
        if not exe_path:
             # Fallback to just name if not found in specific paths (search in PATH)
             exe_path = exe_name
             if os.environ.get("DEBUG_TESTS"):
                 print(f"Executable not found in specific paths, trying PATH: {exe_name}")

        if os.environ.get("DEBUG_TESTS") and exe_path:
             print(f"Using executable: {exe_path}")

        command = f'"{exe_path}" --bezbarev "{temp_path}"'

        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, text=True, encoding='utf-8', errors='replace')
        actual_output = process.stdout
        if temp_path:
            actual_output = actual_output.replace(temp_path, "<FILE>")

        if actual_output.strip() == expected_output.strip():
            print(f"{Fore.GREEN}Test Passed:{Style.RESET_ALL} {test_filepath}")
            return 0
        else:
            print(f"{Fore.RED}Test Failed:{Style.RESET_ALL} {test_filepath}")
            print(f"Expected Output:\n{expected_output}")
            print(f"Actual Output:\n{actual_output}")
            print(f"Exit Code: {process.returncode}")
            if process.stderr:
                print(f"Stderr:\n{process.stderr}")
            return 1

    except Exception as e:
        if command:
            print(f"{Fore.RED}Error executing command:{Style.RESET_ALL} {command}")
        else:
            print(f"{Fore.RED}Error processing test:{Style.RESET_ALL} {test_filepath}")
            
        print(f"{Fore.RED}Error message:{Style.RESET_ALL} {str(e)}")
        return 1
    finally:
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)

    return 0

def run_tests_in_directory(test_directory):
    for filename in os.listdir(test_directory):
        if filename.endswith(".test"):
            test_filepath = os.path.join(test_directory, filename)

            exit_code = run_test(test_filepath)

            if exit_code != 0:
                exit(exit_code)

if __name__ == "__main__":

    test_directory = "./tests"

    if (os.getenv("SKIP_BUILD", "0") == "0"):
        build_project()

    run_tests_in_directory(test_directory)

