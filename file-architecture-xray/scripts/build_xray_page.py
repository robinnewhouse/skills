#!/usr/bin/env python3
import argparse
import html
import json
from pathlib import Path

# ── Geometry constants for callout line-anchoring ──────────────────────────
# These MUST match the rendered CSS geometry of the code panel.
# Callout top = CODE_HEADER_HEIGHT + CODE_BODY_PADDING_TOP + (line - zone_start) * CODE_ROW_HEIGHT
#
# If you change .code-header padding, .code border, .code-line min-height,
# or <pre> padding in the CSS template below, update these values to match.
#
# CRITICAL: code line divs are joined with "" (no separator) and the <pre>
# tag must contain NO whitespace around the content. Inside <pre>, any stray
# newline renders as a visible ~15px line break, destroying all anchoring.
# ───────────────────────────────────────────────────────────────────────────
CODE_ROW_HEIGHT = 20           # .code-line min-height (px)
CODE_BODY_PADDING_TOP = 18     # <pre> padding-top (px)
CODE_BODY_PADDING_BOTTOM = 18  # <pre> padding-bottom (px)
CODE_HEADER_HEIGHT = 40        # .code border-top (1) + .code-header (12+~15+12) + border-bottom (1) ≈ 40px
CALLOUT_GAP = 14


def read_spec(path: Path) -> dict:
    return json.loads(path.read_text())


def read_lines(path: Path) -> list[str]:
    return path.read_text().splitlines()


def count_lines(path: Path) -> int:
    return len(read_lines(path))


def render_code_excerpt(path: Path, start: int, end: int) -> str:
    lines = read_lines(path)
    start = max(1, start)
    end = min(len(lines), end)
    rendered: list[str] = []
    for lineno in range(start, end + 1):
        text = html.escape(lines[lineno - 1])
        rendered.append(
            f'<div class="code-line" id="line-{lineno}"><span class="ln">{lineno}</span><span class="txt">{text}</span></div>'
        )
    return "".join(rendered)


def render_notes(notes: list[dict]) -> str:
    items: list[str] = []
    for note in notes:
        items.append(
            f'<div class="note"><strong>{html.escape(note["label"])}</strong>{html.escape(note["body"])}</div>'
        )
    return "\n".join(items)


def render_intro_chips(chips: list[str]) -> str:
    return "\n".join(
        f'<div class="story-chip">{html.escape(chip)}</div>' for chip in chips
    )


def detail_lookup(zones: list[dict]) -> str:
    payload = {}
    for zone in zones:
        payload[zone["id"]] = {
            "title": zone["title"],
            "range": zone["range_label"],
            "body": zone["detail_body"],
            "input": zone["input"],
            "output": zone["output"],
        }
    return json.dumps(payload)


def minimap_segments(zones: list[dict], primary_path: Path, total_lines: int) -> str:
    items: list[str] = []
    for zone in zones:
        source = zone["source"]
        zone_path = Path(source["path"]).resolve()
        if zone_path != primary_path:
            continue
        start = max(1, int(source["start"]))
        end = max(start, int(source["end"]))
        top = ((start - 1) / max(total_lines, 1)) * 100
        height = (max(end - start + 1, 1) / max(total_lines, 1)) * 100
        height = max(height, 1.4)
        items.append(
            '<div class="segment" data-target="{id}" style="top:{top:.2f}%; height:{height:.2f}%; background:{color};"></div>'.format(
                id=html.escape(zone["id"]),
                top=top,
                height=height,
                color=html.escape(zone["color"]),
            )
        )
    return "\n".join(items)


def diagram_nodes(zones: list[dict]) -> str:
    nodes: list[str] = []
    y = 16
    width = 280
    height = 76
    x = 28
    for zone in zones:
        meta = zone.get("meta", [])[:2]
        meta_1 = html.escape(meta[0] if len(meta) > 0 else zone["range_label"])
        meta_2 = html.escape(meta[1] if len(meta) > 1 else "")
        clip_id = f"clip-{html.escape(zone['id'])}"
        nodes.append(
            f"""
          <g class="node" data-target="{html.escape(zone["id"])}" transform="translate({x} {y})">
            <defs><clipPath id="{clip_id}"><rect x="0" y="0" rx="18" ry="18" width="{width}" height="{height}" /></clipPath></defs>
            <rect x="0" y="0" rx="18" ry="18" width="{width}" height="{height}" />
            <rect x="0" y="0" width="6" height="{height}" fill="{html.escape(zone["color"])}" stroke="none" clip-path="url(#{clip_id})"></rect>
            <text class="title" x="20" y="28">{html.escape(zone["title"])}</text>
            <text class="meta" x="20" y="49">{meta_1}</text>
            <text class="meta" x="20" y="64">{meta_2}</text>
          </g>
"""
        )
        y += 98
    return "\n".join(nodes)


