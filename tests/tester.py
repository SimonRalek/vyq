import os
import subprocess
import tempfile
from colorama import init, Fore, Style

init(autoreset=True)

def build_project():
    try:
        build_command = "zig build"
        subprocess.run(build_command, shell=True, check=True)
        print(f"Project built {Fore.GREEN}successfully.{Style.RESET_ALL}\n")
    except Exception as e:
        print(f"{Fore.RED}Error building project:{Style.RESET_ALL} {str(e)}")
        exit(1)

def run_test(test_filepath):
    try:
        with open(test_filepath, "r") as file:
            user_input = file.readline().strip()

            with tempfile.NamedTemporaryFile(mode="w", delete=False) as temp_input_file:
                temp_input_file.write(user_input)

            command = f"./vyq {temp_input_file.name}"

            process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, text=True)
            actual_output = process.stdout

            expected_output = ''.join(file.readlines())

            if actual_output.strip() == expected_output.strip():
                print(f"{Fore.GREEN}Test Passed:{Style.RESET_ALL} {test_filepath}")
            else:
                print(f"{Fore.RED}Test Failed:{Style.RESET_ALL} {test_filepath}")
                print(f"Expected Output:\n{expected_output}")
                print(f"Actual Output:\n{actual_output}")
                return 1

    except Exception as e:
        print(f"{Fore.RED}Error executing command:{Style.RESET_ALL} {command}")
        print(f"{Fore.RED}Error message:{Style.RESET_ALL} {str(e)}")
        os.remove(temp_input_file.name)
        return 1
    finally:
        os.remove(temp_input_file.name)

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

