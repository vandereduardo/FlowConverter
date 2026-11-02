#!/usr/bin/env python3
"""
FlowConverter Clean-Room Office & Document Converter
Converts between .xlsx, .ods, .csv, .tsv, .html, .pdf, and .pptx using Python standard library
(zipfile, xml.etree.ElementTree, csv, html) and macOS native rendering.
"""
import csv
import html
import os
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile


def read_xlsx_rows(path):
    rows = []
    with zipfile.ZipFile(path, "r") as zf:
        shared_strings = []
        if "xl/sharedStrings.xml" in zf.namelist():
            root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            for si in root.iter():
                if si.tag.endswith("}si") or si.tag == "si":
                    texts = [t.text or "" for t in si.iter() if t.tag.endswith("}t") or t.tag == "t"]
                    shared_strings.append("".join(texts))

        sheet_files = sorted(
            n for n in zf.namelist()
            if n.startswith("xl/worksheets/sheet") and n.endswith(".xml")
        )
        if not sheet_files:
            return rows

        sheet_root = ET.fromstring(zf.read(sheet_files[0]))
        for row_el in sheet_root.iter():
            if row_el.tag.endswith("}row") or row_el.tag == "row":
                current = []
                for c_el in row_el:
                    if not (c_el.tag.endswith("}c") or c_el.tag == "c"):
                        continue
                    cell_type = c_el.attrib.get("t", "")
                    val_text = ""
                    for child in c_el:
                        if child.tag.endswith("}v") or child.tag == "v":
                            val_text = child.text or ""
                        elif child.tag.endswith("}is") or child.tag == "is":
                            val_text = "".join(t.text or "" for t in child.iter() if t.tag.endswith("}t") or t.tag == "t")
                    if cell_type == "s" and val_text.isdigit():
                        idx = int(val_text)
                        if 0 <= idx < len(shared_strings):
                            val_text = shared_strings[idx]
                    current.append(val_text)
                rows.append(current)
    return rows


def read_ods_rows(path):
    rows = []
    with zipfile.ZipFile(path, "r") as zf:
        if "content.xml" not in zf.namelist():
            return rows
        root = ET.fromstring(zf.read("content.xml"))
        for row_el in root.iter():
            if row_el.tag.endswith("}table-row"):
                current = []
                for cell_el in row_el:
                    if cell_el.tag.endswith("}table-cell"):
                        texts = [t.text or "" for t in cell_el.iter() if t.tag.endswith("}p")]
                        current.append(" ".join(texts))
                if any(c != "" for c in current):
                    rows.append(current)
    return rows


def write_xlsx_rows(rows, out_path):
    content_types = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>"""
    root_rels = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""
    workbook = """<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>"""
    wb_rels = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>"""

    def col_letter(n):
        res = ""
        while n >= 0:
            res = chr(65 + (n % 26)) + res
            n = (n // 26) - 1
        return res

    sheet_lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
    ]
    for r_idx, row in enumerate(rows, start=1):
        sheet_lines.append(f'<row r="{r_idx}">')
        for c_idx, val in enumerate(row):
            ref = f"{col_letter(c_idx)}{r_idx}"
            esc = html.escape(str(val))
            sheet_lines.append(f'<c r="{ref}" t="inlineStr"><is><t>{esc}</t></is></c>')
        sheet_lines.append("</row>")
    sheet_lines.append("</sheetData></worksheet>")

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", content_types)
        zf.writestr("_rels/.rels", root_rels)
        zf.writestr("xl/workbook.xml", workbook)
        zf.writestr("xl/_rels/workbook.xml.rels", wb_rels)
        zf.writestr("xl/worksheets/sheet1.xml", "".join(sheet_lines))


