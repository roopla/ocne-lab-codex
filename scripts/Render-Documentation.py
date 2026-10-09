"""Render the two guide HTML copies and statically validate project documentation.
Dependency: Markdown==3.7 installed under private/doc-tools (see README).
No VM, network, SSH, or guest commands are executed.
"""
from pathlib import Path
from html import escape
from html.parser import HTMLParser
from urllib.parse import urlsplit, unquote
import argparse
import hashlib
import re
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "private" / "doc-tools"))
try:
    import markdown
except ImportError:
    raise SystemExit("Install Markdown==3.7 into private/doc-tools using the README command.")
if markdown.__version__ != "3.7":
    raise SystemExit("Expected Markdown==3.7 for reproducible guide HTML.")

GUIDES = [
    ROOT / "docs/OCNE-1.9-Golden-VM-Cloning-Guide.md",
    ROOT / "docs/OCNE-1.9-OL9-Setup-Guide.md",
]
CSS = """
body{margin:0;background:#eef2f6;color:#1d2b3c;font:16px/1.65 system-ui,Segoe UI,sans-serif}
main{max-width:1060px;margin:28px auto;padding:32px 44px;background:white}
h1,h2,h3{color:#103c5c;line-height:1.3;break-after:avoid}
h1{border-bottom:3px solid #16869a;padding-bottom:12px}
h2{margin-top:2em}a{color:#086783}code{font:0.9em Consolas,monospace;background:#edf2f6;padding:2px 4px}
pre{background:#152638;color:#ecf4fa;padding:18px;overflow-x:auto;line-height:1.5}
pre code{padding:0;background:none;color:inherit;white-space:pre}
table{border-collapse:collapse;width:100%;font-size:14px;margin:16px 0}
th{background:#103c5c;color:white;text-align:left}td,th{padding:9px;border:1px solid #d7e0e7;vertical-align:top}
tr:nth-child(even){background:#f5f8fa}.notice{padding:12px;background:#edf5f6}
@media(max-width:700px){main{padding:18px;margin:0}table{display:block;overflow-x:auto}}
@media print{body{background:white;font-size:10pt}main{margin:0;padding:0}
pre,pre code{white-space:pre-wrap;overflow-wrap:anywhere;background:#f2f4f6;color:black}
tr{break-inside:avoid}a{color:#163f53}.notice{background:white}}
"""

def render_body(source):
    return markdown.markdown(source, extensions=["fenced_code", "tables", "toc", "sane_lists"],
                             output_format="html5")

def page(path):
    source = path.read_text(encoding="utf-8")
    title = source.splitlines()[0].lstrip("# ")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    return (
        '<!doctype html>\n<html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        f"<title>{escape(title)}</title><style>{CSS}</style></head>\n<body><main>\n"
        f'<!-- Source SHA256: {digest}; renderer Markdown 3.7 -->\n'
        f'<p class="notice">Generated from <a href="{path.name}">the Markdown source</a>. '
        'Use <a href="OPERATING-LAB.md">Operating the lab</a> for the completed installation.</p>\n'
        + render_body(source) + "\n</main></body></html>\n"
    )

class Elements(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links, self.ids, self.code = [], [], []
        self.in_pre = False
        self.part = []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.append(attrs["id"])
        if tag == "a" and "href" in attrs:
            self.links.append(attrs["href"])
        if tag == "pre":
            self.in_pre = True
            self.part = []
    def handle_data(self, data):
        if self.in_pre:
            self.part.append(data)
    def handle_endtag(self, tag):
        if tag == "pre":
            self.code.append("".join(self.part))
            self.in_pre = False

def parse_html(content):
    parser = Elements()
    parser.feed(content)
    return parser

def fences(source, label):
    result = []
    current = None
    for line in source.splitlines():
        if line.startswith(chr(96)*3):
            if current is None:
                current = []
            else:
                result.append("\n".join(current) + "\n")
                current = None
        elif current is not None:
            current.append(line)
    if current is not None:
        raise ValueError(f"{label}: unclosed code fence")
    return result

def validate():
    documents = [ROOT/"README.md", ROOT/"README-CLONING.md", ROOT/"AGENTS.md",
                 *sorted((ROOT/"docs").glob("*.md"))]
    errors = []
    local_links = 0
    for path in documents:
        source = path.read_text(encoding="utf-8")
        label = str(path.relative_to(ROOT))
        if r"C:\OCNE19-Lab" in source:
            errors.append(f"{label}: stale C: project path")
        if chr(0xfffd) in source or chr(167) in source:
            errors.append(f"{label}: encoding/placeholder artifact")
        try:
            blocks = fences(source, label)
        except ValueError as exc:
            errors.append(str(exc))
            continue
        parsed = parse_html(render_body(source))
        if [s.rstrip("\n") for s in blocks] != [s.rstrip("\n") for s in parsed.code]:
            errors.append(f"{label}: rendered fenced commands differ from source")
        if len(parsed.ids) != len(set(parsed.ids)):
            errors.append(f"{label}: duplicate heading IDs")
        for href in parsed.links:
            u = urlsplit(href)
            if u.scheme or u.netloc:
                continue
            local_links += 1
            target = (path.parent / unquote(u.path)).resolve() if u.path else path
            if not target.is_relative_to(ROOT):
                errors.append(f"{label}: local link leaves project: {href}")
                continue
            if not target.exists():
                errors.append(f"{label}: missing local link: {href}")
                continue
            if u.fragment and target.suffix in (".md", ".html"):
                content = target.read_text(encoding="utf-8")
                ids = parse_html(render_body(content) if target.suffix == ".md" else content).ids
                if unquote(u.fragment) not in ids:
                    errors.append(f"{label}: missing local anchor: {href}")
    for path in GUIDES:
        html_path = path.with_suffix(".html")
        if not html_path.exists() or html_path.read_text(encoding="utf-8") != page(path):
            errors.append(f"{html_path.name}: regenerate from current Markdown")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(documents)} Markdown files, {local_links} local links, "
          "fence/code preservation, heading IDs, project paths, UTF-8, and both HTML copies.")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate without writing")
    args = parser.parse_args()
    if not args.check:
        for path in GUIDES:
            path.with_suffix(".html").write_text(page(path), encoding="utf-8", newline="\n")
            print("Rendered "+str(path.with_suffix(".html").relative_to(ROOT)))
    validate()

if __name__ == "__main__":
    main()
