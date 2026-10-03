# Home Assistant Integration Architecture

## Status

Concept document only. No implementation code is defined by this document.

This document describes the intended long-term Home Assistant architecture for the R4875G1 three-phase charger project. It is deliberately separated from implementation so the integration boundary, data contract, frontend structure, distribution model and compatibility rules can be agreed before development starts.

## 1. Goal

The Home Assistant implementation should provide a charger dashboard that is visually and behaviorally close to the existing V6 touchscreen HMI while remaining a native Home Assistant extension.

The desired user experience is:

1. Install the R4875G1 Charger Home Assistant integration and dashboard frontend.
2. Add the integration through the Home Assistant UI.
3. Select one compatible Charger Controller instance.
4. Let the integration discover and validate the charger entities automatically.
5. Add an R4875G1 Charger dashboard.
6. The dashboard strategy automatically creates the complete charger dashboard for the selected charger instance.

The user should not need to configure individual sensor, number, button or binary-sensor entity IDs.

The implementation must support more than one charger instance. One configured Home Assistant integration entry represents one Charger Controller instance.

## 2. Architectural Position

The Home Assistant dashboard is an additional convenience HMI. It is not a replacement for the Charger Controller and it is not part of the charger safety or blackstart path.

The existing authority model remains unchanged:

```text
                         Charger Controller
                                |
             +------------------+------------------+
             |                  |                  |
             v                  v                  v
        Local LVGL HMI     Backup Encoder      Home Assistant
                                                     |
                                      +--------------+--------------+
                                      |                             |
                                      v                             v
                                 Remote HMI               HA Charger Dashboard
```

The Charger Controller remains authoritative for:

- CAN communication
- rectifier lifecycle
- capability detection
- thermal protection
- current limiting
- START eligibility
- charger START/STOP execution
- charger setpoints
- resulting charger state

The Home Assistant integration and dashboard must never reproduce these safety decisions.

A Home Assistant control action expresses operator intent and forwards that intent to the existing authoritative Charger Controller entities.

If Home Assistant, the frontend, the custom integration or the network is unavailable, the Charger Controller must continue operating independently.

## 3. Proposed Home Assistant Architecture

The Home Assistant solution consists of three coordinated layers:

```text
                    R4875G1 Home Assistant Solution
                                  |
             +--------------------+--------------------+
             |                    |                    |
             v                    v                    v
       Custom Integration   Dashboard Strategy    Custom Cards
          Python backend       dashboard factory    frontend UI
             |                    |                    |
             +--------------------+--------------------+
                                  |
                                  v
                        Charger Instance Model
                                  |
                                  v
                      Home Assistant registries
                                  |
                                  v
                  Existing ESPHome charger entities
```

### 3.1 Custom Integration

The custom integration is the backend adapter between a selected Charger Controller device and the frontend.

Its main responsibilities are:

- configuration through a Home Assistant config flow
- selection of one Charger Controller device
- validation that the selected device is a compatible charger
- discovery of the charger's entities
- mapping physical Home Assistant entities to stable semantic charger roles
- compatibility checking
- feature/capability reporting
- diagnostics
- providing the resolved charger-instance descriptor to the frontend
- reacting to entity-registry changes and entity renames
- supporting reconfiguration if the underlying Charger Controller device is replaced

The integration should not duplicate charger telemetry as a second set of Home Assistant entities unless a future requirement clearly justifies it.

The existing ESPHome entities remain the source of charger state.

### 3.2 Dashboard Strategy

The dashboard strategy creates the complete charger dashboard from one charger-instance reference.

The strategy should not contain installation-specific entity IDs.

Conceptually, its configuration contains only the selected R4875G1 Charger integration entry or charger-instance identifier.

The strategy generates the dashboard structure automatically and uses the custom frontend cards for the page content.

The strategy should register itself as a Home Assistant community dashboard so it can appear in the normal dashboard creation dialog on Home Assistant versions that support community dashboard registration.

### 3.3 Custom Cards

Custom cards render the actual charger UI.

The frontend should use reusable charger-specific web components rather than assembling the HMI from a large number of unrelated built-in Home Assistant cards.

This gives us control over:

