"""Non-privileged checks: use temporary sysfs files, never the live EC."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "fan", Path(__file__).resolve().parents[1] / "modules/letsnote/fan.py"
)
fan = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fan)


class FanChecks(unittest.TestCase):
    def test_curve_and_fast_increase(self):
        for temperature, state in [(20, 10), (39.9, 10), (40, 15), (45, 20),
                                   (50, 25), (55, 35), (60, 50)]:
            self.assertEqual(fan.target_state(temperature), state)
        self.assertEqual(fan.next_state(61, 10, None, 0), (50, None))

    def test_cooling_delay_resets_when_temperature_rebounds(self):
        self.assertEqual(fan.next_state(36, 15, None, 0), (15, 0))
        self.assertEqual(fan.next_state(36, 15, 0, 19), (15, 0))
        self.assertEqual(fan.next_state(38, 15, 0, 20), (15, None))
        self.assertEqual(fan.next_state(36, 15, 21, 41), (10, None))
        self.assertEqual(fan.next_state(35, 50, 0, 20), (35, None))

    def test_missing_or_invalid_sensor_fails_instead_of_ignoring_it(self):
        with tempfile.TemporaryDirectory() as directory:
            p = Path(directory) / "temp"
            p.write_text("49000")
            self.assertEqual(fan.read_temperatures({"SEN6": p}), {"SEN6": 49})
            for value in ["nan", "-1000", "126000", "bad"]:
                p.write_text(value)
                with self.assertRaises((ValueError, RuntimeError)):
                    fan.read_temperatures({"SEN6": p})
            p.unlink()
            with self.assertRaises(OSError):
                fan.read_temperatures({"SEN6": p})

    def test_fan_requests_and_original_levels_restored(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [Path(directory) / name for name in ["TFN1", "TFN2"]]
            for p in paths:
                p.write_text("0")
            commands = []
            with patch.object(fan, "acpi", side_effect=lambda cmd: commands.append(cmd) or 0):
                fan.set_fans(paths, 10)
                self.assertEqual([p.read_text().strip() for p in paths], ["10", "10"])
                fan.restore(list(zip(paths, [0, 0])))
            self.assertEqual(commands, ["SEFM 0x00", "CEFM"])
            self.assertEqual([p.read_text().strip() for p in paths], ["0", "0"])

    def test_hot_or_failed_monitor_restores_firmware(self):
        for temperatures in [{"SEN6": 65}, OSError("sensor lost")]:
            commands = []
            with tempfile.TemporaryDirectory() as directory:
                paths = [Path(directory) / name for name in ["TFN1", "TFN2"]]
                for p in paths:
                    p.write_text("0")
                readings = [{"SEN6": 35}]
                if isinstance(temperatures, Exception):
                    readings.append(temperatures)
                else:
                    readings.append(temperatures)
                with patch.object(fan, "read_temperatures", side_effect=readings), \
                     patch.object(fan, "acpi", side_effect=lambda cmd: commands.append(cmd) or 0), \
                     patch.object(fan, "notify"):
                    if isinstance(temperatures, Exception):
                        with self.assertRaises(OSError):
                            fan.control({}, list(zip(paths, [0, 0])))
                    else:
                        fan.control({}, list(zip(paths, [0, 0])))
                self.assertEqual(commands, ["SEFM 0x01", "SEFM 0x00", "CEFM"])
                self.assertEqual([p.read_text().strip() for p in paths], ["0", "0"])


if __name__ == "__main__":
    unittest.main()
