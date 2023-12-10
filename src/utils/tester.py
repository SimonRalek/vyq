import os
import subprocess

def run_test(test_filepath):
    try:
        with open(test_filepath, "r") as file:
            # Read the input from the first line of the test file
            user_input = file.readline().strip()

            # Construct the command with user input
            command = f"zig build run <<< '{user_input}'"

            # Run the command and capture the output
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            actual_output, _ = process.communicate()

            # Read the expected output from the remaining lines of the test file
            expected_output = ''.join(file.readlines())

            # Compare the actual output with the expected output
            if actual_output.strip() == expected_output.strip():
                print(f"Test Passed: {test_filepath}")
            else:
                print(f"Test Failed: {test_filepath}")
                print(f"Expected Output:\n{expected_output}")
                print(f"Actual Output:\n{actual_output}")

    except Exception as e:
        print(f"Error executing command: {command}")
        print(f"Error message: {str(e)}")

def run_tests_in_directory(test_directory):
    for filename in os.listdir(test_directory):
        if filename.endswith(".test"):
            test_filepath = os.path.join(test_directory, filename)

            # Run the test
            run_test(test_filepath)

if __name__ == "__main__":
    test_directory = "../../tests/"

    run_tests_in_directory(test_directory)

