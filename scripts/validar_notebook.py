import json

caminho = "notebooks/eda.ipynb"
linhas = open(caminho, encoding="utf-8").read().split("\n")

achados = []
for i, linha in enumerate(linhas):
    if '"source"' in linha and i + 1 < len(linhas) and '"source"' in linhas[i + 1]:
        achados.append(i + 1)

print("chave 'source' duplicada nas linhas:", achados or "nenhuma")

d = json.loads("\n".join(linhas))
print(f"JSON valido | celulas: {len(d['cells'])} | "
      f"codigo: {len([c for c in d['cells'] if c['cell_type'] == 'code'])} | "
      f"markdown: {len([c for c in d['cells'] if c['cell_type'] == 'markdown'])}")

for i, c in enumerate(d["cells"]):
    if c["cell_type"] == "code":
        src = "".join(c["source"])
        status = "OK" if src.strip() else "VAZIA"
        primeira = src.strip().split("\n")[0][:60]
        print(f"  celula {i:2} {status:6} {primeira}")