"""Fetch only missing identified public bank-logo SVGs at build time.
No application runtime network access, and no financial data is transmitted.
A failed download leaves the honest generic fallback in the app.
"""
import hashlib
import json
import pathlib
import re
import urllib.request
import urllib.parse
import xml.etree.ElementTree as ET

FILES = {
    "jp-jppost": "Japan Post Bank Logo.svg",
    "jp-resona": "Resona Bank logo.svg",
    "jp-rakuten": "Rakuten Bank logo.svg",
    "jp-seven": "7bank logo.svg",
    "jp-paypay": "PayPay Bank logo.svg",
    "jp-sbi": "SBI Sumishin Net Bank logo.svg",
    "jp-sony": "Sony Bank logo.svg",
    "us-usbank": "U.S. Bancorp logo.svg",
    "us-capitalone": "Capital One logo.svg",
    "us-pnc": "PNClogo.svg",
    "us-truist": "Truist Financial logo.svg"
}
ROOT = pathlib.Path("PocketLedger/Assets.xcassets")

def validate(data):
    if len(data) > 500000 or re.search(br'<!DOCTYPE|<!ENTITY', data, re.I):
        raise ValueError("unsupported XML")
    root = ET.fromstring(data)
    if root.tag.split("}")[-1] != "svg":
        raise ValueError("not an SVG")
    for item in root.iter():
        if item.tag.split("}")[-1].lower() in {"script", "foreignobject", "image", "iframe", "style"}:
            raise ValueError("unsupported SVG element")
        for key, value in item.attrib.items():
            name = key.split("}")[-1].lower()
            if name.startswith("on") or (name == "href" and not value.startswith("#")):
                raise ValueError("external/active content")
            for target in re.findall(r"url\((.*?)\)", value, re.I):
                if not target.strip(" '\"").startswith("#"):
                    raise ValueError("external reference")
    return data

for bank, filename in FILES.items():
    folder = ROOT / ("bank-" + bank + ".imageset")
    # Preserve the checked-in artwork, including PNG sets such as PNC.
    # The network is only a fallback for genuinely absent resources.
    try:
        images = json.loads((folder / "Contents.json").read_text())["images"]
        bundled = [folder / image["filename"] for image in images if "filename" in image]
        if bundled and all(image.is_file() and image.stat().st_size > 0 for image in bundled):
            print("Bundled:", bank)
            continue
    except (OSError, ValueError, KeyError, TypeError):
        pass
    try:
        name = filename.replace(" ", "_")
        digest = hashlib.md5(name.encode()).hexdigest()
        url = "https://upload.wikimedia.org/wikipedia/commons/" + digest[0] + "/" + digest[:2] + "/" + urllib.parse.quote(name)
        req = urllib.request.Request(url, headers={"User-Agent": "PocketLedgerBankLogoBuild/1.0 (bank identification artwork; Github Actions)"})
        with urllib.request.urlopen(req, timeout=12) as response:
            data = validate(response.read(500001))
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "logo.svg").write_bytes(data)
        (folder / "Contents.json").write_text(json.dumps({
            "images": [{"filename": "logo.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "original"}
        }))
        print("Added:", bank, hashlib.sha256(data).hexdigest())
    except Exception as error:
        print("Unavailable:", bank, str(error))
