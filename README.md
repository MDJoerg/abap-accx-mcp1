# abap-accx-mcp1

*[Deutsch](#deutsch) below.*

Transport adapter of [Access Explorer (ACCX)](https://github.com/MDJoerg/abap-accx-base) for the
older [abap-ai/mcp](https://github.com/abap-ai/mcp) MCP SDK (package `ZMCP1`). ABAP package
`ZACCX_MCP1`.

The adapter is a **variant** with the same features as [abap-accx-mcp2](https://github.com/MDJoerg/abap-accx-mcp2):
tools, prompts and resources, served at `/zmcp/<area>/<server>` (registration table
`ZMCP_SERVERS`). It contains no business logic. Use it if your system runs the older SDK; both
adapters can be installed side by side.

## Install

1. Install the mcp SDK and **abap-accx-base** (package `ZACCX`).
2. Pull this repository into package `ZACCX_MCP1` with abapGit.
3. Run class `ZCL_ACCX_MCP1_SERVER` with F9 in ADT. It registers `bc/access-support` and every
   profile of table `ZACCX_PROFILE` in `ZMCP_SERVERS` and lists the visible tools.
4. Connect your MCP client to `https://<host>/zmcp/bc/access-support?sap-client=<client>`.

## Differences to the mcp2 adapter

- The SDK checks the authorization object `ZMCP_SRV` (area and server) before ACCX is reached.
  Callers need it in addition to what the ACCX profile requires; without it they get HTTP 401.
- This SDK has no elicitation. A write tool returns its plan as text and is called again with
  `plan_id` and `confirm = true` after the user approved exactly this plan.

Everything else (tools, profiles, security, user guide, architecture, how the packages fit
together) is documented in **[abap-accx-base](https://github.com/MDJoerg/abap-accx-base)**.

## Deutsch

Transport-Adapter von [Access Explorer (ACCX)](https://github.com/MDJoerg/abap-accx-base) für das
ältere MCP-SDK [abap-ai/mcp](https://github.com/abap-ai/mcp) (Paket `ZMCP1`).
ABAP-Paket `ZACCX_MCP1`.

Der Adapter ist eine **Variante** mit denselben Funktionen wie
[abap-accx-mcp2](https://github.com/MDJoerg/abap-accx-mcp2): Tools, Prompts und Ressourcen unter
`/zmcp/<area>/<server>` (Registrierungstabelle `ZMCP_SERVERS`). Er enthält keine Fachlogik.
Nutzen Sie ihn, wenn Ihr System das ältere SDK betreibt; beide Adapter können nebeneinander
installiert werden.

### Installation

1. mcp-SDK und **abap-accx-base** (Paket `ZACCX`) installieren.
2. Dieses Repository mit abapGit in das Paket `ZACCX_MCP1` ziehen.
3. Klasse `ZCL_ACCX_MCP1_SERVER` in ADT mit F9 ausführen. Sie trägt `bc/access-support` und jedes
   Profil der Tabelle `ZACCX_PROFILE` in `ZMCP_SERVERS` ein und listet die sichtbaren Tools.
4. Den MCP-Client mit `https://<host>/zmcp/bc/access-support?sap-client=<mandant>` verbinden.

### Unterschiede zum mcp2-Adapter

- Das SDK prüft das Berechtigungsobjekt `ZMCP_SRV` (Bereich und Server), bevor ACCX erreicht wird.
  Aufrufer brauchen es zusätzlich zu dem, was das ACCX-Profil verlangt; ohne es gibt es HTTP 401.
- Dieses SDK kennt keine Rückfrage an den Benutzer (Elicitation). Ein Schreibwerkzeug liefert
  den Plan als Text und wird danach mit `plan_id` und `confirm = true` erneut aufgerufen, wenn
  der Benutzer genau diesen Plan freigegeben hat.

Alles Weitere (Tools, Profile, Sicherheit, Benutzerhandbuch, Architektur, Zusammenspiel der
Pakete) steht in **[abap-accx-base](https://github.com/MDJoerg/abap-accx-base)**.