def diagram_wires(zones: list[dict]) -> str:
    wires: list[str] = []
    y = 16
    width = 280
    height = 76
    x = 28
    for _ in range(len(zones) - 1):
        x_mid = x + width / 2
        y1 = y + height
        y2 = y + 98
        wires.append(
            f'<path class="wire" d="M{x_mid} {y1} C{x_mid} {y1 + 12}, {x_mid} {y2 - 20}, {x_mid} {y2 - 8}" />'
        )
        y += 98
    return "\n".join(wires)


def render_callouts(zone: dict) -> str:
    callouts = zone.get("callouts", [])
    if not callouts:
        return ""

    start = int(zone["source"]["start"])
    rendered: list[str] = []
    for callout in callouts:
        line = int(callout["line"])
        # Exact line anchoring within the code block geometry.
        top = CODE_HEADER_HEIGHT + CODE_BODY_PADDING_TOP + (
            (line - start) * CODE_ROW_HEIGHT
        )
        line_label = callout.get("lines_label") or f"Line {line}"
        title = callout.get("title")
        body = callout["body"]
        rendered.append(
            f"""
            <article class="callout-card" style="top:{top:.0f}px;">
              <div class="callout-line">{html.escape(line_label)}</div>
              {"<h4>" + html.escape(title) + "</h4>" if title else ""}
              <p>{html.escape(body)}</p>
            </article>
"""
        )
    return "\n".join(rendered)