- geometry
- typography
- state presentation
- dialogs
- status colors
- responsive behavior
- page navigation
- command-pending presentation
- invalid/unavailable states
- visual consistency with the physical HMI

The cards consume the semantic charger-instance descriptor rather than hard-coded entity IDs.

## 4. Recommended Dashboard Structure

The Home Assistant dashboard should preserve the functional structure of the V6 HMI:

```text
Dashboard
Rectifiers
Battery
System
Cooling
Trends
```

The Rectifiers page keeps the current hierarchical Rectifier Detail behavior.

### 4.1 Home Assistant Views

The preferred design is one Home Assistant view per main HMI page.

Each view is generated by the dashboard strategy and contains one full-width charger page card.

Example conceptual structure:

```text
HA Dashboard
|
+-- Dashboard view
|   `-- R4875G1 Dashboard page card
|
+-- Rectifiers view
|   `-- R4875G1 Rectifiers page card
|
+-- Battery view
|   `-- R4875G1 Battery page card
|
+-- System view
|   `-- R4875G1 System page card
|
+-- Cooling view
|   `-- R4875G1 Cooling page card
|
`-- Trends view
    `-- R4875G1 Trends page card
```

Using real Home Assistant views has several advantages over implementing the complete HMI as one opaque mini-application:

- every page has a stable URL
- browser back/forward navigation remains useful
- deep links are possible
- the dashboard remains recognizable as a Home Assistant dashboard
- page loading can remain modular
- individual page cards can also be reused elsewhere

The charger cards may still render the same persistent header and bottom navigation used by the physical HMI.

Navigation actions should change the Home Assistant view rather than maintaining an unrelated internal page router.

## 5. Frontend Component Model

The frontend should have a small number of public Home Assistant cards and a larger set of internal reusable components.

### 5.1 Public Cards

Initial public cards should correspond to complete HMI pages:

- Charger Dashboard
- Rectifiers
- Battery
- System
- Cooling
- Trends

A Rectifier Detail card may be public if useful, but the primary Rectifiers page can initially own the detail subview just as the physical HMI does.

### 5.2 Internal Components

Shared internal components should include concepts such as:

- charger page shell
- persistent header
- bottom navigation
- metric tile
- status badge
- overview card
- rectifier card
- battery card
- command button
- setpoint field
- modal dialog
- pending-command overlay
- unavailable-data state
- trend chart
- connection/status indicator

These components form a frontend design system for the charger.

The intent is not to share LVGL source code with Home Assistant. The two HMIs use different rendering technologies.

The shared asset is the information architecture and semantic UI model, not the rendering implementation.

## 6. Visual Design Strategy

The physical V6 HMI remains the visual reference.

The Home Assistant implementation should preserve:

- page hierarchy
- card grouping
- information density
- semantic colors
- status wording
- setpoint dialogs
- START/STOP dialogs
- rectifier detail organization
- major typography hierarchy
- the persistent header
- the six-page navigation model

The browser implementation should not attempt strict pixel-for-pixel rendering on every screen size.

Instead, it should define the physical 800 x 480 HMI as the reference layout and support responsive adaptations.

### 6.1 Reference Layout

The 800 x 480 display layout should be reproducible closely on a browser viewport with a similar aspect ratio.

This is important for:

- visual consistency
- documentation screenshots
- wall-mounted tablets
- side-by-side comparison with the physical HMI

### 6.2 Responsive Layout

The same frontend should also behave well on:

- desktop browsers
- tablets
- Home Assistant mobile applications
- narrow phone screens

Desktop and tablet layouts can preserve the multi-column HMI structure.

Narrow layouts may stack cards vertically while keeping the same semantic grouping.

### 6.3 Styling Boundary

The charger frontend should primarily use its own stable CSS component styles and charger-specific CSS variables.

Home Assistant theme variables may be consumed for basic integration with the surrounding application, but the implementation should avoid depending heavily on undocumented internal Home Assistant DOM structures or internal frontend components.

The charger UI should remain recognizable after normal Home Assistant frontend updates.

## 7. Charger Instance Model

The central architectural concept is the Charger Instance.

A Charger Instance is not another physical device. It is the integration's resolved semantic view of one existing Charger Controller device.

Conceptually it contains:

```text
Charger Instance
|
+-- identity
|   +-- integration entry
|   +-- Home Assistant device
|   +-- friendly name
|   +-- ESPHome identity
|   +-- firmware version
|   `-- charger interface/contract version
|
+-- compatibility
|   +-- compatible / degraded / incompatible
|   +-- missing required roles
|   `-- optional feature availability
|
+-- charger-wide telemetry
|
+-- charger-wide controls
|
+-- rectifier 1
|
+-- rectifier 2
|
+-- rectifier 3
|
+-- cooling
|
+-- system diagnostics
|
+-- optional external data sources
|   `-- battery bank
|
`-- frontend capabilities
```

The dashboard strategy and cards should reference the Charger Instance, not individual entity IDs.

## 8. Semantic Entity Contract

The custom integration needs a stable semantic contract between firmware and Home Assistant.

Examples of semantic roles are:

```text
charger.ac.power
charger.ac.voltage
charger.ac.current
charger.ac.current_limit

