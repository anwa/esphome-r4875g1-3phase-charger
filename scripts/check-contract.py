"""Check the Controller entity contract against every consumer.

The Charger Controller's Home Assistant entities are consumed by:

- the Home Assistant integration (role specifications: domain + original name)
- the Grafana history dashboard (InfluxDB entity IDs: ${instance}_<object_id>)
- the Remote HMI firmware (entity IDs: <domain>.${ha_charger_entity_prefix}_<object_id>)
- the dashboard card (semantic roles defined by the integration)

The Controller entity inventory is taken from the fully resolved ESPHome
configuration (`esphome config`), so packages and substitutions are expanded
exactly as in a real build.

Run from the repository root with the project virtual environment:

    .venv/Scripts/python.exe scripts/check-contract.py

The sibling repositories are expected next to this repository. Missing sibling
repositories are reported and their checks are skipped.
"""

from __future__ import annotations

import argparse
import importlib.util
import re
import subprocess
import sys
import types
import unicodedata
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parent.parent
CONTROLLER_CONFIG = "r4875g1-3phase-charger.yaml"
CONTRACT_PACKAGE = REPO_ROOT / "packages" / "controller" / "ha-contract.yaml"
REMOTE_HMI_ENTITY_MAP = REPO_ROOT / "packages" / "remote-hmi" / "ha-entity-map.yaml"

# ESPHome entity components and the Home Assistant domain they create.
ENTITY_DOMAINS = {
    "sensor": "sensor",
    "binary_sensor": "binary_sensor",
    "text_sensor": "sensor",
    "button": "button",
    "number": "number",
    "switch": "switch",
    "select": "select",
    "text": "text",
    "event": "event",
    "update": "update",
    "lock": "lock",
    "fan": "fan",
    "light": "light",
    "cover": "cover",
    "valve": "valve",
    "climate": "climate",
    "datetime": "datetime",
}

ROLE_PREFIXES = ("charger", "cooling", "controller", "metadata", "rectifier")

# Grafana object IDs provided by Home Assistant template helpers instead of the
# Controller. They are documented in the dashboard repository's
# grafana/README.md and are reported as external rather than missing.
GRAFANA_EXTERNAL_OBJECT_IDS = re.compile(r"rectifier_alarm_status_word_history_unit_[1-3]")


@dataclass(frozen=True)
class Entity:
    domain: str
    name: str

    @property
    def object_id(self) -> str:
        return slugify(self.name)


class Report:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.warnings: list[str] = []

    def section(self, title: str) -> None:
        print(f"\n== {title}")

    def ok(self, message: str) -> None:
        print(f"[  OK  ] {message}")

    def error(self, message: str) -> None:
        self.errors.append(message)
        print(f"[ FAIL ] {message}")

    def warn(self, message: str) -> None:
        self.warnings.append(message)
        print(f"[ WARN ] {message}")


def slugify(text: str) -> str:
    """Approximate the Home Assistant object-ID slug of an entity name."""
    normalized = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "_", normalized.lower()).strip("_")


class _TolerantLoader(yaml.SafeLoader):
    """YAML loader that keeps the value of ESPHome-specific tags."""


def _construct_tagged(loader: yaml.SafeLoader, _suffix: str, node: yaml.Node) -> object:
    if isinstance(node, yaml.ScalarNode):
        return loader.construct_scalar(node)
    if isinstance(node, yaml.SequenceNode):
        return loader.construct_sequence(node, deep=True)
    return loader.construct_mapping(node, deep=True)


_TolerantLoader.add_multi_constructor("!", _construct_tagged)


