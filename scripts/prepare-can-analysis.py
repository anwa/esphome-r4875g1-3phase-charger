#!/usr/bin/env python3
"""Prepare compact CAN/ESPHome evidence for further analysis.

The script scans the repository's logs/ directory for:

* Waveshare USB-CAN autosave files named YYYYMMDD_HHMMSS_mmm.txt
* ESPHome web log captures named charger_*_YYYYMMDD-HHMMSS.log

It does not modify source logs.  It creates one Markdown analysis bundle containing
source statistics, selected ESPHome events, CAN silence/gap anomalies, CAN-ID
statistics and (when absolute ESPHome timestamps are available) CAN frames around
matching ESPHome events.

Only Python's standard library is required.
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import datetime as dt
import re
import sys
from pathlib import Path
from typing import Iterable, Optional


CAN_FILE_RE = re.compile(r"^(?P<date>\d{8})_(?P<time>\d{6})_(?P<msec>\d{3})\.txt$", re.I)
ESP_FILE_RE = re.compile(r"^charger_.*_(?P<date>\d{8})-(?P<time>\d{6})\.log$", re.I)
ESP_TIMESTAMP_RE = re.compile(
    r"^\[(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3})\]\s?(?P<msg>.*)$"
)
ESP_LEVEL_RE = re.compile(r"\[(?P<level>[IWEVD])\]")

# Deliberately broad: the goal is preselection, not deciding the diagnosis.
ESP_INTEREST_RE = re.compile(
    r"(?:"
    r"\[(?:W|E)\]"
    r"|\bCAN\b|TWAI|BUS[_ -]?OFF|OFFLINE|DISCOVERING|ONLINE"
    r"|discover|reconnect|watchdog|timeout|fault|fail|error|recover"
    r"|UNKNOWN|capabil|propert|single[- ]?shot|blackstart|setpoint"
    r")",
    re.I,
)


@dataclasses.dataclass(frozen=True)
class CanFrame:
    source: Path
    number: int
    direction: str
    timestamp: dt.datetime
    frame_format: str
    frame_type: str
    frame_id: str
    data_length: int
    data_hex: str
    raw: str


@dataclasses.dataclass(frozen=True)
class EspLine:
    source: Path
    line_no: int
    timestamp: Optional[dt.datetime]
    message: str
    raw: str


@dataclasses.dataclass(frozen=True)
class EspSelection:
    source: Path
    start_line: int
    end_line: int
    lines: tuple[EspLine, ...]


@dataclasses.dataclass(frozen=True)
class CanGap:
    source: Path
    previous: CanFrame
    current: CanFrame
    seconds: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a compact Markdown bundle from ESPHome and USB-CAN log files."
    )
    parser.add_argument(
        "--logs-dir",
        type=Path,
        default=None,
        help="Log directory (default: <repo>/logs).",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output Markdown file (default: logs/can-analysis-YYYYMMDD-HHMMSS.md).",
    )
    parser.add_argument(
        "--can-window",
        type=float,
        default=2.0,
        help="Seconds before/after timestamped ESPHome events to include CAN frames (default: 2.0).",
    )
    parser.add_argument(
        "--gap-threshold",
        type=float,
        default=1.0,
        help="Report CAN silence gaps at or above this many seconds (default: 1.0).",
    )
    parser.add_argument(
        "--context",
        type=int,
        default=2,
        help="ESPHome context lines before/after interesting lines (default: 2).",
    )
    parser.add_argument(
        "--max-can-frames",
        type=int,
        default=300,
        help="Maximum CAN frames emitted across correlated event windows (default: 300).",
    )
    parser.add_argument(
        "--max-gaps",
        type=int,
        default=100,
        help="Maximum CAN gaps included in the report (default: 100).",
    )
    parser.add_argument(
        "--all-esp-info",
        action="store_true",
        help="Include every ESPHome INFO line instead of keyword/error preselection.",
    )
    return parser.parse_args()


def repo_root_from_script() -> Path:
    return Path(__file__).resolve().parent.parent


def parse_file_start(name: str, regex: re.Pattern[str]) -> Optional[dt.datetime]:
    match = regex.match(name)
    if not match:
        return None
    base = dt.datetime.strptime(match.group("date") + match.group("time"), "%Y%m%d%H%M%S")
    if "msec" in match.groupdict() and match.group("msec") is not None:
        base = base.replace(microsecond=int(match.group("msec")) * 1000)
    return base


def parse_can_file(path: Path) -> tuple[list[CanFrame], list[str]]:
    frames: list[CanFrame] = []
    rejected: list[str] = []
    file_date = parse_file_start(path.name, CAN_FILE_RE)
    if file_date is None:
        return frames, rejected

    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\r\n")
            if not line.strip() or line.lstrip().startswith("No "):
                continue

            # Waveshare writes columns separated by a large run of spaces.
            parts = re.split(r"\s{2,}", line.strip())
            if len(parts) < 8 or not parts[0].isdigit():
                rejected.append(line)
                continue

            try:
                number = int(parts[0])
                direction = parts[1]
                tod = dt.datetime.strptime(parts[2], "%H:%M:%S %f").time()
                timestamp = dt.datetime.combine(file_date.date(), tod)
                # Autosave files can cross midnight.  Resolve a large backwards jump.
                if frames and timestamp < frames[-1].timestamp - dt.timedelta(hours=12):
                    timestamp += dt.timedelta(days=1)
                frame_format = parts[3]
                frame_type = parts[4]
                frame_id = parts[5].lower()
                data_length = int(parts[6])
                data_hex = " ".join(parts[7].split()).upper()
            except (ValueError, IndexError):
                rejected.append(line)
                continue

            frames.append(
                CanFrame(
                    source=path,
                    number=number,
                    direction=direction,
                    timestamp=timestamp,
                    frame_format=frame_format,
                    frame_type=frame_type,
                    frame_id=frame_id,
                    data_length=data_length,
                    data_hex=data_hex,
                    raw=line,
                )
            )

    return frames, rejected


def parse_esphome_file(path: Path) -> list[EspLine]:
    lines: list[EspLine] = []
    with path.open("r", encoding="utf-8-sig", errors="replace") as handle:
        for line_no, raw_line in enumerate(handle, start=1):
            raw = raw_line.rstrip("\r\n")
            match = ESP_TIMESTAMP_RE.match(raw)
            if match:
                timestamp = dt.datetime.strptime(match.group("ts"), "%Y-%m-%d %H:%M:%S.%f")
                message = match.group("msg")
            else:
                timestamp = None
                message = raw
            lines.append(EspLine(path, line_no, timestamp, message, raw))
    return lines


def merge_ranges(indexes: Iterable[int], radius: int, total: int) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    for index in sorted(set(indexes)):
        start = max(0, index - radius)
        end = min(total - 1, index + radius)
        if ranges and start <= ranges[-1][1] + 1:
            ranges[-1] = (ranges[-1][0], max(ranges[-1][1], end))
        else:
            ranges.append((start, end))
    return ranges


def select_esphome(lines: list[EspLine], context: int, all_info: bool) -> list[EspSelection]:
    indexes: list[int] = []
    for index, line in enumerate(lines):
        if all_info:
            if line.message.strip():
                indexes.append(index)
        elif ESP_INTEREST_RE.search(line.message):
            indexes.append(index)

    selections: list[EspSelection] = []
    for start, end in merge_ranges(indexes, context, len(lines)):
        selections.append(
            EspSelection(lines[start].source, lines[start].line_no, lines[end].line_no, tuple(lines[start : end + 1]))
        )
    return selections


def find_can_gaps(frames_by_file: dict[Path, list[CanFrame]], threshold: float) -> list[CanGap]:
    gaps: list[CanGap] = []
    for source, frames in frames_by_file.items():
        for previous, current in zip(frames, frames[1:]):
            seconds = (current.timestamp - previous.timestamp).total_seconds()
            if seconds >= threshold:
                gaps.append(CanGap(source, previous, current, seconds))
    return sorted(gaps, key=lambda gap: gap.seconds, reverse=True)


def format_frame(frame: CanFrame) -> str:
    return (
        f"{frame.timestamp:%Y-%m-%d %H:%M:%S.%f}"[:-3]
        + f"  #{frame.number:<7} {frame.direction:<11} {frame.frame_id:<12} "
        + f"DLC={frame.data_length}  {frame.data_hex}"
    )


def timestamped_selected_events(selections: list[EspSelection]) -> list[EspLine]:
    events: list[EspLine] = []
    seen: set[tuple[Path, int]] = set()
    for selection in selections:
        for line in selection.lines:
            key = (line.source, line.line_no)
            if key in seen or line.timestamp is None:
                continue
            if ESP_INTEREST_RE.search(line.message):
                events.append(line)
                seen.add(key)
    return sorted(events, key=lambda line: line.timestamp or dt.datetime.min)


def correlate_can(
    events: list[EspLine],
    all_frames: list[CanFrame],
    window_seconds: float,
    max_frames: int,
) -> list[tuple[EspLine, list[CanFrame]]]:
    if not events or not all_frames or max_frames <= 0:
        return []

    delta = dt.timedelta(seconds=window_seconds)
    remaining = max_frames
    result: list[tuple[EspLine, list[CanFrame]]] = []

    for event in events:
        assert event.timestamp is not None
        nearby = [
            frame
            for frame in all_frames
            if event.timestamp - delta <= frame.timestamp <= event.timestamp + delta
        ]
        if not nearby:
            continue
        if len(nearby) > remaining:
            nearby = nearby[:remaining]
        result.append((event, nearby))
        remaining -= len(nearby)
        if remaining <= 0:
            break
    return result


def write_report(
    output: Path,
    can_files: list[Path],
    esp_files: list[Path],
    frames_by_file: dict[Path, list[CanFrame]],
    rejected_by_file: dict[Path, list[str]],
    esp_lines_by_file: dict[Path, list[EspLine]],
    selections: list[EspSelection],
    gaps: list[CanGap],
    correlated: list[tuple[EspLine, list[CanFrame]]],
    args: argparse.Namespace,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    all_frames = [frame for frames in frames_by_file.values() for frame in frames]
    id_counts = collections.Counter(frame.frame_id for frame in all_frames)
    direction_counts = collections.Counter(frame.direction for frame in all_frames)
    timestamped_esp = sum(
        1 for lines in esp_lines_by_file.values() for line in lines if line.timestamp is not None
    )
    total_esp = sum(len(lines) for lines in esp_lines_by_file.values())

    with output.open("w", encoding="utf-8", newline="\n") as out:
        out.write("# R4875G1 CAN / ESPHome analysis bundle\n\n")
        out.write(f"Generated: {dt.datetime.now():%Y-%m-%d %H:%M:%S}\n\n")
        out.write("## Prompt for ChatGPT\n\n")
        out.write(
            "Analyze the following preselected evidence from the R4875G1 three-phase charger. "
            "Focus on CAN communication loss/recovery, lifecycle transitions (OFFLINE/DISCOVERING/ONLINE), "
            "discovery behavior, watchdog timing, TWAI/BUS_OFF symptoms, unit-specific differences, "
            "and whether CAN traffic supports or contradicts the ESPHome log. Build a chronological explanation. "
            "Separate directly observed facts from hypotheses. Pay special attention to silence gaps, repeated or missing "
            "frame IDs, the first/last frames around failures and reconnects, and Unit 1/2/3 asymmetries. "
            "If evidence is insufficient, state exactly which raw interval or additional logging would be needed. "
            "Do not assume that an ESPHome OFFLINE state proves the physical CAN bus itself was down.\n\n"
        )

        out.write("## Source inventory\n\n")
        out.write("### USB-CAN autosave files\n\n")
        if not can_files:
            out.write("No matching USB-CAN files found.\n\n")
        for path in can_files:
            frames = frames_by_file[path]
            rejected = rejected_by_file[path]
            if frames:
                span = f"{frames[0].timestamp:%Y-%m-%d %H:%M:%S.%f}"[:-3] + " → " + f"{frames[-1].timestamp:%Y-%m-%d %H:%M:%S.%f}"[:-3]
            else:
                span = "no parsed frames"
            out.write(
                f"- `{path.name}`: {len(frames):,} frames, {len(rejected):,} rejected rows, {span}\n"
            )
        out.write("\n### ESPHome files\n\n")
        if not esp_files:
            out.write("No matching ESPHome files found.\n\n")
        for path in esp_files:
            lines = esp_lines_by_file[path]
            stamped = sum(1 for line in lines if line.timestamp is not None)
            out.write(f"- `{path.name}`: {len(lines):,} lines, {stamped:,} with absolute timestamps\n")

        out.write("\n## CAN summary\n\n")
        out.write(f"Total parsed CAN frames: **{len(all_frames):,}**\n\n")
        if direction_counts:
            out.write("Directions: " + ", ".join(f"{k}={v:,}" for k, v in direction_counts.items()) + "\n\n")
        out.write("Most frequent CAN IDs:\n\n")
        out.write("| CAN ID | Frames |\n|---|---:|\n")
        for frame_id, count in id_counts.most_common(30):
            out.write(f"| `{frame_id}` | {count:,} |\n")

        out.write(f"\n## CAN silence gaps ≥ {args.gap_threshold:.3f} s\n\n")
        if not gaps:
            out.write("No gaps above the configured threshold were found.\n\n")
        else:
            for gap in gaps[: args.max_gaps]:
                out.write(f"### {gap.seconds:.3f} s — `{gap.source.name}`\n\n")
                out.write("```text\n")
                out.write(format_frame(gap.previous) + "\n")
                out.write(f"--- SILENCE {gap.seconds:.3f} s ---\n")
                out.write(format_frame(gap.current) + "\n")
                out.write("```\n\n")

        out.write("## Selected ESPHome evidence\n\n")
        if total_esp and timestamped_esp == 0:
            out.write(
                "> **Correlation limitation:** these ESPHome logs contain no absolute per-line timestamps. "
                "They can be analyzed by sequence, but cannot be aligned reliably to USB-CAN frames by wall clock. "
                "New captures made with the updated `capture-log.ps1` include local timestamps.\n\n"
            )
        if not selections:
            out.write("No lines matched the ESPHome preselection criteria.\n\n")
        for selection in selections:
            out.write(
                f"### `{selection.source.name}` lines {selection.start_line}–{selection.end_line}\n\n```text\n"
            )
            for line in selection.lines:
                out.write(line.raw + "\n")
            out.write("```\n\n")

        out.write(f"## CAN windows around timestamped ESPHome events (±{args.can_window:.3f} s)\n\n")
        if not correlated:
            out.write(
                "No timestamp-correlated windows could be produced. This is expected for older ESPHome captures without local timestamps.\n\n"
            )
        for event, frames in correlated:
            assert event.timestamp is not None
            out.write(
                f"### {event.timestamp:%Y-%m-%d %H:%M:%S.%f}"[:-3]
                + f" — `{event.source.name}:{event.line_no}`\n\n"
            )
            out.write("ESPHome:\n\n```text\n" + event.raw + "\n```\n\nCAN:\n\n```text\n")
            for frame in frames:
                out.write(format_frame(frame) + "\n")
            out.write("```\n\n")

        out.write("## Parser notes\n\n")
        out.write(
            "- USB-CAN timestamps use the calendar date from the autosave filename and the time-of-day from each row.\n"
            "- A >12 h backwards time jump in one CAN file is treated as crossing midnight.\n"
            "- ESPHome absolute timestamps are local workstation receive times added by `capture-log.ps1`; they are suitable for practical correlation but include normal network/processing latency.\n"
            "- Source logs are never modified.\n"
            f"- CAN correlation output is capped at {args.max_can_frames} frames to keep the analysis bundle compact.\n"
        )


def main() -> int:
    args = parse_args()
    repo_root = repo_root_from_script()
    logs_dir = (args.logs_dir or (repo_root / "logs")).resolve()

    if not logs_dir.is_dir():
        print(f"Log directory does not exist: {logs_dir}", file=sys.stderr)
        return 2

    can_files = sorted(
        (path for path in logs_dir.iterdir() if path.is_file() and CAN_FILE_RE.match(path.name)),
        key=lambda path: parse_file_start(path.name, CAN_FILE_RE) or dt.datetime.min,
    )
    esp_files = sorted(
        (path for path in logs_dir.iterdir() if path.is_file() and ESP_FILE_RE.match(path.name)),
        key=lambda path: parse_file_start(path.name, ESP_FILE_RE) or dt.datetime.min,
    )

    frames_by_file: dict[Path, list[CanFrame]] = {}
    rejected_by_file: dict[Path, list[str]] = {}
    for path in can_files:
        frames, rejected = parse_can_file(path)
        frames_by_file[path] = frames
        rejected_by_file[path] = rejected

    esp_lines_by_file = {path: parse_esphome_file(path) for path in esp_files}
    selections: list[EspSelection] = []
    for lines in esp_lines_by_file.values():
        selections.extend(select_esphome(lines, args.context, args.all_esp_info))

    gaps = find_can_gaps(frames_by_file, args.gap_threshold)
    events = timestamped_selected_events(selections)
    all_frames = sorted(
        (frame for frames in frames_by_file.values() for frame in frames),
        key=lambda frame: frame.timestamp,
    )
    correlated = correlate_can(events, all_frames, args.can_window, args.max_can_frames)

    output = args.output
    if output is None:
        output = logs_dir / f"can-analysis-{dt.datetime.now():%Y%m%d-%H%M%S}.md"
    elif not output.is_absolute():
        output = (Path.cwd() / output).resolve()

    write_report(
        output,
        can_files,
        esp_files,
        frames_by_file,
        rejected_by_file,
        esp_lines_by_file,
        selections,
        gaps,
        correlated,
        args,
    )

    print("R4875G1 CAN/ESPHome analysis bundle created")
    print(f"  USB-CAN files : {len(can_files)}")
    print(f"  ESPHome files : {len(esp_files)}")
    print(f"  CAN frames    : {sum(len(v) for v in frames_by_file.values()):,}")
    print(f"  CAN gaps      : {len(gaps):,} >= {args.gap_threshold:.3f} s")
    print(f"  ESP sections  : {len(selections):,}")
    print(f"  Output        : {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
