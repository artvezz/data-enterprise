import os
import sys

import pg8000.native

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db_env import db_params  # noqa: E402

p = db_params()

c = pg8000.native.Connection(
    user=p["user"], host=p["host"], port=p["port"], password=p["password"],
    database=p["database"], ssl_context=True, timeout=15)

rows = c.run(
    "select table_name, column_name, data_type, is_nullable "
    "from information_schema.columns "
    "where table_schema='raw' order by table_name, ordinal_position"
)

schema = {}
for t, col, dt, null in rows:
    schema.setdefault(t, []).append(f"{col} {dt}")

out = []
for t in sorted(schema):
    out.append(f"-- {t}")
    out.append(f"--   {', '.join(schema[t])}")
print("\n".join(out))
c.close()