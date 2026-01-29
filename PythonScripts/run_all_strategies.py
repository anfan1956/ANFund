# run_all_strategies.py
import subprocess
import time
import sys
import signal

configs = [1, 2, 3]  # XAUUSD, XAGUSD, BTCUSD

processes = []
for config_id in configs:
    cmd = [sys.executable, 'mtf_rsi_ema_strategy.py', '--config-id', str(config_id)]
    proc = subprocess.Popen(cmd)
    processes.append(proc)
    print(f"Started strategy with config ID: {config_id}")
    time.sleep(2)  # Задержка между запусками

print(f"\nStarted {len(processes)} strategies")
print("Press Ctrl+C to stop all")


# Signal handler for clean shutdown
def signal_handler(sig, frame):
    print("\nCtrl+C detected. Stopping all strategies...")
    for proc in processes:
        proc.terminate()
    for proc in processes:
        proc.wait(timeout=5)
    print("All strategies stopped.")
    sys.exit(0)


signal.signal(signal.SIGINT, signal_handler)

# Keep the main process alive and check if strategies are still running
try:
    while True:
        # Check if any process has died unexpectedly
        for i, proc in enumerate(processes):
            if proc.poll() is not None:  # Process has terminated
                print(f"Warning: Strategy with config ID {configs[i]} has stopped!")
                # Optionally restart it here

        time.sleep(1)  # Reduced CPU usage

except KeyboardInterrupt:
    signal_handler(signal.SIGINT, None)
except Exception as e:
    print(f"Error: {e}")
    signal_handler(signal.SIGINT, None)