# Plugin Runtime

AcMind loads executable plugins from `~/Library/Application Support/AcMind/Plugins/<plugin-id>`.
The directory name and the manifest `id` must match. A disk plugin currently supports the
`customPolish` capability; unsupported capabilities fail during loading instead of being shown
as active.

## Manifest

Create `plugin.json` beside the executable:

```json
{
  "id": "example-polish",
  "name": "Example Polish",
  "version": "1.0.0",
  "author": "Example",
  "description": "Example process plugin",
  "capabilities": ["customPolish"],
  "entryPoint": "plugin",
  "configPath": "plugin.json"
}
```

`entryPoint` must be an executable regular file inside the plugin directory. Symlinks that
resolve outside that directory are rejected.

## Process protocol

AcMind starts a fresh process for every operation, writes one JSON object to standard input,
closes standard input, and reads one JSON object from standard output. The process must finish
within 15 seconds and return exit status zero. Responses larger than 1 MiB are rejected.

Activation request:

```json
{"protocolVersion":1,"action":"activate"}
```

Polish request:

```json
{"protocolVersion":1,"action":"polish","text":"input","mode":"light"}
```

Deactivation request:

```json
{"protocolVersion":1,"action":"deactivate"}
```

A successful lifecycle response is `{"success":true}`. A polish response also contains the
result, for example `{"success":true,"text":"output"}`. Return a non-zero exit status or
`{"success":false,"error":"reason"}` to report a failure.

Valid polish modes are `raw`, `light`, `structured`, `aiPrompt`, `formal`, and `none`.

The executable runs as a child process with its working directory set to the plugin directory.
Process isolation protects the AcMind address space, but it is not an operating-system security
sandbox. Only install plugins you trust.
