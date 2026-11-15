"""CF-FV1 V1.00L25 fan policy, validated initially by a temporary trial."""
import math
import os
from pathlib import Path
import signal
import socket
import sys
import time

EC = r"\_SB.PC00.LPCB.EC0"
CALL = Path("/proc/acpi/call")
THERMAL = Path("/sys/class/thermal")
EXCLUDED_SENSOR = "SEN6"
REQUIRED_SENSOR = "x86_pkg_temp"
SENSOR_PREFIXES = ("SEN", "TCPU", "acpitz", "x86_pkg")
FAN_CHANNELS = {"TFN1", "TFN2"}
FIRMWARE_COMMAND = "SEFM 0x00"
MANUAL_COMMAND = "SEFM 0x01"
MODE_QUERY = "CEFM"
MANUAL_RESUME_C = 60
FIRMWARE_CUTOFF_C = 65
POLL_SECONDS = 2
# ACPI control levels, not measured percentages of maximum RPM.
CURVE = [(float("-inf"), 10), (40, 15), (45, 20), (50, 25), (55, 35), (60, 50)]


def acpi(method):
    CALL.write_text(f"{EC}.{method}\n")
    result = CALL.read_bytes().rstrip(b"\0").decode()
    if not result or result == "not called" or result.startswith("Error"):
        raise RuntimeError(f"ACPI {method}: {result}")
    return int(result, 0)


def notify(message):
    address = os.environ.get("NOTIFY_SOCKET")
    if address:
        if address.startswith("@"):
            address = "\0" + address[1:]
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as connection:
            connection.sendto(message.encode(), address)


def read_temperatures(sensors):
    values = {}
    for name, path in sensors.items():
        temperature = float(path.read_text()) / 1000
        if not math.isfinite(temperature) or not 0 <= temperature <= 125:
            raise RuntimeError(f"Invalid {name} reading: {temperature}")
        values[name] = temperature
    if not values:
        raise RuntimeError("No temperature readings")
    return values


def fan_temperature(values):
    return max(values.values())


def target_state(temperature):
    return next(state for lower, state in reversed(CURVE) if temperature >= lower)


def next_state(temperature, state, cool_since, now):
    requested = target_state(temperature)
    if requested > state:
        return requested, None
    index = next(i for i, (_, level) in enumerate(CURVE) if level == state)
    if index == 0 or temperature >= CURVE[index][0] - 3:
        return state, None
    if cool_since is None:
        return state, now
    if now - cool_since >= 20:
        return CURVE[index - 1][1], None
    return state, cool_since


def set_fans(paths, state):
    for path in paths:
        path.write_text(f"{state}\n")
    for path in paths:
        if int(path.read_text()) != state:
            raise RuntimeError(f"Fan request readback failed: {path}")
    print(f"Fan request: {state * 2}% on both channels", flush=True)


def restore(fans=()):
    acpi(FIRMWARE_COMMAND)
    for path, previous in fans:
        path.write_text(f"{previous}\n")
    if acpi(MODE_QUERY) != 0:
        raise RuntimeError("Firmware mode readback failed")
    print("Restored firmware fan mode (CEFM=0)", flush=True)


def control(sensors, fans):
    try:
        values = read_temperatures(sensors)
        if max(values.values()) >= MANUAL_RESUME_C:
            raise RuntimeError("Already warm; leaving firmware in control")
        paths = [path for path, _ in fans]
        state = target_state(fan_temperature(values))
        cool_since = None
        set_fans(paths, state)
        acpi(MANUAL_COMMAND)
        notify("READY=1")
        report_at = 0
        while True:
            values = read_temperatures(sensors)
            hottest = max(values.values())
            now = time.monotonic()
            if hottest >= FIRMWARE_CUTOFF_C:
                print(f"{FIRMWARE_CUTOFF_C}C cutoff reached; returning to firmware", flush=True)
                restore(fans)

                while hottest >= MANUAL_RESUME_C:
                    notify("WATCHDOG=1")
                    time.sleep(POLL_SECONDS)
                    values = read_temperatures(sensors)
                    hottest = max(values.values())

                state = target_state(fan_temperature(values))
                cool_since = None
                set_fans(paths, state)
                acpi(MANUAL_COMMAND)
                print(f"Below {MANUAL_RESUME_C}C; resumed manual fan control", flush=True)
                continue
            requested, cool_since = next_state(fan_temperature(values), state, cool_since, now)
            if requested != state:
                set_fans(paths, requested)
                state = requested
            if now >= report_at:
                print(f"request={state * 2}% " + " ".join(
                    f"{name}={value:.1f}C" for name, value in sorted(values.items())
                ), flush=True)
                report_at = now + 30
            notify("WATCHDOG=1")
            time.sleep(POLL_SECONDS)
    finally:
        restore(fans)


def discover():
    sensors = {}
    for directory in THERMAL.glob("thermal_zone*"):
        name = (directory / "type").read_text().strip()
        if name != EXCLUDED_SENSOR and name.startswith(SENSOR_PREFIXES):
            sensors[name] = directory / "temp"
    if REQUIRED_SENSOR not in sensors:
        raise RuntimeError("Required CPU sensor unavailable")
    fans = {}
    for directory in THERMAL.glob("cooling_device*"):
        name = (directory / "type").read_text().strip()
        if name in FAN_CHANNELS:
            if int((directory / "max_state").read_text()) != 50:
                raise RuntimeError(f"Unexpected fan scale: {name}")
            path = directory / "cur_state"
            fans[name] = (path, int(path.read_text()))
    if set(fans) != FAN_CHANNELS:
        raise RuntimeError("Both fan channels required")
    return sensors, list(fans.values())


def interrupted(signum, frame):
    raise KeyboardInterrupt


def main():
    if Path("/sys/class/dmi/id/product_name").read_text().strip() != "CFFV1-1":
        raise RuntimeError("Fan policy only supports CFFV1-1")
    if Path("/sys/class/dmi/id/bios_version").read_text().strip() != "V1.00L25":
        raise RuntimeError("BIOS changed; inspect fan methods before enabling")
    if sys.argv[1:] == ["--restore"]:
        restore()
        return
    if sys.argv[1:]:
        raise RuntimeError("Only --restore is supported")
    signal.signal(signal.SIGINT, interrupted)
    signal.signal(signal.SIGTERM, interrupted)
    # Allow boot-time thermal devices to appear before taking control.
    deadline = time.monotonic() + 20
    while True:
        try:
            sensors, fans = discover()
            break
        except (OSError, RuntimeError):
            if time.monotonic() >= deadline:
                raise
            time.sleep(1)
    if acpi(MODE_QUERY) != 0:
        raise RuntimeError("EC already in non-default fan mode")
    control(sensors, fans)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