def write_ods_rows(rows, out_path):
    manifest = """<?xml version="1.0" encoding="UTF-8"?>
<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
  <manifest:file-entry manifest:full-path="/" manifest:media-type="application/vnd.oasis.opendocument.spreadsheet"/>
  <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
</manifest:manifest>"""
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
        'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
        'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" office:version="1.2">',
        '<office:body><office:spreadsheet><table:table table:name="Sheet1">'
    ]
    for row in rows:
        lines.append("<table:table-row>")
        for val in row:
            esc = html.escape(str(val))
            lines.append(f'<table:table-cell office:value-type="string"><text:p>{esc}</text:p></table:table-cell>')
        lines.append("</table:table-row>")
    lines.append("</table:table></office:spreadsheet></office:body></office:document-content>")

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("mimetype", "application/vnd.oasis.opendocument.spreadsheet", compress_type=zipfile.ZIP_STORED)
        zf.writestr("META-INF/manifest.xml", manifest)
        zf.writestr("content.xml", "".join(lines))


def read_tabular(src_path):
    ext = os.path.splitext(src_path)[1].lower()
    if ext == ".xlsx":
        return read_xlsx_rows(src_path)
    if ext == ".ods":
        return read_ods_rows(src_path)
    delim = "\t" if ext == ".tsv" else ","
    with open(src_path, "r", encoding="utf-8", errors="replace", newline="") as f:
        return list(csv.reader(f, delimiter=delim))


def write_tabular(rows, out_path):
    ext = os.path.splitext(out_path)[1].lower()
    if ext == ".xlsx":
        write_xlsx_rows(rows, out_path)
    elif ext == ".ods":
        write_ods_rows(rows, out_path)
    elif ext in (".csv", ".tsv"):
        delim = "\t" if ext == ".tsv" else ","
        with open(out_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f, delimiter=delim)
            writer.writerows(rows)
    elif ext == ".html":
        lines = [
            "<!DOCTYPE html><html><head><meta charset='utf-8'>",
            "<style>body{font-family:-apple-system,sans-serif;padding:24px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #d0d7de;padding:8px 12px;text-align:left;}tr:nth-child(even){background:#f6f8fa;}</style>",
            "</head><body><table>"
        ]
        for idx, row in enumerate(rows):
            tag = "th" if idx == 0 else "td"
            cells = "".join(f"<{tag}>{html.escape(str(c))}</{tag}>" for c in row)
            lines.append(f"<tr>{cells}</tr>")
        lines.append("</table></body></html>")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))


def extract_pptx_text_to_html(src_path, out_html):
    slides = []
    with zipfile.ZipFile(src_path, "r") as zf:
        slide_files = sorted(
            n for n in zf.namelist()
            if n.startswith("ppt/slides/slide") and n.endswith(".xml")
        )
        for sf in slide_files:
            root = ET.fromstring(zf.read(sf))
            paras = []
            for p_el in root.iter():
                if p_el.tag.endswith("}p"):
                    runs = [t.text or "" for t in p_el.iter() if t.tag.endswith("}t")]
                    line = "".join(runs).strip()
                    if line:
                        paras.append(line)
            slides.append(paras)

    lines = [
        "<!DOCTYPE html><html><head><meta charset='utf-8'>",
        "<style>body{font-family:-apple-system,sans-serif;padding:32px;background:#fff;color:#111;}.slide{border:1px solid #d0d7de;border-radius:12px;padding:24px;margin-bottom:24px;page-break-after:always;}</style>",
        "</head><body>"
    ]
    for i, paras in enumerate(slides, start=1):
        lines.append(f"<div class='slide'><h2>Slide {i}</h2>")
        for p in paras:
            lines.append(f"<p>{html.escape(p)}</p>")
        lines.append("</div>")
    lines.append("</body></html>")
    with open(out_html, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))


def main():
    if len(sys.argv) < 3:
        sys.exit(1)
    src_path = sys.argv[1]
    out_path = sys.argv[2]
    src_ext = os.path.splitext(src_path)[1].lower()
    out_ext = os.path.splitext(out_path)[1].lower()

    if src_ext in (".xlsx", ".ods", ".csv", ".tsv") and out_ext in (".xlsx", ".ods", ".csv", ".tsv", ".html"):
        rows = read_tabular(src_path)
        write_tabular(rows, out_path)
        sys.exit(0)

    if src_ext == ".pptx" and out_ext == ".html":
        extract_pptx_text_to_html(src_path, out_path)
        sys.exit(0)

    sys.exit(2)


if __name__ == "__main__":
    main()