charger.dc.power
charger.dc.voltage
charger.dc.current
charger.dc.voltage_setpoint
charger.dc.sum_power_setpoint

charger.available_units
charger.running_units
charger.highest_output_temperature
charger.conversion_efficiency

charger.command.start
charger.command.stop

rectifier.1.lifecycle
rectifier.1.power_state
rectifier.1.can_connected
rectifier.1.ac.voltage
rectifier.1.dc.voltage
rectifier.1.temperature.output
rectifier.1.fan.rpm

cooling.compartment.temperature
cooling.compartment.humidity
cooling.fan.1.rpm
cooling.fan.2.rpm
cooling.fan.3.rpm

system.controller_battery.voltage
system.controller_battery.soc
```

The exact list should be defined later in a dedicated `ENTITY_CONTRACT.md`.

### 8.1 Why Semantic Roles Matter

The frontend should not know that a value currently happens to be represented by an entity named:

```text
sensor.some_prefix_combined_dc_power_all_units
```

It should request:

```text
charger.dc.power
```

The custom integration resolves that semantic role to the actual Home Assistant entity.

This isolates the frontend from:

- user-renamed entity IDs
- different charger device names
- installation-specific entity prefixes
- future entity naming cleanup
- multiple charger instances

## 9. Entity Discovery and Rename Safety

The config flow should ask the user to select a Charger Controller device, not an entity prefix.

The integration then inspects entities associated with that Home Assistant device.

The current Remote HMI prefix mapping is useful as a semantic inventory, but the new Home Assistant integration should not make the prefix the primary identity mechanism.

### 9.1 Initial Resolution

For the first implementation, entity discovery can use a combination of:

- selected Home Assistant device
- ESPHome integration ownership
- known domains
- known original entity names
- known stable unique identities
- expected charger entity combinations

The discovery process should reject ambiguous mappings rather than guessing silently.

### 9.2 After Initial Resolution

Once a role is resolved, the integration should track the entity through Home Assistant's entity registry rather than relying on the current editable entity ID.

If the user renames:

```text
sensor.charger_combined_dc_power_all_units
```

to:

```text
sensor.garage_charger_power
```

the Charger Instance should remain valid.

### 9.3 Recommended Future Firmware Anchor

A future small firmware enhancement should provide an explicit Home Assistant-facing charger interface identifier or contract version.

This could be a diagnostic entity or equivalent stable metadata that allows the integration to identify compatible Charger Controller devices without heuristics.

The interface version should describe the Home Assistant entity contract, not the complete firmware feature version.

Example concept:

```text
Firmware version:          6.2.0
HA charger contract:       1
```

A firmware update can then change from 6.2.0 to 6.3.0 without forcing a Home Assistant integration change if contract version 1 remains compatible.

## 10. Configuration Flow

The intended setup flow is:

```text
Settings
  -> Devices & services
  -> Add integration
  -> R4875G1 Charger
  -> Select Charger Controller
  -> Validate
  -> Create Charger Instance