def load_controller_entities() -> list[Entity]:
    result = subprocess.run(
        [sys.executable, "-m", "esphome", "config", CONTROLLER_CONFIG],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    if result.returncode != 0:
        print(result.stderr, file=sys.stderr)
        raise SystemExit(f"esphome config failed for {CONTROLLER_CONFIG}")

    config = yaml.load(result.stdout, Loader=_TolerantLoader)
    entities: list[Entity] = []

    for component, domain in ENTITY_DOMAINS.items():
        for item in config.get(component) or []:
            if not isinstance(item, dict):
                continue
            # The item itself and platform sub-entities such as a sensor
            # platform's temperature/humidity children.
            candidates = [item] + [v for v in item.values() if isinstance(v, dict)]
            for candidate in candidates:
                name = candidate.get("name")
                if not name or candidate.get("internal") is True:
                    continue
                entities.append(Entity(domain, str(name)))

    return entities


def load_integration_module(integration_root: Path, name: str) -> types.ModuleType:
    """Import one integration module without executing the package __init__."""
    package_dir = integration_root / "custom_components" / "r4875g1_charger"
    package_name = "r4875g1_charger_contract_check"

    if package_name not in sys.modules:
        package = types.ModuleType(package_name)
        package.__path__ = [str(package_dir)]
        sys.modules[package_name] = package

    full_name = f"{package_name}.{name}"
    if full_name in sys.modules:
        return sys.modules[full_name]

    spec = importlib.util.spec_from_file_location(full_name, package_dir / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[full_name] = module
    spec.loader.exec_module(module)
    return module


def check_controller_uniqueness(report: Report, entities: list[Entity]) -> None:
    report.section("Controller entity inventory")
    report.ok(f"{len(entities)} exposed Controller entities")

    duplicates = [k for k, n in Counter((e.domain, e.name) for e in entities).items() if n > 1]
    for domain, name in duplicates:
        report.error(f"duplicate Controller entity {domain} '{name}' makes role resolution ambiguous")

    slugs = Counter((e.domain, e.object_id) for e in entities)
    for (domain, object_id), n in slugs.items():
        if n > 1:
            report.error(f"duplicate Controller entity ID {domain}.<prefix>_{object_id}")

    if not duplicates:
        report.ok("entity names are unique per domain")


def check_contract_marker(report: Report, integration_root: Path) -> None:
    report.section("Contract version marker")
    match = re.search(r'return\s*\{\s*"([^"]+)"\s*\}', CONTRACT_PACKAGE.read_text(encoding="utf-8"))
    if not match:
        report.error(f"no contract version found in {CONTRACT_PACKAGE.relative_to(REPO_ROOT)}")
        return

    published = match.group(1)
    const = load_integration_module(integration_root, "const")
    supported = set(const.SUPPORTED_CONTRACT_VERSIONS)

    if published in supported:
        report.ok(f"Controller publishes contract '{published}', integration supports {sorted(supported)}")
    else:
        report.error(f"Controller publishes contract '{published}', integration supports only {sorted(supported)}")


def check_integration_roles(report: Report, entities: list[Entity], integration_root: Path) -> set[str]:
    report.section("Integration role specifications")
    role_specs = load_integration_module(integration_root, "role_specs")
    specs = role_specs.CONTRACT_ROLE_SPECS
    available = {(e.domain, e.name) for e in entities}

    missing = [s for s in specs if (s.domain, s.original_name) not in available]
    for spec in missing:
        by_name = sorted(e.domain for e in entities if e.name == spec.original_name)
        hint = f" (exists as {', '.join(by_name)})" if by_name else ""
        level = report.error if spec.required else report.warn
        level(f"role {spec.role}: no Controller {spec.domain} named '{spec.original_name}'{hint}")

    report.ok(f"{len(specs) - len(missing)}/{len(specs)} roles resolve to a Controller entity")
    return {s.role for s in specs}


def check_grafana(report: Report, entities: list[Entity], dashboard_root: Path) -> None:
    report.section("Grafana history dashboard")
    object_ids = {e.object_id for e in entities}
    dashboards = sorted((dashboard_root / "grafana" / "dashboards").glob("*.json"))

    for path in dashboards:
        text = path.read_text(encoding="utf-8")
        referenced = set(re.findall(r"\$\{instance\}_([a-z0-9_]+)", text))
        # Instance discovery uses an anchored entity-ID suffix regex.
        referenced |= set(re.findall(r"=~ /_([a-z0-9_]+)\$/", text))

        external = sorted(r for r in referenced if GRAFANA_EXTERNAL_OBJECT_IDS.fullmatch(r))
        controller = referenced - set(external)
        missing = sorted(r for r in controller if r not in object_ids)
        for object_id in missing:
            report.error(f"{path.name}: no Controller entity with object ID '{object_id}'")
        report.ok(f"{path.name}: {len(controller) - len(missing)}/{len(controller)} Controller entity IDs exist")
        if external:
            report.ok(f"{path.name}: {len(external)} documented Home Assistant helper entity IDs not checked")


def check_remote_hmi(report: Report, entities: list[Entity]) -> None:
    report.section("Remote HMI entity map")
    available = {(e.domain, e.object_id) for e in entities}
    text = REMOTE_HMI_ENTITY_MAP.read_text(encoding="utf-8")
    referenced = set(re.findall(r'"([a-z_]+)\.\$\{ha_charger_entity_prefix\}_([a-z0-9_]+)"', text))

    missing = sorted(r for r in referenced if r not in available)
    for domain, object_id in missing:
        report.error(f"no Controller entity {domain}.<prefix>_{object_id}")
    report.ok(f"{len(referenced) - len(missing)}/{len(referenced)} entity IDs exist")


def check_dashboard_roles(report: Report, roles: set[str], dashboard_root: Path) -> None:
    report.section("Dashboard card semantic roles")
    referenced: set[str] = set()
    prefixes = "|".join(ROLE_PREFIXES)

    for path in sorted((dashboard_root / "src").rglob("*.ts")):
        text = path.read_text(encoding="utf-8")
        referenced |= set(re.findall(rf'["\']((?:{prefixes})\.[a-z0-9_.]+)["\']', text))

        # Per-unit templates such as `rectifier.${unit}.command.start`.
        for tail in re.findall(r"`rectifier\.\$\{unit\}\.([a-z0-9_.]+)`", text):
            referenced |= {f"rectifier.{unit}.{tail}" for unit in (1, 2, 3)}

        # Templates with a variable suffix use suffix literals from the same file.
        if "${suffix}" in text:
            for suffix in re.findall(r'suffix:\s*"([a-z0-9_.]+)"', text):
                for unit in (1, 2, 3):
                    candidates = {f"rectifier.{unit}.{suffix}", f"rectifier.{unit}.alarm.{suffix}"}
                    if not candidates & roles:
                        referenced.add(f"rectifier.{unit}.{suffix}")

    missing = sorted(r for r in referenced if r not in roles)
    for role in missing:
        report.error(f"dashboard references unknown role '{role}'")
    report.ok(f"{len(referenced) - len(missing)}/{len(referenced)} referenced roles exist")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--integration", type=Path, default=REPO_ROOT.parent / "homeassistant-r4875g1-charger")
    parser.add_argument("--dashboard", type=Path, default=REPO_ROOT.parent / "r4875g1-charger-dashboard")
    args = parser.parse_args()

    report = Report()
    print("R4875G1 Charger - Cross-Repository Contract Check")

    entities = load_controller_entities()
    check_controller_uniqueness(report, entities)
    check_remote_hmi(report, entities)

    roles: set[str] = set()
    if args.integration.is_dir():
        check_contract_marker(report, args.integration)
        roles = check_integration_roles(report, entities, args.integration)
    else:
        report.warn(f"integration repository not found at {args.integration}; skipping integration checks")

    if args.dashboard.is_dir():
        check_grafana(report, entities, args.dashboard)
        if roles:
            check_dashboard_roles(report, roles, args.dashboard)
    else:
        report.warn(f"dashboard repository not found at {args.dashboard}; skipping dashboard checks")

    print()
    if report.errors:
        print(f"[ FAIL ] {len(report.errors)} error(s), {len(report.warnings)} warning(s)")
        return 1
    print(f"[  OK  ] contract consistent, {len(report.warnings)} warning(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
