import os
import sys

import pg8000.native

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from db_env import db_params  # noqa: E402

p = db_params()

for port in (5432, 6543):
    try:
        c = pg8000.native.Connection(
            user=p["user"], host=p["host"], port=port, password=p["password"],
            database=p["database"], ssl_context=True, timeout=12)
        print("OK porta", port)
        print("remuneracao =", c.run("select count(*) from raw.remuneracao"))
        rows = c.run("select table_name from information_schema.tables "
                     "where table_schema='raw' order by 1")
        print("tabelas raw:", len(rows))
        marts = c.run("select table_schema, count(*) from information_schema.tables "
                      "where table_schema like 'mart_%' group by 1 order by 1")
        print("marts:", marts)
        c.close()
        break
    except Exception as e:
        print("FALHOU", port, "->", str(e)[:120])