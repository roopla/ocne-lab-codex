"""Generate the combined app manual and printable HTML from reviewed source chapters."""

import argparse
from pathlib import Path
import re
import sys
from prepare import APP, LAB

sys.path.insert(0, str(LAB / "private/doc-tools"))
try:
    import markdown
except ImportError:
    raise SystemExit(
        "Install Markdown==3.7 under private/doc-tools; see the root README"
    )
if markdown.__version__ != "3.7":
    raise SystemExit("Expected Markdown==3.7")


def content():
    docs = APP / "docs"
    introduction = (docs / "MANUAL-INTRO.md").read_text(encoding="utf-8")
    deployment = (docs / "DEPLOYMENT.md").read_text(encoding="utf-8").split("\n", 1)[1]
    internals = (
        (docs / "INNER-WORKINGS.md").read_text(encoding="utf-8").split("\n", 1)[1]
    )
    destroy = (docs / "DESTROY.md").read_text(encoding="utf-8").split("\n", 1)[1]
    destroy = re.sub(r"^## (\d+)\. ", r"### 12.\1. ", destroy, flags=re.M)
    destroy = re.sub(r"^## ", "### ", destroy, flags=re.M)
    source = (
        introduction
        + "\n"
        + deployment
        + "\n"
        + internals
        + "\n## 12. Stop, destroy and redeploy\n"
        + destroy
    )
    renderer = markdown.Markdown(
        extensions=["fenced_code", "tables", "toc", "sane_lists"]
    )
    body = renderer.convert(source)
    style = """body{margin:0;background:#eef3f3;color:#18313b;font:16px/1.65 system-ui,Segoe UI,sans-serif}main{max-width:1140px;margin:28px auto;padding:36px;background:white}h1,h2,h3{line-height:1.25;color:#164d43}h2{margin-top:2.2em;border-bottom:1px solid #bed4ce;padding-bottom:10px}a{color:#076c80}img{max-width:100%;height:auto}table{width:100%;border-collapse:collapse;font-size:14px;table-layout:fixed}td,th{border:1px solid #c8d7d8;padding:9px;vertical-align:top;overflow-wrap:anywhere}th{background:#174b43;color:white}tr:nth-child(even){background:#f3f7f7}pre{padding:18px;background:#122d36;color:#e8f5f0;overflow-x:auto;font:13px/1.55 Consolas,monospace}code{overflow-wrap:anywhere}pre code{white-space:pre;overflow-wrap:normal}nav{background:#f0f7f5;padding:20px}nav ul{padding-left:22px}.notice{border-left:4px solid #168879;padding:12px;background:#e8f5ef}@media(max-width:700px){main{padding:16px;margin:0}table{display:block;overflow:auto;table-layout:auto}}@media print{body{background:white;font-size:10pt}main{margin:0;padding:0}nav{display:none}pre,pre code{white-space:pre-wrap;overflow-wrap:anywhere;color:black;background:#f4f6f6}h2,h3{break-after:avoid}tr,img{break-inside:avoid}}"""
    html = (
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RAC Lab Board - Complete Manual</title><style>'
        + style
        + '</style></head><body><main><p class="notice">Tested deployment: 13 October 2026. Main URL: <a href="http://localhost:8080">http://localhost:8080</a> while the workstation SSH tunnel is running. First installation and teardown commands change the lab; follow their stated scope.</p><nav><details><summary><strong>Contents - expand to jump to a step</strong></summary>'
        + renderer.toc
        + "</details></nav>"
        + body
        + "</main></body></html>\n"
    )
    return {docs / "MANUAL.md": source, docs / "MANUAL.html": html}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    for path, expected in content().items():
        if args.check:
            if not path.exists() or path.read_text(encoding="utf-8") != expected:
                raise SystemExit("Stale generated manual: " + str(path))
        else:
            path.write_text(expected, encoding="utf-8", newline="\n")
        print(("Verified " if args.check else "Wrote ") + str(path))
