# Plugin Runtime

AcMind loads executable plugins from `~/Library/Application Support/AcMind/Plugins/<plugin-id>`.
The directory name and the manifest `id` must match. A disk plugin supports `customASR` and
`customPolish`, separately or together. Unsupported capabilities fail during loading instead of
being shown as active.

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
closes standard input, and reads one JSON object from standard output. The process must return
exit status zero. Responses larger than 1 MiB are rejected.

Activation request:

```json
{"protocolVersion":1,"action":"activate"}
```

Polish request:

```json
{"protocolVersion":1,"action":"polish","text":"input","mode":"light"}
```

ASR request:

```json
{"protocolVersion":1,"action":"transcribe","audioPath":"/path/to/audio.wav","sampleRate":16000,"channels":1}
```

Deactivation request:

```json
{"protocolVersion":1,"action":"deactivate"}
```

A successful lifecycle response is `{"success":true}`. Polish and ASR responses also contain
the result, for example `{"success":true,"text":"output"}`. ASR calls may run for up to five
minutes; other calls must finish within 15 seconds. Return a non-zero exit status or
`{"success":false,"error":"reason"}` to report a failure.

Valid polish modes are `raw`, `light`, `structured`, `aiPrompt`, `formal`, and `none`.

The executable runs as a child process with its working directory set to the plugin directory.
Process isolation protects the AcMind address space, but it is not an operating-system security
sandbox. Only install plugins you trust.
