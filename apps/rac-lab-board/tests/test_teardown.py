"""Safety contracts for the destructive helper; all Kubernetes calls are mocked."""

import contextlib
import io
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import remove_app


def owned(kind, name):
    return {
        "metadata": {
            "uid": kind + "/" + name,
            "labels": {"app.kubernetes.io/part-of": "rac-lab-board"},
        }
    }


class RemovalSafety(unittest.TestCase):
    def invoke(self, args, lookup=owned):
        with patch.object(sys, "argv", ["remove_app.py", *args]), patch.object(
            remove_app, "get", side_effect=lookup
        ), patch.object(
            remove_app.subprocess, "check_output", return_value="lab-context"
        ), patch.object(
            remove_app.subprocess, "run"
        ) as mutation, contextlib.redirect_stdout(
            io.StringIO()
        ):
            remove_app.main()
            return mutation.call_args_list

    def test_plan_never_deletes(self):
        self.assertEqual(self.invoke([]), [])

    def test_wrong_owner_aborts_before_any_delete(self):
        def lookup(kind, name):
            obj = owned(kind, name)
            if kind == "configmap":
                obj["metadata"]["labels"][
                    "app.kubernetes.io/part-of"
                ] = "another-project"
            return obj

        with patch.object(sys, "argv", ["remove_app.py", "--execute"]), patch.object(
            remove_app, "get", side_effect=lookup
        ), patch.object(
            remove_app.subprocess, "run"
        ) as mutation, contextlib.redirect_stdout(
            io.StringIO()
        ):
            with self.assertRaisesRegex(SystemExit, "Ownership mismatch"):
                remove_app.main()
            mutation.assert_not_called()

    def test_default_uninstall_preserves_secrets_namespace_and_rac(self):
        calls = self.invoke(["--execute"])
        self.assertEqual(len(calls), 13)
        for call in calls:
            args = call.args[0]
            self.assertEqual(args[:4], ["kubectl", "-n", "rac-app", "delete"])
            self.assertIn(
                args[4], ("deployment", "service", "poddisruptionbudget", "configmap")
            )
            self.assertTrue(
                args[5].startswith("board-") or args[5] == "rac-board-config"
            )

    def test_optional_secret_removal_only_targets_two_app_secrets(self):
        calls = self.invoke(["--execute", "--remove-secrets"])
        secrets = [c.args[0][5] for c in calls if c.args[0][4] == "secret"]
        self.assertEqual(secrets, ["board-tasks-db", "board-notes-db"])

    def test_replaced_object_stops_removal(self):
        seen = {}

        def lookup(kind, name):
            key = (kind, name)
            seen[key] = seen.get(key, 0) + 1
            obj = owned(kind, name)
            if seen[key] > 1:
                obj["metadata"]["uid"] += "-new"
            return obj

        with self.assertRaisesRegex(SystemExit, "Object replaced"):
            self.invoke(["--execute"], lookup)


if __name__ == "__main__":
    unittest.main(verbosity=2)
