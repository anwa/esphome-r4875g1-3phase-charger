# YAML Comment Style Guide

This rule defines the required comment style for all YAML files in this repository.

The primary audience is AI coding agents, but comments must remain concise, readable and useful for human maintainers.

The goal is a consistent hierarchy of comments without unnecessary noise.

---

## Normative Language

The keywords MUST, MUST NOT, SHOULD, SHOULD NOT and MAY describe the strength of a rule.

- MUST / MUST NOT: required
- SHOULD / SHOULD NOT: preferred unless there is a concrete reason to deviate
- MAY: optional

## General Principles

All YAML comments MUST be written in English.

This applies even when the development conversation or user instructions are in another language.

Comments MUST describe the current implementation.

Comments SHOULD explain:

- the purpose of a component or configuration block
- important architectural relationships
- non-obvious behavior
- safety-related behavior
- protocol details
- hardware connections
- timing or state-machine behavior
- reasons for unusual implementation choices

Comments SHOULD NOT merely repeat what the YAML key or code already states.

Avoid comments such as:

```yaml
# Set the value to 10.
value: 10
```

Prefer comments that explain why the value matters:

```yaml
# Allow cyclic telemetry to resume before connectivity is evaluated again.
property_poll_resume_grace_ms: "2000"
```

Comments MUST describe the current codebase, not its development history.

Do not leave comments such as:

```yaml
# Added in v5.0.9.
# Temporary implementation.
# Will be implemented later.
# Part 2 of the migration.
```

unless the historical information is genuinely required to understand the current implementation.

Comments that become incorrect after a code change MUST be updated in the same change.

---

# Comment Hierarchy

Three comment levels are used:

1. Section
2. Minor Section
3. Simple Line Comment

Do not introduce additional separator styles.

---

## 1. Section

Sections divide a file into major functional areas.

Use exactly this separator:

```text
# ==============================================================================
```

Section titles MUST use uppercase text.

Example without description:

```yaml
# ==============================================================================
# CAN BUS
# ==============================================================================

canbus:
```

There MUST be one empty line before and after a complete Section block.

If the Section is at the beginning of a file, no leading empty line is required.

---

### Section With Description

A description is optional.

If a description is present, insert one comment-only blank line after the title separator:

```yaml
# ==============================================================================
# USB / CAN MODE SELECTION
# ==============================================================================
#
# CH422G EXIO5 selects the onboard transceiver routing required for CAN mode.
# ==============================================================================

switch:
```

For longer descriptions:

```yaml
# ==============================================================================
# CONTROLLER BACKUP BATTERY
# ==============================================================================
#
# A 1S lithium battery is connected to the Waveshare J3 battery connector.
#
# Battery voltage is measured through the onboard 200 kΩ / 100 kΩ divider
# connected from TP1 to J8 AD / GPIO6.
#
# The resulting voltage-based SOC value is intended for monitoring only.
# ==============================================================================

sensor:
```

The final Section separator MUST be present when a descriptive block is used.

There MUST be one empty line after it before the YAML content begins.

---

## 2. Minor Section

Minor Sections divide a Section into logical subsections.

Use exactly this separator:

```text
# ---------------------------------------------------------------------------
```

Minor Section titles MUST use uppercase text.

Example without description:

```yaml
  # ---------------------------------------------------------------------------
  # CONTROLLER CPU TEMPERATURE
  # ---------------------------------------------------------------------------

  - platform: internal_temperature
```

There MUST normally be one empty line before and after a complete Minor Section header.

Indent the comment block to the same YAML level as the content it describes.

---

### Minor Section With Description

A description is optional.

If present, insert one comment-only blank line after the title separator:

```yaml
  # ---------------------------------------------------------------------------
  # RECTIFIER COMPARTMENT TEMPERATURE AND HUMIDITY
  # ---------------------------------------------------------------------------
  #
  # AHT10 installed in the shared rear connection compartment behind the
  # three rectifier units.
  #
  # Connected through:
  #   main I2C -> TCA9548A channel 1 -> AHT10 @ 0x38
  # ---------------------------------------------------------------------------

  - platform: aht10
```