```

### 10.1 Candidate Filtering

The device selector should preferably show only likely compatible Charger Controller devices.

Detection can use:

- ESPHome device ownership
- project metadata when available
- the future charger contract identifier
- presence of a minimum required entity set

### 10.2 Validation Result

The integration should classify the selected device as:

- Compatible
- Compatible with optional features missing
- Unsupported firmware/interface version
- Invalid Charger Controller selection

A missing safety-critical control mapping must not be silently substituted.

### 10.3 Reconfiguration

An options/reconfigure flow should support:

- replacing the underlying Charger Controller device
- re-running entity discovery
- resolving changed optional sources
- reviewing missing roles
- changing optional dashboard features

The generated dashboard should not need to be rebuilt manually after reconfiguration.

## 11. Multiple Charger Instances

Multiple chargers should be supported from the beginning.

Each config entry represents exactly one Charger Instance.

Example:

```text
R4875G1 Charger
|
+-- Garage Charger
|
`-- Workshop Charger
```

Each dashboard strategy instance references one Charger Instance.

This avoids a later architectural change if another charger is added.

## 12. Command Handling

The Home Assistant frontend must remain a command requester, not a charger controller.

### 12.1 Standard Command Path

The normal path is:

```text
Custom Card
   |
   v
Home Assistant action/service call
   |
   v
Existing ESPHome button/number entity
   |
   v
Charger Controller authoritative control path
   |
   v
CAN / safety / lifecycle logic
```

The custom integration may resolve which entity represents a semantic command, but it should not reproduce charger eligibility or safety rules.

### 12.2 No Optimistic Operational State

When the user requests START:

1. the UI may show that a request is pending
2. the UI sends the command through Home Assistant
3. the UI waits for authoritative Charger Controller state
4. only returned charger state determines whether the charger is shown as running

This mirrors the current Remote HMI authority model.

### 12.3 Connection Loss

If the Charger Controller entity set is unavailable:

- charger commands must be disabled
- unavailable state must be visible
- stale telemetry must not be rendered as healthy live data
- unavailable numeric values must not silently become zero

The Home Assistant dashboard is not an offline blackstart interface.

The direct Controller HMI and backup encoder retain that role.

## 13. Backend-to-Frontend Interface

The custom integration and frontend should communicate through a small explicit internal interface.

The frontend needs to obtain, at minimum:

- available Charger Instances
- selected instance identity
- display name
- compatibility state
- firmware version
- charger contract version
- semantic-role to entity mapping
- optional feature flags
- missing-role diagnostics

A small Home Assistant WebSocket API is the preferred conceptual boundary because it allows the frontend to request the resolved instance description without encoding integration internals into dashboard YAML.

The frontend should not read the integration's private Python storage directly.

The exact WebSocket commands and payload schema should be specified before implementation.

## 14. Required and Optional Capabilities

Not every future charger firmware version needs to expose exactly the same optional data.

The entity contract should classify roles.

### 14.1 Required Roles

Required roles are needed for a valid core Charger Instance.

Examples:

- charger availability
- main AC/DC telemetry
- active charger setpoints
- available/running unit counts
- charger START/STOP targets
- rectifier lifecycle and power state

If required roles are missing, setup should fail or the instance should be explicitly incompatible.

### 14.2 Optional Roles

Optional roles can enable or disable sections of the dashboard.

Examples may include:

- external cooling telemetry
- controller backup-battery monitoring
- detailed rectifier fan data
- extended diagnostics
- optional battery-bank context

The dashboard strategy can hide, disable or mark optional sections unavailable according to the capability descriptor.

## 15. Battery Page and External Home Assistant Data

The Battery page requires special treatment because the current physical HMI imports battery-bank data from other Home Assistant entities. Those source entities do not inherently belong to the Charger Controller device.

This creates an architectural difference between charger-native data and installation context.

### 15.1 Design Principle

The Home Assistant dashboard should read existing Home Assistant battery entities directly rather than routing those values through the Charger Controller merely to display them again in Home Assistant.

This avoids:

```text
Home Assistant battery source
        -> Charger Controller
        -> Home Assistant
        -> Charger dashboard
```

when the dashboard can instead use:

```text
Home Assistant battery source
        -> Charger dashboard
```

### 15.2 Desired User Experience

The long-term target remains one charger selection with automatic discovery whenever possible.

The integration should therefore support a secondary-source resolver that can:

