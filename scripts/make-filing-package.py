#!/usr/bin/env python3
"""Build the ethereum/ERCs filing package for the Agent Safety and Security Framework.

Usage:
    python3 scripts/make-filing-package.py [--number 9999] [--discussions-to URL] [--out ercs-pr-package]

Produces:
    <out>/ERCS/erc-<number>.md            the ERC text with the number and asset links rewritten
    <out>/assets/erc-<number>/...          contracts, schemas, vectors and examples copied from assets/erc-asf

Rules applied (learned from the earlier filings of this standards family):
  * asset links inside the ERC text are written ../assets/eip-<number>/... (the ERCs site renames erc-* to eip-*)
  * the `eip` preamble header carries the number; `discussions-to` can be set from the command line
  * a few local lint checks run before writing: title/description length, no "standard" in the title,
    first-mention links for ERC-/EIP- references, no proposal references inside backticks, section order
"""
import argparse
import os
import re
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "ERCS", "erc-asf.md")
ASSETS = os.path.join(ROOT, "assets", "erc-asf")
REQUIRED_SECTIONS = [
    "Abstract",
    "Motivation",
    "Specification",
    "Rationale",
    "Backwards Compatibility",
    "Test Cases",
    "Reference Implementation",
    "Security Considerations",
    "Copyright",
]


def lint(text: str, number: str):
    problems = []
    m = re.search(r"^title: (.*)$", text, re.M)
    title = m.group(1).strip() if m else ""
    if len(title) > 44:
        problems.append(f"title longer than 44 characters ({len(title)})")
    if re.search(r"standard", title, re.I):
        problems.append("title contains the word 'standard'")
    m = re.search(r"^description: (.*)$", text, re.M)
    desc = m.group(1).strip() if m else ""
    if len(desc) > 140:
        problems.append(f"description longer than 140 characters ({len(desc)})")
    if ":" in desc:
        problems.append("description contains a colon")
    if re.search(r"standard", desc, re.I):
        problems.append("description contains the word 'standard'")
    headings = re.findall(r"^## (.+)$", text, re.M)
    order = [h for h in headings if h in REQUIRED_SECTIONS]
    if order != [s for s in REQUIRED_SECTIONS if s in headings]:
        problems.append(f"section order is {order}")
    for s in ["Abstract", "Specification", "Rationale", "Security Considerations", "Copyright"]:
        if s not in headings:
            problems.append(f"missing required section {s}")
    body = text.split("---", 2)[2]
    prose = re.sub(r"```.*?```", "", body, flags=re.S)
    prose_no_code = re.sub(r"`[^`\n]*`", "", prose)
    seen = set()
    for mm in re.finditer(r"(\[)?(ERC|EIP)-(\d+)(\]\(\./eip-\3\.md\))?", prose_no_code):
        n = mm.group(3)
        if n in seen:
            continue
        seen.add(n)
        if not (mm.group(1) and mm.group(4)):
            problems.append(f"first mention of {mm.group(2)}-{n} is not a link")
    no_links = re.sub(r"\]\([^)]*\)", "]", prose)
    for mm in re.finditer(r"`([^`\n]*)`", no_links):
        if re.search(r"(?:eip|erc)-\d+", mm.group(1), re.I):
            problems.append(f"proposal reference inside backticks: {mm.group(0)}")
    if re.search(r"[‘’“”]", text):
        problems.append("smart quotes present")
    for mm in re.finditer(r"\]\((\.\./assets/[^)]+)\)", body):
        if not mm.group(1).startswith(f"../assets/eip-{number}/"):
            problems.append(f"asset link not rewritten: {mm.group(1)}")
    # RFC links must point at rfc-editor.org (the ERCs link allow-list)
    for mm in re.finditer(r"\]\((https?://[^)]+)\)", body):
        url = mm.group(1)
        if "ietf.org" in url:
            problems.append(f"RFC link must use rfc-editor.org: {url}")
    return problems


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--number", default="9999")
    ap.add_argument("--discussions-to", default=None)
    ap.add_argument("--out", default=os.path.join(ROOT, "ercs-pr-package"))
    args = ap.parse_args()

    text = open(SOURCE, encoding="utf-8").read()
    text = re.sub(r"^eip: .*$", f"eip: {args.number}", text, count=1, flags=re.M)
    if args.discussions_to:
        text = re.sub(r"^discussions-to: .*$", f"discussions-to: {args.discussions_to}", text, count=1, flags=re.M)
    text = text.replace("../assets/erc-asf/", f"../assets/eip-{args.number}/")

    problems = lint(text, args.number)
    if problems:
        print("lint problems:")
        for p in problems:
            print("  -", p)
        sys.exit(1)

    out_ercs = os.path.join(args.out, "ERCS")
    out_assets = os.path.join(args.out, "assets", f"erc-{args.number}")
    if os.path.exists(args.out):
        shutil.rmtree(args.out)
    os.makedirs(out_ercs)
    with open(os.path.join(out_ercs, f"erc-{args.number}.md"), "w", encoding="utf-8") as f:
        f.write(text)
    shutil.copytree(ASSETS, out_assets, ignore=shutil.ignore_patterns("manifest.json"))
    count = sum(len(files) for _, _, files in os.walk(args.out))
    print(f"filing package written to {args.out} ({count} files)")


if __name__ == "__main__":
    main()
