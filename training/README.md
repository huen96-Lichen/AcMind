# acmind-trainer contract

AcMind 主应用只通过文件契约对接训练仓。训练仓不驻留在 Electron 主进程里。

## Required commands

```bash
acmind-trainer snapshot validate <manifest>
acmind-trainer train sft <manifest> --base-model <model>
acmind-trainer eval <run-or-artifact> <eval-manifest>
acmind-trainer package ollama <artifact>
```

## Snapshot layout

```text
snapshot/
  manifest.json
  train.jsonl
  eval.jsonl
  assets/
```

## Manifest fields

- `id`
- `name`
- `description`
- `splitConfig`
- `counts`
- `status`
- `createdAt`

## Example schema

Each JSONL row should contain:

- `exampleId`
- `capability`
- `input`
- `teacherOutput`
- `targetOutput`
- `metadata`

## Result files

The training job should emit:

- `run.json`
- `metrics.json`
- `artifact.json`
- `Modelfile`

## Import back into AcMind

Use the `trainingRuns.importResult` IPC entry to register:

- `training_runs`
- `eval_runs`
- `model_versions`

The main app treats `candidate` models as activatable only after evaluation and smoke testing.