1. discover known battery-bank source entities automatically when unambiguous
2. associate them with the Charger Instance
3. prompt only if discovery is ambiguous or incomplete

This keeps the common setup simple without hard-coding one installation's entity IDs into the frontend.

### 15.3 Fallback

If no battery source is configured or discoverable:

- the core charger dashboard remains valid
- the Battery page clearly reports that the optional source is not configured
- charger control remains unaffected

Battery source selection belongs to integration configuration, not individual dashboard-card configuration.

## 16. Cooling Page

Cooling data is charger-side data and should normally be discovered from the selected Charger Controller device.

The dashboard should preserve the distinction between:

- external chassis cooling
- internal rectifier fans

Cooling commands, if exposed, should use the same existing Home Assistant entities already owned by the Charger Controller.

The dashboard must not infer safety state from fan RPM alone.

## 17. System Page

The Home Assistant System page should distinguish two kinds of data:

### Charger Controller diagnostics

Examples:

- uptime
- Wi-Fi status
- ESPHome version
- controller battery
- local runtime information

### Charger operational state

Examples:

- rectifier lifecycle
- CAN connectivity
- charger firmware version
- integration/contract compatibility

The Home Assistant browser's own device diagnostics should not be confused with Charger Controller diagnostics.

## 18. Trends

The browser dashboard does not need to reproduce the Controller's in-memory 60-minute ring buffers internally.

Home Assistant already has persistent state history.

The preferred frontend approach is:

- request the required recent history/statistics from Home Assistant
- use the same five logical trend series as the physical HMI
- initially display the same 60-minute window
- preserve unavailable gaps rather than forcing zero
- use responsive browser-native chart rendering

This gives the Home Assistant dashboard an advantage over the physical HMI: trend data can survive frontend reloads and may later support selectable time ranges.

The visual default should still match the physical HMI closely.

## 19. Dialogs and Editing

Setpoint and power dialogs should visually follow the physical HMI.

The frontend should provide dedicated modal components for:

- AC current limit
- DC voltage and nominal sum power
- fallback voltage/current
- charger START
- charger STOP
- per-rectifier START/STOP
- rectifier detail commands where applicable

The modal owns presentation and input validation appropriate to the frontend.

The Charger Controller remains authoritative for operational acceptance.

The frontend should use the same configured ranges exposed by the entity where possible rather than duplicating numeric limits in JavaScript.

## 20. Availability Model

The Home Assistant frontend should have a consistent availability model.

Suggested instance states:

```text
OK
DEGRADED
OFFLINE
INCOMPATIBLE
```

### OK

All required roles are resolved and their current source data is available.

### DEGRADED

The core charger is usable but one or more optional capabilities are unavailable.

### OFFLINE

The Charger Controller is configured but authoritative entities are unavailable.

### INCOMPATIBLE

The selected device or firmware contract cannot satisfy the required semantic interface.

Cards should consume this instance-level state consistently instead of implementing independent ad-hoc availability rules.

## 21. Compatibility and Versioning

Three independent version concepts should exist.

### Firmware Version

Example:

```text
6.2.0
```

Owned by the charger firmware repository.

### Home Assistant Integration Version

Owned by the backend integration repository.

### Home Assistant Frontend Version

Owned by the dashboard/frontend repository.

### Charger Contract Version

Defines compatibility between firmware and the Home Assistant solution.

This contract should change only when the semantic Home Assistant interface changes incompatibly.

A compatibility matrix can then state, for example:

```text
HA contract 1
  compatible firmware: 6.2.x and later versions that retain contract 1
  backend integration: >= 1.x
  frontend: >= 1.x
```

The frontend should not compare firmware versions to guess entity availability when an explicit capability or contract version can answer the question.

## 22. Diagnostics

The custom integration should provide useful diagnostics without exposing secrets.

Diagnostics should include:

- configured Charger Instance
- selected Home Assistant device ID
- detected firmware version
- detected charger contract version
- resolved semantic roles
- missing required roles
- missing optional roles
- feature flags
- integration version
- compatibility result

The diagnostics should not include authentication credentials or unrelated Home Assistant state.

## 23. Testing Strategy