For descriptive Minor Sections, repeat the Minor Section separator after the description.

There MUST be one empty line between the completed comment block and the YAML content.

---

## 3. Simple Line Comments

Simple comments document a specific setting, action or nearby group of values.

They do not create an additional visual section and therefore do not require extra blank lines.

Example:

```yaml
  # ---------------------------------------------------------------------------
  # CAN COMMUNICATION TIMING
  # ---------------------------------------------------------------------------
  # Normal runtime CAN watchdog.
  can_watchdog_timeout_ms: "3000"
```

The description directly belongs to the following setting, so there is no empty line between comment and setting.

Another valid example:

```yaml
    on_press:
      then:
        - logger.log:
            level: INFO
            format: "Start requested for all available rectifiers."

        # Unit 1
        - if:
            condition:
              lambda: |-
                return
```

The empty line above `# Unit 1` exists because it separates YAML list actions, not because the comment itself requires spacing.

Simple comments SHOULD be short.

Use them when a Section or Minor Section would add unnecessary visual weight.

---

# Indentation

Comments inside nested YAML structures MUST use the same indentation level as the YAML element they describe.

Correct:

```yaml
sensor:
  # ---------------------------------------------------------------------------
  # CONTROLLER UPTIME
  # ---------------------------------------------------------------------------

  - platform: uptime
```

Correct:

```yaml
    on_press:
      then:
        # Only send the command after lifecycle validation succeeds.
        - canbus.send:
```

Avoid placing a comment at root indentation when it describes nested content.

---

# Description Detail

Descriptions SHOULD be detailed enough that a maintainer can understand the purpose of the block without reconstructing the entire implementation.

Prefer explaining:

```text
why
what responsibility the block has
what external hardware or protocol it interacts with
important constraints
failure or fallback behavior
```

Avoid explaining every obvious YAML property.

Bad:

```yaml
# Set the update interval to 5 seconds.
update_interval: 5s
```

Better:

```yaml
# Five-second sampling is sufficient for the slowly changing backup battery.
update_interval: 5s
```

---

# Keep Comments Close to Their Code

A comment MUST appear immediately before the code it describes whenever possible.

Bad:

```yaml
- id: last_can_rx_1
  type: uint32_t

# Timestamp of the last valid CAN frame.
- id: rectifier_state_1
```

The comment visually appears to describe the wrong variable.

Correct:

```yaml
# Timestamp of the most recent valid CAN activity from Unit 1.
- id: last_can_rx_1
  type: uint32_t

# Current lifecycle state of Unit 1.
- id: rectifier_state_1
```

---

# Avoid Orphaned Comments

Do not leave descriptive blocks without corresponding code.

For example, a comment describing an encoder implementation MUST NOT remain in a `sensor:` or `binary_sensor:` section if no encoder entity follows it.

Move the comment to the actual implementation or remove it.

---

# Avoid Duplicate Comments

Do not keep both a detailed explanation and an older condensed version.

Bad:

```yaml
# Automatic cooling stage:
#   0 = OFF
#   1 = 35 %
#   2 = 45 %
#   3 = 60 %
#   4 = 80 %
#   5 = 100 %
# 0=OFF, 1=35%, 2=45%, 3=60%, 4=80%, 5=100%.
```

Correct:

```yaml
# Automatic cooling stage:
#   0 = OFF
#   1 = 35 %
#   2 = 45 %
#   3 = 60 %
#   4 = 80 %
#   5 = 100 %
```

---

# Avoid Redundant Separators

Do not append an additional separator after a normal description unless the block is intentionally using the documented descriptive Section or Minor Section format.

Bad:

```yaml
  # ---------------------------------------------------------------------------
  # EFFECTIVE DC CURRENT LIMIT
  # ---------------------------------------------------------------------------
  # Runtime hardware/capability ceiling shared by all active-current paths.
  # --------------------------------------------------------------------------
  - platform: template
```

Use either the compact form:

