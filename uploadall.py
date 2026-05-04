import subprocess

def run_command(command):
    try:
        result = subprocess.run(command, shell=True, check=True, text=True, capture_output=True)
        print(result.stdout)
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)

commands = [
    "git status",
    "git add .",
    'git commit -m "Update project files"',
    "git push origin main"
]

for cmd in commands:
    print(f"Running: {cmd}")
    run_command(cmd)