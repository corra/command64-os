#!/usr/bin/env python3
import sys
import subprocess
import argparse
import os

def main():
    parser = argparse.ArgumentParser(description="Wrapper to execute build commands and notify OBS theme overlay.")
    parser.add_argument("--theme-dir", required=True, help="Path to c64_theme directory")
    parser.add_argument("--target", required=True, help="Name of the target being built")
    parser.add_argument("--building", action="store_true", help="Send 'building' event before execution")
    parser.add_argument("--success", action="store_true", help="Send 'success' event on command success")
    parser.add_argument("--error", action="store_true", help="Send 'error' event on command failure")
    parser.add_argument("command", nargs="+", help="Command to execute")
    args = parser.parse_args()

    notify_script = os.path.join(args.theme_dir, "scripts", "notify_obs.py")
    
    # Gracefully fall back to executing command without notifications if theme script is missing
    if not os.path.exists(notify_script):
        sys.exit(subprocess.run(args.command).returncode)

    def notify(state, message):
        venv_python = os.path.join(args.theme_dir, ".venv", "bin", "python")
        python_exe = venv_python if os.path.exists(venv_python) else sys.executable
        cmd = [python_exe, notify_script, state, message, f"--program={args.target}"]
        try:
            subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass

    # Send build start notification if requested
    if args.building:
        notify("building", f"COMPILING {args.target.upper()}")

    # Run the wrapped command
    result = subprocess.run(args.command)

    # Send final status notification
    if result.returncode == 0:
        if args.success:
            notify("success", f"0 ERRORS / {args.target.upper()} READY")
    else:
        if args.error:
            notify("error", f"BUILD FAILED / EXIT {result.returncode}")

    sys.exit(result.returncode)

if __name__ == "__main__":
    main()