```yaml
  # ---------------------------------------------------------------------------
  # EFFECTIVE DC CURRENT LIMIT
  # ---------------------------------------------------------------------------
  # Runtime hardware/capability ceiling shared by all active-current paths.
  - platform: template
```

or the full descriptive Minor Section form:

```yaml
  # ---------------------------------------------------------------------------
  # EFFECTIVE DC CURRENT LIMIT
  # ---------------------------------------------------------------------------
  #
  # Runtime hardware/capability ceiling shared by all active-current paths.
  # ---------------------------------------------------------------------------

  - platform: template
```

Choose the full form when the description explains the subsection as a whole.

Choose the compact form when the comment only documents the immediately following setting or entity.

---

# File Headers

Every complete YAML package SHOULD begin with a Section describing the purpose of the file.

Example:

```yaml
# ==============================================================================
# V5 CONTROLLER HARDWARE PACKAGE
# ==============================================================================
#
# Defines controller-side buses and peripherals not owned by the RGB display
# driver itself.
#
# Included hardware:
#   - shared I2C bus
#   - TCA9548A I2C multiplexer
#   - MCP23017 I/O expander
#   - controller backup-battery ADC
#   - GT911 touch controller
#   - ESP32-S3 CAN controller
# ==============================================================================
```

Small include fragments may use a shorter header, but their purpose and required substitution variables SHOULD still be documented.

---

# Terminology

Use consistent project terminology.

Examples:

```text
Rectifier
Unit 1 / Unit 2 / Unit 3
Controller
Charger
CAN
DC
AC
Backup Battery
Cooling
Dashboard
Rectifiers
System
Trends
```

Do not alternate between multiple names for the same component unless the difference is intentional.

---

# Current State Only

Comments MUST reflect the current architecture.

When code is refactored:

* update file references
* update ownership/responsibility descriptions
* remove obsolete migration comments
* remove references to old runtime locations
* remove "planned", "temporary" or "future" wording when the implementation
  already exists

Example:

Bad:

```yaml
# Live updates are handled by ui.yaml.
```

when the runtime has been moved to:

```text
display/rectifier-detail.yaml
```

The comment must be updated as part of the same refactor.

---

# Comments Inside Lambdas

Comments inside C++ lambdas follow the same general principle but do not use YAML Section separators.

Use `//` comments to explain protocol details, safety decisions, state transitions or non-obvious calculations.

Good:

```cpp
// Ignore stale telemetry so an offline rectifier cannot contribute to the
// charger-wide aggregate value.
```

Avoid comments that merely translate the next statement into English.

Bad:

```cpp
// Increment count.
count++;
```

---

# Comment-Only Cleanup Changes

When a task is explicitly a comment or documentation cleanup, AI agents MUST NOT change runtime behavior.

Do not:

* rename IDs
* change values
* reorder logic
* modify expressions
* change timing
* add or remove entities
* alter YAML structure unless required solely for comment placement

If a functional issue is discovered during a comment-only cleanup, report it separately instead of silently fixing it.

An exception is allowed only when the user explicitly approves the functional change.

---

# Required Formatting Summary

Major Section:

```yaml
# ==============================================================================
# TITLE
# ==============================================================================
#
# Optional description.
# ==============================================================================

yaml:
```

Minor Section:

```yaml
  # ---------------------------------------------------------------------------
  # TITLE
  # ---------------------------------------------------------------------------
  #
  # Optional description.
  # ---------------------------------------------------------------------------

  - yaml:
```

Minor Section without description:

```yaml
  # ---------------------------------------------------------------------------
  # TITLE
  # ---------------------------------------------------------------------------

  - yaml:
```

Simple setting comment:

```yaml
  # ---------------------------------------------------------------------------
  # TITLE
  # ---------------------------------------------------------------------------
  # Short comment describing the following setting.
  setting: value
```

Inline list/action comment:

```yaml
      - first.action:

        # Description of the following action.
        - second.action:
```

These formats SHOULD be used consistently throughout all YAML files in the repository.