The Home Assistant solution needs its own validation layers.

### Backend Integration Tests

Cover:

- config flow
- candidate discovery
- duplicate prevention
- entity-role mapping
- renamed entity handling
- missing required entities
- optional entity handling
- reconfiguration
- compatibility checks

### Frontend Tests

Cover:

- semantic state rendering
- unavailable states
- dialog behavior
- responsive layout
- navigation
- command pending state
- multiple Charger Instances
- no accidental hard-coded installation entity IDs

### Integration Acceptance Tests

Cover at least:

- one complete Charger Controller
- renamed Home Assistant entities
- Charger Controller temporarily offline
- Home Assistant restart
- frontend/browser reload
- optional battery source missing
- optional battery source present
- multiple dashboard sessions
- multiple charger instances when available

No Home Assistant test replaces the existing physical firmware safety and blackstart validation.

## 24. Repository and Distribution Strategy

### 24.1 Recommendation

The Home Assistant architecture documentation should live in the existing charger repository because the entity contract and HMI semantics are part of the overall product architecture.

The production Home Assistant implementation should eventually be distributed from dedicated Home Assistant repositories.

This separation gives us both:

- one canonical project architecture
- clean Home Assistant/HACS packaging

### 24.2 Existing Charger Repository

Recommended structure:

```text
esphome-r4875g1-3phase-charger/
|
+-- HomeAssistant/
|   +-- ARCHITECTURE.md
|   +-- ENTITY_CONTRACT.md        future
|   +-- UI_SPEC.md                future
|   `-- TEST_PLAN.md              future
|
+-- packages/
+-- KiCAD/
+-- FreeCAD/
`-- ...
```

`HomeAssistant/ARCHITECTURE.md` is the conceptual document.

`ENTITY_CONTRACT.md` should become the authoritative semantic contract between ESPHome firmware and the Home Assistant integration.

`UI_SPEC.md` should describe page layouts, dialogs, visual semantics and responsive behavior without duplicating backend mapping details.

`TEST_PLAN.md` should define release acceptance for the Home Assistant solution.

No production Home Assistant runtime code needs to be added to this repository initially.

### 24.3 Backend Integration Repository

Recommended future repository:

```text
homeassistant-r4875g1-charger
```

Its purpose is the Home Assistant custom integration.

HACS-compatible integration repositories expect the integration below a root-level `custom_components/<domain>/` directory.

The backend repository should therefore be structured for Home Assistant rather than nested under the ESPHome firmware repository.

### 24.4 Frontend Repository

Recommended future repository:

```text
r4875g1-charger-dashboard
```

Its purpose is the dashboard strategy and custom cards.

HACS dashboard/plugin repositories have a different packaging model from custom integrations and normally publish JavaScript from a root-level or `dist/` location.

Keeping the frontend distribution separate avoids mixing two HACS repository types.

### 24.5 Why Not Put Production Code Under `HomeAssistant/` in the Existing Repository?

A nested `HomeAssistant/` source tree would be convenient for development, but it creates unnecessary distribution friction:

- HACS custom integrations expect a root-level `custom_components/<domain>/` structure
- HACS dashboard plugins expect their distributable JavaScript at the repository root or in `dist/`
- backend and frontend have different toolchains
- backend and frontend may need independent releases
- firmware releases should not automatically imply Home Assistant frontend releases
- Home Assistant code will eventually need its own tests and CI

Therefore:

```text
Existing repo
    owns architecture and firmware contract

Backend repo
    owns Home Assistant integration

Frontend repo
    owns dashboard strategy and custom cards
```

This is the preferred long-term structure.

A single-repository Home Assistant implementation can still be reconsidered later if distribution requirements change, but it should not be the baseline architecture.

## 25. Development Sequence

The recommended implementation order is deliberately contract-first.

### Phase 1 — Contract Definition

Create `ENTITY_CONTRACT.md`.

Define:

- required semantic roles
- optional semantic roles
- supported commands
- device identity/discovery anchor
- contract version
- availability semantics

No frontend work should begin before the core role names are stable.

### Phase 2 — Backend Integration Prototype

Create the Home Assistant custom integration.

Implement:

