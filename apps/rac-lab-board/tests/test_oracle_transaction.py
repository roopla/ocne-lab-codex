"""Fake-driver tests of Python Oracle transaction behavior; NOT a live RAC validation."""

import importlib.util, types, unittest, sys
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "tasks", Path(__file__).resolve().parents[1] / "backend/python-tasks/server.py"
)
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)


class IntegrityError(Exception):
    pass


class Cursor:
    def __init__(self, fail=None):
        self.fail = fail
        self.sql = []

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def execute(self, sql, **params):
        self.sql.append((sql, params))
        if sql.startswith("INSERT") and self.fail:
            raise self.fail

    def fetchall(self):
        return [
            (
                "00000000-0000-0000-0000-000000000001",
                "Original",
                "2026-10-12T12:00:00.000Z",
            )
        ]


class Connection:
    def __init__(self, cursor, commit_error=False):
        self.c = cursor
        self.commits = 0
        self.rollbacks = 0
        self.commit_error = commit_error

    def cursor(self):
        return self.c

    def commit(self):
        self.commits += 1
        if self.commit_error:
            raise ConnectionError("Simulated lost commit reply")

    def rollback(self):
        self.rollbacks += 1


class Transactions(unittest.TestCase):
    def store(self, fail=None, commit_error=False):
        store = m.OracleStore.__new__(m.OracleStore)
        store.driver = types.SimpleNamespace(IntegrityError=IntegrityError)
        self.con = Connection(Cursor(fail), commit_error)
        store.local = types.SimpleNamespace(con=self.con)
        return store

    def test_success_bound_variables_and_commit(self):
        store = self.store()
        row, duplicate = store.write("id", "text")
        self.assertFalse(duplicate)
        self.assertEqual(self.con.commits, 1)
        sql, params = self.con.c.sql[0]
        self.assertIn(":body", sql)
        self.assertEqual(params, {"id": "id", "body": "text"})

    def test_duplicate_rolls_back_then_reads(self):
        store = self.store(IntegrityError(types.SimpleNamespace(code=1)))
        _, dup = store.write("id", "Original")
        self.assertTrue(dup)
        self.assertEqual(self.con.rollbacks, 1)
        self.assertEqual(self.con.commits, 0)

    def test_duplicate_different_text_conflicts(self):
        with self.assertRaises(m.Conflict):
            self.store(IntegrityError(types.SimpleNamespace(code=1))).write(
                "id", "Changed"
            )

    def test_other_integrity_error_not_deduplicated(self):
        with self.assertRaises(IntegrityError):
            self.store(IntegrityError(types.SimpleNamespace(code=2290))).write(
                "id", "Original"
            )

    def test_unknown_commit_is_not_replayed(self):
        with self.assertRaises(ConnectionError):
            self.store(commit_error=True).write("id", "Original")
        self.assertEqual(self.con.commits, 1)
        self.assertEqual(sum(sql.startswith("INSERT") for sql, _ in self.con.c.sql), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
