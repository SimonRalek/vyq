import os
import subprocess
import tempfile
from colorama import init, Fore, Style

# Initialize colorama
init(autoreset=True)

def build_project():
    try:
        # Build the project
        build_command = "zig build"
        subprocess.run(build_command, shell=True, check=True)
        print(f"Project built {Fore.GREEN}successfully.{Style.RESET_ALL}\n")
    except Exception as e:
        print(f"{Fore.RED}Error building project:{Style.RESET_ALL} {str(e)}")
        exit(1)

def run_test(test_filepath):
    try:
        with open(test_filepath, "r") as file:
            # Read the input from the first line of the test file
            user_input = file.readline().strip()

            # Create a temporary file to store the input
            with tempfile.NamedTemporaryFile(mode="w", delete=False) as temp_input_file:
                temp_input_file.write(user_input)

            # Construct the command with input redirection
            command = f"./vyq {temp_input_file.name}"

            # Run the command and capture the output
            process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, text=True)
            actual_output = process.stdout

            # Read the expected output from the remaining lines of the test file
            expected_output = ''.join(file.readlines())

            # Compare the actual output with the expected output
            if actual_output.strip() == expected_output.strip():
                print(f"{Fore.GREEN}Test Passed:{Style.RESET_ALL} {test_filepath}")
            else:
                print(f"{Fore.RED}Test Failed:{Style.RESET_ALL} {test_filepath}")
                print(f"Expected Output:\n{expected_output}")
                print(f"Actual Output:\n{actual_output}")

    except Exception as e:
        print(f"{Fore.RED}Error executing command:{Style.RESET_ALL} {command}")
        print(f"{Fore.RED}Error message:{Style.RESET_ALL} {str(e)}")
    finally:
        # Remove the temporary input file
        os.remove(temp_input_file.name)

def run_tests_in_directory(test_directory):
    for filename in os.listdir(test_directory):
        if filename.endswith(".test"):
            test_filepath = os.path.join(test_directory, filename)

            # Run the test
            run_test(test_filepath)

if __name__ == "__main__":
    # Specify the directory containing test files
    test_directory = "./tests"

    # Build the project once
    # build_project()

    # Run tests in the specified directory
    run_tests_in_directory(test_directory)