- config flow
- Charger Controller device selection
- entity discovery
- semantic mapping
- compatibility status
- frontend instance descriptor
- diagnostics

Do not create the full visual dashboard yet.

### Phase 3 — Frontend Design System

Create the frontend project.

Implement reusable visual components:

- shell
- header
- metric tiles
- status badges
- dialogs
- navigation
- unavailable state

Use static mock data only in isolated frontend development tests, never in production runtime.

### Phase 4 — Dashboard Page Cards

Implement the six page cards against the semantic instance descriptor.

Start with:

1. Dashboard
2. Rectifiers
3. System
4. Cooling
5. Battery
6. Trends

This order validates the most important charger-native data before optional external context and historical charting.

### Phase 5 — Dashboard Strategy

Generate the full dashboard automatically from one Charger Instance.

Add graphical strategy configuration and community-dashboard registration.

### Phase 6 — Secondary Source Discovery

Add battery-bank discovery/configuration.

Keep it optional and separate from the charger-native entity contract.

### Phase 7 — Distribution

Prepare:

- backend HACS integration repository
- frontend HACS dashboard repository
- release notes
- installation documentation
- compatibility matrix
- CI validation

## 26. Architectural Invariants

The following rules should be treated as non-negotiable unless the architecture is explicitly revised:

1. The Charger Controller remains authoritative for charger operation and safety.
2. Home Assistant must not become a dependency of local charger operation or blackstart.
3. The Home Assistant frontend must not implement independent START eligibility.
4. The dashboard must not hard-code one installation's entity prefix.
5. One Charger Instance must be configurable without manually entering every entity.
6. Entity renaming in Home Assistant should not break a configured Charger Instance.
7. Shared semantic roles are the boundary between backend discovery and frontend rendering.
8. Missing data must remain distinguishable from a valid zero value.
9. The Remote HMI and Home Assistant dashboard should share the same charger semantics even though their implementations are independent.
10. Optional external context such as the solar battery bank must not become a charger safety dependency.
11. Multiple charger instances must be possible without architectural redesign.
12. Firmware, backend, frontend and contract versions remain separate concepts.
13. Home Assistant frontend implementation must not depend unnecessarily on undocumented Home Assistant DOM internals.
14. The physical V6 HMI remains the visual and behavioral reference, but the browser implementation may adapt responsively.
15. Production Home Assistant backend and frontend distribution should remain independent from firmware release packaging.

## 27. Open Design Questions

The following questions should be resolved before implementation:

1. What exact firmware metadata or diagnostic entity should identify the charger contract version?
2. Which current ESPHome entities are mandatory for contract version 1?
3. Which current ESPHome entities are optional?
4. Should the integration resolve entities initially by original name, stable unique identity, or a dedicated future firmware key?
5. What is the exact backend-to-frontend WebSocket descriptor schema?
6. Should the dashboard allow hiding complete pages through integration options?
7. How should automatic battery-bank discovery work across installations?
8. Should the Home Assistant dashboard reproduce the physical HMI colors exactly or allow an optional Home Assistant theme-adaptive mode?
9. Should the Rectifier Detail screen remain an internal subview or become a dedicated Home Assistant view?
10. Which controls should be exposed on the Home Assistant System and Cooling pages?
11. How should pending command timeouts be presented if Home Assistant delivers the request but no authoritative state transition follows?
12. What minimum Home Assistant version should the first supported release require?

## 28. Current Recommendation

Proceed with the following repository decision now:

```text
Current charger repository
    HomeAssistant/ARCHITECTURE.md
```

Keep this document with the firmware because it defines how the Home Assistant product relates to the Charger Controller contract.

Do not add production Python or TypeScript/JavaScript implementation under `HomeAssistant/` yet.

Before creating implementation repositories, create `HomeAssistant/ENTITY_CONTRACT.md` and define contract version 1 from the current V6.2.0 Home Assistant-facing entities.

Once that contract is stable, create dedicated backend and frontend repositories with distribution-oriented layouts.

This gives the project a clean separation between:

```text
firmware authority
Home Assistant semantic contract
backend discovery/configuration
frontend presentation
distribution packaging
```

and preserves the same architectural discipline already used by the V6 Charger Controller and Remote HMI.