def estimate_callout_height(callout: dict) -> int:
    title = callout.get("title", "")
    body = callout.get("body", "")
    chars = len(title) + len(body)
    text_lines = max(2, (chars // 34) + 1)
    title_bonus = 26 if title else 0
    return 58 + title_bonus + (text_lines * 18)


def estimate_callout_rail_height(zone: dict) -> int:
    start = int(zone["source"]["start"])
    end = int(zone["source"]["end"])
    line_count = max(end - start + 1, 1)
    code_height = CODE_BODY_PADDING_TOP + CODE_BODY_PADDING_BOTTOM + (line_count * CODE_ROW_HEIGHT)
    cards_height = 0
    callouts = zone.get("callouts", [])
    for callout in callouts:
        cards_height += estimate_callout_height(callout) + CALLOUT_GAP
    return max(code_height, cards_height + 24, 260)


def render_slices(zones: list[dict]) -> str:
    rendered: list[str] = []
    for zone in zones:
        source = zone["source"]
        source_path = Path(source["path"]).resolve()
        start = int(source["start"])
        end = int(source["end"])
        code_html = render_code_excerpt(source_path, start, end)
        callouts_html = render_callouts(zone)
        has_callouts = "true" if zone.get("callouts") else "false"
        line_count = max(end - start + 1, 1)
        code_total_height = (
            CODE_HEADER_HEIGHT
            + CODE_BODY_PADDING_TOP
            + CODE_BODY_PADDING_BOTTOM
            + (line_count * CODE_ROW_HEIGHT)
        )
        rendered.append(
            f"""
    <section class="slice" id="slice-{html.escape(zone["id"])}" data-id="{html.escape(zone["id"])}" style="--slice-color:{html.escape(zone["color"])};">
      <div class="slice-head">
        <div>
          <div class="slice-badge">{html.escape(zone["badge"])}</div>
          <h3>{html.escape(zone["title"])}</h3>
          <p>{html.escape(zone["summary"])}</p>
        </div>
        <div class="slice-meta">
          <div class="slice-range">{html.escape(zone["range_label"])}</div>
        </div>
      </div>
      <div class="slice-body">
        <div class="notes">
          {render_notes(zone.get("notes", []))}
        </div>
        <div class="code-shell code-shell-{has_callouts}">
          <div class="callout-overlay" style="height:{code_total_height}px;">
            {callouts_html}
          </div>
          <div class="code">
            <div class="code-header"><span class="dot"></span>{html.escape(str(source_path))}</div>
            <pre>{code_html}</pre>
          </div>
        </div>
      </div>
    </section>
"""
        )
    return "\n".join(rendered)


def build_html(spec: dict) -> str:
    zones = spec["zones"]
    primary_path = Path(spec["source_path"]).resolve()
    total_lines = int(spec.get("source_total_lines") or count_lines(primary_path))
    first_zone = zones[0]
    detail = detail_lookup(zones)
    intro = spec["intro"]

    scale_marks = [
        1,
        max(1, total_lines // 4),
        max(1, total_lines // 2),
        max(1, (total_lines * 3) // 4),
        total_lines,
    ]
    scale_html = "\n".join(
        f'<span style="top:{(mark - 1) / max(total_lines, 1) * 100:.2f}%;">{mark}</span>'
        for mark in scale_marks
    )

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{html.escape(spec["title"])}</title>
<style>
  :root {{
    --ink: #1f1d1a;
    --muted: #6d655d;
    --accent: #d76834;
    --accent-2: #157a6e;
    --accent-3: #2457a5;
    --surface: rgba(255, 252, 246, 0.96);
    --code-bg: #111827;
    --code-panel: #172033;
    --code-text: #e6edf7;
    --code-dim: #9fb1d0;
    --shadow: 0 20px 60px rgba(75, 43, 24, 0.12);
  }}
  * {{ box-sizing: border-box; }}
  html {{ scroll-behavior: smooth; }}
  body {{
    margin: 0;
    background:
      radial-gradient(circle at top left, rgba(215, 104, 52, 0.12), transparent 22%),
      radial-gradient(circle at top right, rgba(21, 122, 110, 0.14), transparent 18%),
      linear-gradient(180deg, #fbf6ee 0%, #f2eadf 100%);
    color: var(--ink);
    font-family: "Avenir Next", "Segoe UI", sans-serif;
  }}
  .page {{ display: grid; grid-template-columns: 420px minmax(0, 1fr); min-height: 100vh; }}
  .left {{
    position: sticky; top: 0; height: 100vh; padding: 28px 24px;
    border-right: 1px solid rgba(109, 101, 93, 0.18);
    background: rgba(255, 250, 242, 0.82); backdrop-filter: blur(10px); overflow: auto;
  }}
  .right {{ padding: 28px 28px 120px; }}
  .hero, .card, .minimap, .slice {{
    border: 1px solid rgba(109, 101, 93, 0.16);
    border-radius: 22px;
    box-shadow: var(--shadow);
  }}
  .hero {{
    padding: 22px;
    background: linear-gradient(135deg, rgba(255, 247, 236, 0.98), rgba(255, 252, 246, 0.94));
    margin-bottom: 18px;
  }}
  .eyebrow {{
    display: inline-flex; align-items: center; gap: 8px; padding: 6px 10px; border-radius: 999px;
    background: rgba(36, 87, 165, 0.08); color: var(--accent-3); font-size: 12px; font-weight: 700;
    letter-spacing: 0.08em; text-transform: uppercase;
  }}
  h1, h2, h3, h4 {{
    font-family: "Iowan Old Style", "Palatino Linotype", "Book Antiqua", Georgia, serif;
    letter-spacing: -0.02em;
  }}
  .hero h1 {{ margin: 14px 0 10px; font-size: 24px; line-height: 1.15; }}
  .hero p, .card p, .intro p, .slice-head p, .callout-card p {{ color: var(--muted); line-height: 1.58; }}
  .path {{
    margin-top: 12px; padding: 12px 14px; border-radius: 16px; background: rgba(31, 29, 26, 0.04);
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; word-break: break-all;
  }}
  .card, .minimap {{ background: var(--surface); padding: 18px; margin-bottom: 18px; }}
  .diagram-shell {{ margin-top: 14px; }}
  svg {{ width: 100%; height: auto; display: block; }}
  .wire {{ fill: none; stroke: rgba(31, 29, 26, 0.28); stroke-width: 2.5; stroke-linecap: round; stroke-linejoin: round; }}
  .node {{ cursor: pointer; }}
  .node rect {{ fill: #fffdf8; stroke: rgba(31, 29, 26, 0.18); stroke-width: 1.5; }}
  .node text.title {{ font-family: "Avenir Next", "Segoe UI", sans-serif; font-size: 13px; font-weight: 700; fill: var(--ink); }}
  .node text.meta {{ font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 10px; fill: var(--muted); }}
  .node.active rect {{ fill: #fff1e7; stroke: var(--accent); }}
  .detail-grid {{ display: grid; gap: 12px; margin-top: 14px; }}
  .detail-grid .pill {{
    width: fit-content; padding: 5px 10px; border-radius: 999px; font-size: 11px; font-weight: 700;
    letter-spacing: 0.05em; text-transform: uppercase; background: rgba(21, 122, 110, 0.08); color: var(--accent-2);
  }}
  .detail-grid h3 {{ margin: 0; font-size: 26px; }}
  .detail-grid .range, .slice-range {{
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; color: var(--muted);
  }}
  .io {{ display: grid; gap: 10px; }}
  .io-box, .note {{
    padding: 12px 14px; border-radius: 16px; background: rgba(31, 29, 26, 0.04);
  }}
  .io-box strong, .note strong {{
    display: block; font-size: 11px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); margin-bottom: 6px;
  }}
  .io-box code {{ font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; color: var(--accent-3); }}
  .minimap-wrap {{ display: grid; grid-template-columns: 36px 1fr; gap: 14px; align-items: start; }}
  .scale {{ position: relative; height: 420px; color: var(--muted); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 11px; }}
  .scale span {{ position: absolute; left: 0; transform: translateY(-50%); }}
  .track {{
    position: relative; height: 420px; border-radius: 999px;
    background: repeating-linear-gradient(to bottom, rgba(31, 29, 26, 0.04) 0, rgba(31, 29, 26, 0.04) 6px, rgba(31, 29, 26, 0.02) 6px, rgba(31, 29, 26, 0.02) 12px);
    border: 1px solid rgba(109, 101, 93, 0.12); overflow: hidden;
  }}
  .segment {{
    position: absolute; left: 8px; right: 8px; border-radius: 999px; cursor: pointer;
    border: 2px solid rgba(255, 255, 255, 0.72); box-shadow: 0 8px 18px rgba(31, 29, 26, 0.12);
  }}
  .segment.active {{ box-shadow: 0 0 0 3px rgba(31, 29, 26, 0.18), 0 14px 28px rgba(31, 29, 26, 0.16); }}
  .legend {{ margin-top: 12px; display: grid; gap: 8px; }}
  .legend-item {{ display: flex; align-items: center; gap: 10px; font-size: 13px; color: var(--muted); }}
  .legend-swatch {{ width: 14px; height: 14px; border-radius: 999px; }}
  .intro {{ max-width: 1040px; margin-bottom: 22px; }}
  .intro h2 {{ font-size: 26px; margin: 0 0 10px; }}
  .story-strip {{ display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 24px; }}
  .story-chip {{ padding: 10px 12px; border-radius: 999px; background: rgba(31, 29, 26, 0.06); font-size: 13px; }}
  .slice {{
    position: relative; overflow: visible; margin-bottom: 22px;
    background: linear-gradient(180deg, rgba(255, 252, 246, 0.97), rgba(255, 248, 239, 0.93));
  }}
  .slice::before {{ content: ""; position: absolute; left: 0; top: 0; bottom: 0; width: 8px; background: var(--slice-color, var(--accent)); }}
  .slice.active {{ box-shadow: 0 0 0 2px rgba(215, 104, 52, 0.18), var(--shadow); }}
  .slice-head {{
    padding: 22px 24px 14px; display: grid; grid-template-columns: minmax(0, 1fr) auto; gap: 14px; align-items: start;
  }}
  .slice-head h3 {{ margin: 8px 0 0; font-size: 30px; }}
  .slice-meta {{ display: grid; gap: 8px; justify-items: end; }}
  .slice-badge {{
    display: inline-flex; align-items: center; padding: 7px 10px; border-radius: 999px;
    font-size: 12px; font-weight: 700; background: rgba(31, 29, 26, 0.06); text-transform: uppercase; letter-spacing: 0.06em;
  }}
  .slice-range {{ background: rgba(36, 87, 165, 0.08); padding: 7px 10px; border-radius: 999px; color: var(--accent-3); }}
  .slice-body {{ display: grid; grid-template-columns: 1fr; gap: 12px; padding: 0 24px 24px; }}
  .notes {{
    display: grid;
    gap: 10px;
    align-content: start;
    grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  }}
  .code-shell {{ position: relative; min-width: 0; }}
  .code-shell-true {{
    display: grid;
    grid-template-columns: 230px minmax(0, 1fr);
    gap: 0;
  }}
  .code-shell-false .callout-overlay {{ display: none; }}
  .callout-overlay {{
    position: relative;
    width: 230px;
    pointer-events: none;
    z-index: 2;
    flex-shrink: 0;
  }}
  .callout-card {{
    position: absolute;
    left: 0;
    right: 0;
    width: auto;
    padding: 10px 12px;
    border-radius: 14px;
    background: rgba(255, 250, 243, 0.95);
    border: 1px solid rgba(109, 101, 93, 0.14);
    box-shadow: 0 8px 20px rgba(75, 43, 24, 0.07);
    pointer-events: auto;
  }}
  .callout-card::after {{
    content: "";
    position: absolute;
    right: -12px;
    top: 18px;
    width: 12px;
    border-top: 1.5px dashed rgba(36, 87, 165, 0.45);
  }}
  .callout-line {{
    margin-bottom: 6px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--accent-3);
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }}
  .callout-card h4 {{ margin: 0 0 6px; font-size: 18px; }}
  .callout-card p {{ margin: 0; font-size: 14px; }}
  .code {{
    background: linear-gradient(180deg, var(--code-bg), var(--code-panel)); color: var(--code-text);
    border-radius: 20px; overflow: auto; border: 1px solid rgba(159, 177, 208, 0.16);
  }}
  .code-header {{
    display: flex; align-items: center; gap: 8px; padding: 12px 14px; border-bottom: 1px solid rgba(159, 177, 208, 0.14);
    font-size: 12px; color: var(--code-dim); font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  }}
  .dot {{ width: 10px; height: 10px; border-radius: 999px; background: #f59e0b; box-shadow: 16px 0 0 #10b981, 32px 0 0 #3b82f6; margin-right: 30px; }}
  pre {{ margin: 0; padding: {CODE_BODY_PADDING_TOP}px 0 {CODE_BODY_PADDING_BOTTOM}px; overflow-x: auto; }}
  .code-line {{
    display: grid; grid-template-columns: 62px minmax(0, 1fr); gap: 14px; padding: 0 18px; min-height: {CODE_ROW_HEIGHT}px; align-items: center; line-height: 1.45; white-space: pre;
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 13px;
  }}
  .ln {{ color: #7f92b8; text-align: right; user-select: none; }}
  .txt {{ color: var(--code-text); }}
  .footer-note {{ margin-top: 12px; color: var(--muted); font-size: 13px; }}
  @media (max-width: 1180px) {{
    .page {{ grid-template-columns: 1fr; }}
    .left {{ position: static; height: auto; border-right: 0; border-bottom: 1px solid rgba(109, 101, 93, 0.18); }}
  }}
  @media (max-width: 940px) {{
    .right {{ padding: 20px 16px 90px; }}
    .left {{ padding: 20px 16px; }}
    .slice-head, .slice-body {{ grid-template-columns: 1fr; }}
    .slice-meta {{ justify-items: start; }}
    .intro h2 {{ font-size: 22px; }}
    .code-shell-true {{ grid-template-columns: 1fr; }}
    .callout-overlay {{
      position: static;
      width: 100%;
      height: auto !important;
      display: grid;
      gap: 10px;
      margin-bottom: 10px;
    }}
    .callout-card {{
      position: static;
      width: 100%;
    }}
    .callout-card::after {{ display: none; }}
  }}
</style>
</head>
<body>
<div class="page">
  <aside class="left">
    <section class="hero">
      <div class="eyebrow">File-Specific Architecture Viewer</div>
      <h1>{html.escape(spec["title"])}</h1>
      <p>{html.escape(spec["subtitle"])}</p>
      <div class="path">{html.escape(str(primary_path))}</div>
    </section>

    <section class="card">
      <h2>Pipeline Diagram</h2>
      <p>Click any node. The right pane jumps to the corresponding architectural slice and code excerpt.</p>
      <div class="diagram-shell">
        <svg viewBox="0 0 340 {110 + (len(zones) * 98)}" aria-label="file architecture flow diagram">
          {diagram_wires(zones)}
          {diagram_nodes(zones)}
        </svg>
      </div>
      <div class="detail-grid">
        <div class="pill">Active Zone</div>
        <h3 id="detail-title">{html.escape(first_zone["title"])}</h3>
        <div class="range" id="detail-range">{html.escape(first_zone["range_label"])}</div>
        <p id="detail-body">{html.escape(first_zone["detail_body"])}</p>
        <div class="io">
          <div class="io-box">
            <strong>Input shape</strong>
            <code id="detail-in">{html.escape(first_zone["input"])}</code>
          </div>
          <div class="io-box">
            <strong>Output shape</strong>
            <code id="detail-out">{html.escape(first_zone["output"])}</code>
          </div>
        </div>
      </div>
    </section>

    <section class="minimap">
      <h2>File Map</h2>
      <div class="minimap-wrap">
        <div class="scale">
          {scale_html}
        </div>
        <div class="track">
          {minimap_segments(zones, primary_path, total_lines)}
        </div>
      </div>
      <div class="legend">
        {"".join(f'<div class="legend-item"><span class="legend-swatch" style="background:{html.escape(zone["color"])}"></span>{html.escape(zone["title"])}</div>' for zone in zones)}
      </div>
    </section>
  </aside>

  <main class="right">
    <section class="intro">
      <div class="eyebrow">{html.escape(intro["eyebrow"])}</div>
      <h2>{html.escape(intro["headline"])}</h2>
      {"".join(f"<p>{html.escape(paragraph)}</p>" for paragraph in intro.get("paragraphs", []))}
      <div class="story-strip">
        {render_intro_chips(intro.get("chips", []))}
      </div>
    </section>

    {render_slices(zones)}

    <p class="footer-note">Primary file: {html.escape(str(primary_path))}</p>
  </main>
</div>

<script>
  const ZONES = {detail};
  const slices = [...document.querySelectorAll(".slice")];
  const nodes = [...document.querySelectorAll(".node")];
  const segments = [...document.querySelectorAll(".segment")];
  const detailTitle = document.getElementById("detail-title");
  const detailRange = document.getElementById("detail-range");
  const detailBody = document.getElementById("detail-body");
  const detailIn = document.getElementById("detail-in");
  const detailOut = document.getElementById("detail-out");
  let activeId = {json.dumps(first_zone["id"])};

  function setActive(id) {{
    activeId = id;
    const zone = ZONES[id];
    if (!zone) return;
    detailTitle.textContent = zone.title;
    detailRange.textContent = zone.range;
    detailBody.textContent = zone.body;
    detailIn.textContent = zone.input;
    detailOut.textContent = zone.output;
    for (const slice of slices) slice.classList.toggle("active", slice.dataset.id === id);
    for (const node of nodes) node.classList.toggle("active", node.dataset.target === id);
    for (const segment of segments) segment.classList.toggle("active", segment.dataset.target === id);
  }}

  function scrollToZone(id) {{
    const target = document.getElementById(`slice-${{id}}`);
    if (!target) return;
    target.scrollIntoView({{ behavior: "smooth", block: "start" }});
    setActive(id);
  }}

  for (const node of nodes) node.addEventListener("click", () => scrollToZone(node.dataset.target));
  for (const segment of segments) segment.addEventListener("click", () => scrollToZone(segment.dataset.target));

  const observer = new IntersectionObserver((entries) => {{
    const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => b.intersectionRatio - a.intersectionRatio);
    if (!visible.length) return;
    setActive(visible[0].target.dataset.id);
  }}, {{ rootMargin: "-20% 0px -45% 0px", threshold: [0.18, 0.4, 0.65] }});

  for (const slice of slices) observer.observe(slice);
  setActive(activeId);
</script>
</body>
</html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a standalone HTML file architecture explainer."
    )
    parser.add_argument("--spec", required=True, help="Path to JSON spec.")
    parser.add_argument("--output", required=True, help="Path to output HTML file.")
    args = parser.parse_args()

    spec_path = Path(args.spec).resolve()
    output_path = Path(args.output).resolve()
    spec = read_spec(spec_path)
    html_text = build_html(spec)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(html_text)
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
