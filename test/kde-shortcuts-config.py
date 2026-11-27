#!/usr/bin/env python3
"""Offline tests: simulate GVariant replies and live shortcut state."""
import contextlib
import importlib.util
import io
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "shortcuts", Path(__file__).resolve().parents[1] / "kde/shortcuts-config.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class FakeAccel:
    def __init__(self):
        self.state = {(component, action): [] for _, _, component, action in m.TARGETS}
        self.state[m.SPECTACLE_LAUNCH] = [m.seq(m.SCREENSHOT_KEY), m.seq(16777225)]
        self.state[("org.kde.krunner.desktop", "_launch")] = [m.seq(134217760), (1, 2, 0, 0)]
        self.state[("org.kde.spectacle.desktop", "RectangularRegionScreenShot")] = [m.seq(318767113)]
        self.state[("kwin", "Overview")] = [m.seq(268435543)]
        self.state[("other", "keep")] = [m.seq(123)]
        self.writes = []

    def call(self, method, *args):
        import ast
        if method == "allActionsForComponent":
            component = ast.literal_eval(args[0])[0]
            return ([[c, a, c, a] for c, a in self.state if c == component],)
        if method == "getGlobalShortcutsByKey":
            key = int(args[0])
            return ([(a, a, c, c, "default", "Default Context", [key], [])
                     for (c, a), keys in self.state.items() if m.seq(key) in keys],)
        action = tuple(ast.literal_eval(args[0])[:2])
        if method == "shortcutKeys":
            return ([(list(k),) for k in self.state[action]],)
        if method == "setForeignShortcutKeys":
            self.writes.append(action)
            self.state[action] = [tuple(row[0]) for row in ast.literal_eval(args[1])]
            return ()
        raise AssertionError(method)


class Tests(unittest.TestCase):
    def setUp(self):
        self.fake = FakeAccel()
        self.mock = patch.object(m, "call", self.fake.call)
        self.mock.start()
        self.addCleanup(self.mock.stop)

    def run_config(self, check=False):
        with contextlib.redirect_stdout(io.StringIO()):
            return m.configure(check)

    def test_drift_apply_rerun(self):
        self.assertEqual(self.run_config(True), 1)
        self.assertEqual(self.fake.writes, [])
        self.assertEqual(self.run_config(), 0)
        self.assertEqual(len(self.fake.writes), 8)
        for _, key, c, a in m.TARGETS:
            self.assertEqual(m.owners(key), [(c, a)])
        self.assertEqual(self.fake.state[m.SPECTACLE_LAUNCH], [m.seq(16777225)])
        self.assertIn((1, 2, 0, 0), self.fake.state[("org.kde.krunner.desktop", "_launch")])
        self.assertIn(m.seq(134217760), self.fake.state[("org.kde.krunner.desktop", "_launch")])
        self.assertIn(m.seq(318767113), self.fake.state[("org.kde.spectacle.desktop", "RectangularRegionScreenShot")])
        self.assertIn(m.seq(268435543), self.fake.state[("kwin", "Overview")])
        self.assertEqual(self.fake.state[("other", "keep")], [m.seq(123)])
        self.fake.writes.clear()
        self.assertEqual(self.run_config(True), 0)
        self.assertEqual(self.run_config(), 0)
        self.assertEqual(self.fake.writes, [])

    def test_conflict_before_any_write(self):
        self.fake.state[("other", "keep")] += [m.seq(m.TARGETS[-1][1])]
        with self.assertRaisesRegex(m.ShortcutError, "Conflict"):
            self.run_config()
        self.assertEqual(self.fake.writes, [])

    def test_missing_registration(self):
        del self.fake.state[("Alacritty.desktop", "New")]
        with self.assertRaisesRegex(m.ShortcutError, "not registered"):
            self.run_config()
        self.assertEqual(self.fake.writes, [])

    def test_parser(self):
        self.assertEqual(m.parse_reply("(@a(ssssssaiai) [],)"), ([],))
        self.assertEqual(m.parse_reply("(@a(ai) [],)"), ([],))
        self.assertEqual(m.parse_reply("([([134217760, 0, 0, 0],)],)"), ([([134217760, 0, 0, 0],)],))
        row = m.parse_reply("([('New', 'New Terminal', 'Alacritty.desktop', 'Alacritty', 'default', 'Default Context', [285212676], @ai [])],)")
        self.assertEqual(row[0][0][-1], [])
        with self.assertRaises(m.ShortcutError):
            m.parse_reply("__import__('os').getcwd()")

    def test_readback_failure(self):
        def ignore_write(method, *args):
            if method == "setForeignShortcutKeys":
                return ()
            return self.fake.call(method, *args)
        with patch.object(m, "call", ignore_write):
            with self.assertRaisesRegex(m.ShortcutError, "Readback differs"):
                self.run_config()


if __name__ == "__main__":
    unittest.main()
