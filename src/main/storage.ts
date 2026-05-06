import { randomUUID, createHash } from 'node:crypto';
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import Database from 'better-sqlite3';
import type {
  SourceItem,
  AiTask,
  DistilledOutput,
  ExportRecord,
  KnowledgeCard,
  KnowledgeEdge,
  ReviewEvent,
  TrainingExample,
  DatasetSnapshot,
  TrainingRun,
  EvalRun,
  ModelVersion,
  ProviderConfig,
  VaultConfig,
  StorageStats,
  SourceItemStatus,
  AiTaskStatus,
  ImportTask,
  CaptureItem,
  CaptureItemStatus,
  CaptureItemListFilter,
  AssetFile,
  ClipboardItem,
  ShelfItem,
  AIAction,
  PinItem,
  PinItemListFilter,
  SourceItemSource,
  ProcessJob,
  DistilledNote,
} from '../shared/types';
import { logger } from './logger';

// ---------------------------------------------------------------------------
// Schema definitions
// ---------------------------------------------------------------------------

const CURRENT_SCHEMA_VERSION = 21;

const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS source_items (
  id TEXT PRIMARY KEY,
  capture_item_id TEXT,
  type TEXT NOT NULL DEFAULT 'text',
  source TEXT NOT NULL DEFAULT 'manual',
  content_path TEXT NOT NULL DEFAULT '',
  content_hash TEXT,
  preview_text TEXT,
  ocr_text TEXT,
  source_app TEXT,
  original_url TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  status TEXT NOT NULL DEFAULT 'inbox',
  title TEXT,
  tags TEXT,
  vault_import_path TEXT
);

CREATE INDEX IF NOT EXISTS idx_source_items_status ON source_items(status);
CREATE INDEX IF NOT EXISTS idx_source_items_created_at ON source_items(created_at);
CREATE UNIQUE INDEX IF NOT EXISTS idx_source_items_capture_item_id ON source_items(capture_item_id) WHERE capture_item_id IS NOT NULL;

CREATE TABLE IF NOT EXISTS ai_tasks (
  id TEXT PRIMARY KEY,
  source_item_id TEXT NOT NULL,
  tier TEXT NOT NULL DEFAULT 'local_light',
  operation TEXT NOT NULL DEFAULT 'summarize',
  status TEXT NOT NULL DEFAULT 'queued',
  provider TEXT NOT NULL DEFAULT '',
  model TEXT NOT NULL DEFAULT '',
  input TEXT NOT NULL DEFAULT '{}',
  output TEXT,
  error TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  started_at INTEGER,
  finished_at INTEGER,
  latency_ms INTEGER,
  FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_ai_tasks_source_item_id ON ai_tasks(source_item_id);
CREATE INDEX IF NOT EXISTS idx_ai_tasks_status ON ai_tasks(status);

CREATE TABLE IF NOT EXISTS distilled_outputs (
  id TEXT PRIMARY KEY,
  source_item_id TEXT NOT NULL,
  task_id TEXT NOT NULL,
  operation TEXT,
  suggested_title TEXT,
  summary TEXT,
  category TEXT,
  tags TEXT,
  document_type TEXT,
  content_markdown TEXT,
  value_score REAL,
  clean_suggestion TEXT,
  confidence REAL,
  review_status TEXT NOT NULL DEFAULT 'pending',
  reviewed_at INTEGER,
  accepted_knowledge_card_id TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE CASCADE,
  FOREIGN KEY (task_id) REFERENCES ai_tasks(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_distilled_outputs_source_item_id ON distilled_outputs(source_item_id);
CREATE INDEX IF NOT EXISTS idx_distilled_outputs_review_status ON distilled_outputs(review_status);

CREATE TABLE IF NOT EXISTS knowledge_cards (
  id TEXT PRIMARY KEY,
  source_item_id TEXT NOT NULL UNIQUE,
  distilled_output_id TEXT,
  canonical_title TEXT NOT NULL DEFAULT '',
  summary TEXT,
  category TEXT,
  tags TEXT NOT NULL DEFAULT '[]',
  body TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_knowledge_cards_status ON knowledge_cards(status);
CREATE INDEX IF NOT EXISTS idx_knowledge_cards_category ON knowledge_cards(category);

CREATE TABLE IF NOT EXISTS knowledge_edges (
  id TEXT PRIMARY KEY,
  from_knowledge_card_id TEXT NOT NULL,
  to_knowledge_card_id TEXT NOT NULL,
  relation_type TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'suggested',
  confidence REAL,
  reason TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (from_knowledge_card_id) REFERENCES knowledge_cards(id) ON DELETE CASCADE,
  FOREIGN KEY (to_knowledge_card_id) REFERENCES knowledge_cards(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_knowledge_edges_from ON knowledge_edges(from_knowledge_card_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_edges_to ON knowledge_edges(to_knowledge_card_id);
CREATE INDEX IF NOT EXISTS idx_knowledge_edges_status ON knowledge_edges(status);

CREATE TABLE IF NOT EXISTS review_events (
  id TEXT PRIMARY KEY,
  source_item_id TEXT NOT NULL,
  distilled_output_id TEXT NOT NULL,
  knowledge_card_id TEXT,
  action TEXT NOT NULL,
  before TEXT NOT NULL DEFAULT '{}',
  after TEXT NOT NULL DEFAULT '{}',
  actor TEXT NOT NULL DEFAULT 'user',
  provider TEXT,
  model TEXT,
  task_id TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_review_events_source_item_id ON review_events(source_item_id);
CREATE INDEX IF NOT EXISTS idx_review_events_distilled_output_id ON review_events(distilled_output_id);

CREATE TABLE IF NOT EXISTS training_examples (
  id TEXT PRIMARY KEY,
  capability TEXT NOT NULL,
  source_item_id TEXT NOT NULL,
  distilled_output_id TEXT,
  knowledge_card_id TEXT,
  input TEXT NOT NULL DEFAULT '{}',
  teacher_output TEXT NOT NULL DEFAULT '{}',
  target_output TEXT NOT NULL DEFAULT '{}',
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_training_examples_capability ON training_examples(capability);
CREATE INDEX IF NOT EXISTS idx_training_examples_source_item_id ON training_examples(source_item_id);

CREATE TABLE IF NOT EXISTS dataset_snapshots (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  manifest_path TEXT NOT NULL DEFAULT '',
  split_config TEXT NOT NULL DEFAULT '{}',
  counts TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'draft',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  frozen_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_dataset_snapshots_status ON dataset_snapshots(status);

CREATE TABLE IF NOT EXISTS training_runs (
  id TEXT PRIMARY KEY,
  snapshot_id TEXT NOT NULL,
  base_model TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'queued',
  manifest_path TEXT,
  artifact_path TEXT,
  metrics TEXT NOT NULL DEFAULT '{}',
  error TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  finished_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_training_runs_snapshot_id ON training_runs(snapshot_id);
CREATE INDEX IF NOT EXISTS idx_training_runs_status ON training_runs(status);

CREATE TABLE IF NOT EXISTS eval_runs (
  id TEXT PRIMARY KEY,
  snapshot_id TEXT NOT NULL,
  training_run_id TEXT,
  model_version_id TEXT,
  metrics TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_eval_runs_snapshot_id ON eval_runs(snapshot_id);

CREATE TABLE IF NOT EXISTS model_versions (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  base_model TEXT NOT NULL,
  artifact_path TEXT NOT NULL DEFAULT '',
  modelfile_path TEXT,
  provider TEXT NOT NULL DEFAULT 'ollama',
  status TEXT NOT NULL DEFAULT 'candidate',
  notes TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_model_versions_status ON model_versions(status);

CREATE TABLE IF NOT EXISTS export_records (
  id TEXT PRIMARY KEY,
  source_item_id TEXT NOT NULL,
  distilled_output_id TEXT NOT NULL,
  knowledge_card_id TEXT,
  vault_path TEXT NOT NULL DEFAULT '',
  relative_file_path TEXT NOT NULL DEFAULT '',
  frontmatter TEXT NOT NULL DEFAULT '{}',
  exported_at INTEGER NOT NULL DEFAULT (unixepoch()),
  status TEXT NOT NULL DEFAULT 'success',
  conflict_resolution TEXT
);

CREATE INDEX IF NOT EXISTS idx_export_records_source_item_id ON export_records(source_item_id);

CREATE TABLE IF NOT EXISTS import_tasks (
  id TEXT PRIMARY KEY,
  vault_path TEXT NOT NULL DEFAULT '',
  folder_path TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'scanning',
  total_files INTEGER NOT NULL DEFAULT 0,
  imported_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  failed_count INTEGER NOT NULL DEFAULT 0,
  exclude_patterns TEXT NOT NULL DEFAULT '[]',
  include_patterns TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  started_at INTEGER,
  finished_at INTEGER,
  error TEXT
);

CREATE INDEX IF NOT EXISTS idx_import_tasks_status ON import_tasks(status);

CREATE TABLE IF NOT EXISTS capture_items (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL DEFAULT 'text',
  status TEXT NOT NULL DEFAULT 'pending',
  title TEXT NOT NULL DEFAULT '',
  raw_text TEXT NOT NULL DEFAULT '',
  source_url TEXT NOT NULL DEFAULT '',
  file_path TEXT NOT NULL DEFAULT '',
  user_note TEXT NOT NULL DEFAULT '',
  captured_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_capture_items_status ON capture_items(status);
CREATE INDEX IF NOT EXISTS idx_capture_items_captured_at ON capture_items(captured_at);
CREATE INDEX IF NOT EXISTS idx_capture_items_type ON capture_items(type);

CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS provider_configs (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'ollama',
  tier TEXT NOT NULL DEFAULT 'local_light',
  base_url TEXT NOT NULL DEFAULT '',
  api_key TEXT,
  model_id TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1,
  capabilities TEXT NOT NULL DEFAULT '[]'
);

CREATE TABLE IF NOT EXISTS vault_config (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  vault_path TEXT NOT NULL DEFAULT '',
  default_folder TEXT NOT NULL DEFAULT 'Inbox',
  template TEXT NOT NULL DEFAULT '',
  path_rule TEXT NOT NULL DEFAULT 'category_date',
  conflict_strategy TEXT NOT NULL DEFAULT 'rename',
  auto_frontmatter INTEGER NOT NULL DEFAULT 1,
  frontmatter_template TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS _migration (
  version INTEGER NOT NULL,
  applied_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Phase A: Agent Chat Tables
CREATE TABLE IF NOT EXISTS chat_sessions (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL DEFAULT '新对话',
  provider_id TEXT,
  model_id TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_chat_sessions_status ON chat_sessions(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS chat_messages (
  id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL REFERENCES chat_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  status TEXT NOT NULL DEFAULT 'pending',
  model_id TEXT,
  provider_id TEXT,
  prompt_tokens INTEGER,
  completion_tokens INTEGER,
  latency_ms INTEGER,
  error TEXT,
  action_proposals TEXT NOT NULL DEFAULT '[]',
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON chat_messages(session_id, created_at ASC);

-- Phase C: Agent Tasks
CREATE TABLE IF NOT EXISTS agent_tasks (
  id TEXT PRIMARY KEY,
  session_id TEXT REFERENCES chat_sessions(id),
  name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  skill_name TEXT,
  input_params TEXT NOT NULL DEFAULT '{}',
  result TEXT,
  error TEXT,
  started_at INTEGER,
  completed_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_agent_tasks_status ON agent_tasks(status, updated_at DESC);

CREATE TABLE IF NOT EXISTS agent_task_events (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES agent_tasks(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  metadata TEXT NOT NULL DEFAULT '{}',
  created_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_agent_task_events_task ON agent_task_events(task_id, created_at ASC);

-- Phase D: Scheduled Agent Tasks
CREATE TABLE IF NOT EXISTS scheduled_agent_tasks (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  cron_expression TEXT NOT NULL,
  skill_name TEXT NOT NULL,
  input_params TEXT NOT NULL DEFAULT '{}',
  enabled INTEGER NOT NULL DEFAULT 1,
  last_run_at INTEGER,
  last_run_status TEXT,
  last_run_task_id TEXT,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_scheduled_agent_tasks_enabled ON scheduled_agent_tasks(enabled, updated_at DESC);
`;

// ---------------------------------------------------------------------------
// Helper: parse JSON stored as text
// ---------------------------------------------------------------------------

function parseJson<T>(raw: string | null | undefined, fallback: T): T {
  if (!raw) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

// ---------------------------------------------------------------------------
// StorageService
// ---------------------------------------------------------------------------

class StorageService {
  private _db: Database.Database | null = null;
  private dbPathValue: string | null = null;
  private storageRoot: string | null = null;

  /** Public read-only accessor for the database instance. */
  get db(): Database.Database | null {
    return this._db;
  }

  // Prepared statements
  private stmtInsertSourceItem!: Database.Statement;
  private stmtGetSourceItem!: Database.Statement;
  private stmtGetSourceItemByCaptureItemId!: Database.Statement;
  private stmtUpdateSourceItem!: Database.Statement;
  private stmtDeleteSourceItem!: Database.Statement;
  private stmtInsertAiTask!: Database.Statement;
  private stmtUpdateAiTask!: Database.Statement;
  private stmtInsertDistilledOutput!: Database.Statement;
  private stmtUpdateDistilledOutput!: Database.Statement;
  private stmtInsertExportRecord!: Database.Statement;
  private stmtInsertKnowledgeCard!: Database.Statement;
  private stmtUpdateKnowledgeCard!: Database.Statement;
  private stmtInsertKnowledgeEdge!: Database.Statement;
  private stmtInsertReviewEvent!: Database.Statement;
  private stmtInsertTrainingExample!: Database.Statement;
  private stmtInsertDatasetSnapshot!: Database.Statement;
  private stmtUpdateDatasetSnapshot!: Database.Statement;
  private stmtInsertTrainingRun!: Database.Statement;
  private stmtUpdateTrainingRun!: Database.Statement;
  private stmtInsertEvalRun!: Database.Statement;
  private stmtInsertModelVersion!: Database.Statement;
  private stmtUpdateModelVersion!: Database.Statement;
  private stmtGetSetting!: Database.Statement;
  private stmtSetSetting!: Database.Statement;
  private stmtUpsertProviderConfig!: Database.Statement;
  private stmtDeleteProviderConfig!: Database.Statement;
  private stmtGetVaultConfig!: Database.Statement;
  private stmtInsertImportTask!: Database.Statement;
  private stmtGetImportTask!: Database.Statement;
  private stmtUpdateImportTask!: Database.Statement;
  private stmtUpdateVaultConfig!: Database.Statement;
  // Capture Inbox
  private stmtInsertCaptureItem!: Database.Statement;
  private stmtGetCaptureItem!: Database.Statement;
  private stmtUpdateCaptureItem!: Database.Statement;
  private stmtDeleteCaptureItem!: Database.Statement;
  private stmtGetKnowledgeCardBySourceItemId!: Database.Statement;

  // Phase A: Agent Chat
  private stmtInsertChatSession!: Database.Statement;
  private stmtGetChatSession!: Database.Statement;
  private stmtUpdateChatSession!: Database.Statement;
  private stmtDeleteChatSession!: Database.Statement;
  private stmtListChatSessions!: Database.Statement;
  private stmtInsertChatMessage!: Database.Statement;
  private stmtGetChatMessage!: Database.Statement;
  private stmtUpdateChatMessage!: Database.Statement;
  private stmtListChatMessages!: Database.Statement;

  // Phase C: Agent Tasks
  private stmtInsertAgentTask!: Database.Statement;
  private stmtGetAgentTask!: Database.Statement;
  private stmtUpdateAgentTask!: Database.Statement;
  private stmtDeleteAgentTask!: Database.Statement;
  private stmtListAgentTasks!: Database.Statement;
  private stmtInsertAgentTaskEvent!: Database.Statement;
  private stmtListAgentTaskEvents!: Database.Statement;

  // Phase D: Scheduled Agent Tasks
  private stmtInsertScheduledAgentTask!: Database.Statement;
  private stmtGetScheduledAgentTask!: Database.Statement;
  private stmtUpdateScheduledAgentTask!: Database.Statement;
  private stmtDeleteScheduledAgentTask!: Database.Statement;
  private stmtListScheduledAgentTasks!: Database.Statement;

  /**
   * Initialize the database: create file, run schema, apply migrations.
   */
  init(storageRoot: string): void {
    this.storageRoot = storageRoot;

    const dbPath = path.join(storageRoot, 'acmind.db');

    // Migration: rename legacy pinmind.db → acmind.db if it exists and acmind.db doesn't yet
    const legacyDbPath = path.join(storageRoot, 'pinmind.db');
    try {
      if (existsSync(legacyDbPath) && !existsSync(dbPath)) {
        renameSync(legacyDbPath, dbPath);
        logger.info('app', 'storage', 'migrate-db', 'Renamed legacy pinmind.db → acmind.db');
      }
    } catch (err) {
      logger.warn('app', 'storage', 'migrate-db', 'Failed to rename legacy DB, will create new', {
        error: err instanceof Error ? err.message : String(err),
      });
    }

    this.dbPathValue = dbPath;

    this._db = new Database(dbPath);
    this._db.pragma('journal_mode = WAL');
    this._db.pragma('foreign_keys = ON');

    this.runMigrations();
    this.prepareStatements();
    this.seedFeaturedToolProjects();

    logger.info('app', 'storage', 'init', 'Storage initialized', {
      dbPath,
      schemaVersion: CURRENT_SCHEMA_VERSION,
    });
  }

  isInitialized(): boolean {
    return this._db !== null;
  }

  /**
   * Run schema migrations based on _migration table.
   */
  private runMigrations(): void {
    const db = this._db!;

    db.exec(`
      CREATE TABLE IF NOT EXISTS _migration (
        version INTEGER NOT NULL,
        applied_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    `);

    const row = db.prepare('SELECT version FROM _migration ORDER BY version DESC LIMIT 1').get() as
      | { version: number }
      | undefined;
    const currentVersion = row?.version ?? 0;

    if (currentVersion < CURRENT_SCHEMA_VERSION) {
      const migrate = db.transaction(() => {
        if (currentVersion < 1) {
          db.exec(SCHEMA_SQL);
        }
        if (currentVersion < 2) {
          // Phase 6: External Import
          db.exec(`
            CREATE TABLE IF NOT EXISTS import_tasks (
              id TEXT PRIMARY KEY,
              vault_path TEXT NOT NULL DEFAULT '',
              folder_path TEXT NOT NULL DEFAULT '',
              status TEXT NOT NULL DEFAULT 'scanning',
              total_files INTEGER NOT NULL DEFAULT 0,
              imported_count INTEGER NOT NULL DEFAULT 0,
              skipped_count INTEGER NOT NULL DEFAULT 0,
              failed_count INTEGER NOT NULL DEFAULT 0,
              exclude_patterns TEXT NOT NULL DEFAULT '[]',
              include_patterns TEXT NOT NULL DEFAULT '[]',
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              started_at INTEGER,
              finished_at INTEGER,
              error TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_import_tasks_status ON import_tasks(status);
            CREATE INDEX IF NOT EXISTS idx_import_tasks_created_at ON import_tasks(created_at);
          `);
          // Add new columns to source_items for vault import
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN title TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN tags TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN vault_import_path TEXT`);
          } catch {
            // Column may already exist, ignore
          }
        }
        if (currentVersion < 3) {
          // Capture Inbox v0.1
          db.exec(`
            CREATE TABLE IF NOT EXISTS capture_items (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL DEFAULT 'text',
              status TEXT NOT NULL DEFAULT 'pending',
              title TEXT NOT NULL DEFAULT '',
              raw_text TEXT NOT NULL DEFAULT '',
              source_url TEXT NOT NULL DEFAULT '',
              file_path TEXT NOT NULL DEFAULT '',
              user_note TEXT NOT NULL DEFAULT '',
              captured_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_capture_items_status ON capture_items(status);
            CREATE INDEX IF NOT EXISTS idx_capture_items_captured_at ON capture_items(captured_at);
            CREATE INDEX IF NOT EXISTS idx_capture_items_type ON capture_items(type);
          `);
        }
        if (currentVersion < 4) {
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN capture_item_id TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN review_status TEXT NOT NULL DEFAULT 'pending'`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN reviewed_at INTEGER`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN accepted_knowledge_card_id TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          db.exec(`
            CREATE TABLE IF NOT EXISTS knowledge_cards (
              id TEXT PRIMARY KEY,
              source_item_id TEXT NOT NULL UNIQUE,
              distilled_output_id TEXT,
              canonical_title TEXT NOT NULL DEFAULT '',
              summary TEXT,
              category TEXT,
              tags TEXT NOT NULL DEFAULT '[]',
              body TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_knowledge_cards_status ON knowledge_cards(status);
            CREATE INDEX IF NOT EXISTS idx_knowledge_cards_category ON knowledge_cards(category);
            CREATE TABLE IF NOT EXISTS knowledge_edges (
              id TEXT PRIMARY KEY,
              from_knowledge_card_id TEXT NOT NULL,
              to_knowledge_card_id TEXT NOT NULL,
              relation_type TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'suggested',
              confidence REAL,
              reason TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_knowledge_edges_from ON knowledge_edges(from_knowledge_card_id);
            CREATE INDEX IF NOT EXISTS idx_knowledge_edges_to ON knowledge_edges(to_knowledge_card_id);
            CREATE INDEX IF NOT EXISTS idx_knowledge_edges_status ON knowledge_edges(status);
            CREATE TABLE IF NOT EXISTS review_events (
              id TEXT PRIMARY KEY,
              source_item_id TEXT NOT NULL,
              distilled_output_id TEXT NOT NULL,
              knowledge_card_id TEXT,
              action TEXT NOT NULL,
              before TEXT NOT NULL DEFAULT '{}',
              after TEXT NOT NULL DEFAULT '{}',
              actor TEXT NOT NULL DEFAULT 'user',
              provider TEXT,
              model TEXT,
              task_id TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_review_events_source_item_id ON review_events(source_item_id);
            CREATE INDEX IF NOT EXISTS idx_review_events_distilled_output_id ON review_events(distilled_output_id);
            CREATE TABLE IF NOT EXISTS training_examples (
              id TEXT PRIMARY KEY,
              capability TEXT NOT NULL,
              source_item_id TEXT NOT NULL,
              distilled_output_id TEXT,
              knowledge_card_id TEXT,
              input TEXT NOT NULL DEFAULT '{}',
              teacher_output TEXT NOT NULL DEFAULT '{}',
              target_output TEXT NOT NULL DEFAULT '{}',
              metadata TEXT NOT NULL DEFAULT '{}',
              created_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_training_examples_capability ON training_examples(capability);
            CREATE INDEX IF NOT EXISTS idx_training_examples_source_item_id ON training_examples(source_item_id);
            CREATE TABLE IF NOT EXISTS dataset_snapshots (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              manifest_path TEXT NOT NULL DEFAULT '',
              split_config TEXT NOT NULL DEFAULT '{}',
              counts TEXT NOT NULL DEFAULT '{}',
              status TEXT NOT NULL DEFAULT 'draft',
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              frozen_at INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_dataset_snapshots_status ON dataset_snapshots(status);
            CREATE TABLE IF NOT EXISTS training_runs (
              id TEXT PRIMARY KEY,
              snapshot_id TEXT NOT NULL,
              base_model TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'queued',
              manifest_path TEXT,
              artifact_path TEXT,
              metrics TEXT NOT NULL DEFAULT '{}',
              error TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              finished_at INTEGER
            );
            CREATE INDEX IF NOT EXISTS idx_training_runs_snapshot_id ON training_runs(snapshot_id);
            CREATE INDEX IF NOT EXISTS idx_training_runs_status ON training_runs(status);
            CREATE TABLE IF NOT EXISTS eval_runs (
              id TEXT PRIMARY KEY,
              snapshot_id TEXT NOT NULL,
              training_run_id TEXT,
              model_version_id TEXT,
              metrics TEXT NOT NULL DEFAULT '{}',
              created_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_eval_runs_snapshot_id ON eval_runs(snapshot_id);
            CREATE TABLE IF NOT EXISTS model_versions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              base_model TEXT NOT NULL,
              artifact_path TEXT NOT NULL DEFAULT '',
              modelfile_path TEXT,
              provider TEXT NOT NULL DEFAULT 'ollama',
              status TEXT NOT NULL DEFAULT 'candidate',
              notes TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_model_versions_status ON model_versions(status);
          `);
        }
        if (currentVersion < 5) {
          // Distill Loop v5: Add export_records index for lineage queries
          try {
            db.exec(`CREATE INDEX IF NOT EXISTS idx_export_records_distilled_output_id ON export_records(distilled_output_id)`);
          } catch {
            // Index may already exist, ignore
          }
          try {
            db.exec(`CREATE INDEX IF NOT EXISTS idx_export_records_status ON export_records(status)`);
          } catch {
            // Index may already exist, ignore
          }
        }
        if (currentVersion < 6) {
          // Add operation column to distilled_outputs for direct operation lookup
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN operation TEXT`);
          } catch {
            // Column may already exist, ignore
          }
        }
        if (currentVersion < 7) {
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN document_type TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`ALTER TABLE distilled_outputs ADD COLUMN content_markdown TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            // Phase 1: 不再硬编码开发者路径，保持用户已设置的 vault_path 不变
            // db.exec(`UPDATE vault_config SET vault_path = '/Users/lichen/Library/Mobile Documents/iCloud~md~obsidian/Documents', default_folder = '' WHERE id = 1`);
          } catch {
            // Vault config may not exist yet, ignore
          }
        }
        if (currentVersion < 8) {
          // Phase 1: export_records 加 error 列，用于前端展示失败原因
          try {
            db.exec(`ALTER TABLE export_records ADD COLUMN error TEXT`);
          } catch {
            // Column may already exist, ignore
          }
        }
        if (currentVersion < 9) {
          this.ensureAiTasksUpdatedAtColumn(db);
        }
        if (currentVersion < 10) {
          // V2.1 Phase 2: Add original_id to source_items for dedup
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN original_id TEXT`);
          } catch {
            // Column may already exist, ignore
          }
          try {
            db.exec(`CREATE INDEX IF NOT EXISTS idx_source_items_original_id ON source_items(original_id)`);
          } catch {
            // Index may already exist, ignore
          }
          // V2.1 Phase 2: Add content_state_history table for state tracking
          db.exec(`
            CREATE TABLE IF NOT EXISTS content_state_history (
              id TEXT PRIMARY KEY,
              source_item_id TEXT NOT NULL,
              from_state TEXT NOT NULL,
              to_state TEXT NOT NULL,
              actor TEXT NOT NULL DEFAULT 'system',
              reason TEXT,
              error TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS idx_content_state_history_source_item_id ON content_state_history(source_item_id);
            CREATE INDEX IF NOT EXISTS idx_content_state_history_created_at ON content_state_history(created_at);
          `);
        }
        if (currentVersion < 11) {
          // V2.1 Phase 6.1: Add error_records table for unified error model
          db.exec(`
            CREATE TABLE IF NOT EXISTS error_records (
              error_id TEXT PRIMARY KEY,
              error_type TEXT NOT NULL,
              original_id TEXT,
              output_id TEXT,
              stage TEXT NOT NULL DEFAULT '',
              message TEXT NOT NULL,
              user_message TEXT NOT NULL,
              raw_error TEXT,
              retryable INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              resolved_at INTEGER,
              status TEXT NOT NULL DEFAULT 'open'
            );
            CREATE INDEX IF NOT EXISTS idx_error_records_status ON error_records(status);
            CREATE INDEX IF NOT EXISTS idx_error_records_error_type ON error_records(error_type);
            CREATE INDEX IF NOT EXISTS idx_error_records_original_id ON error_records(original_id);
            CREATE INDEX IF NOT EXISTS idx_error_records_created_at ON error_records(created_at);
          `);
        }
        if (currentVersion < 12) {
          // V2.1 Phase 6.3: Add retry_count to error_records
          try {
            db.exec(`ALTER TABLE error_records ADD COLUMN retry_count INTEGER NOT NULL DEFAULT 0`);
          } catch {
            // Column may already exist, ignore
          }
        }
        if (currentVersion < 13) {
          // V2.1 Phase 8: Add metadata column to source_items for model call records
          try {
            db.exec(`ALTER TABLE source_items ADD COLUMN metadata TEXT`);
          } catch {
            // Column may already exist, ignore
          }
        }
        if (currentVersion < 14) {
          // Phase 0: AcMind 统一数据模型 — 新增 4 张表
          db.exec(`
            CREATE TABLE IF NOT EXISTS asset_files (
              id TEXT PRIMARY KEY,
              source_item_id TEXT,
              kind TEXT NOT NULL DEFAULT 'other',
              original_name TEXT,
              local_path TEXT NOT NULL DEFAULT '',
              mime_type TEXT,
              size_bytes INTEGER,
              sha256 TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              metadata TEXT,
              FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE SET NULL
            );
            CREATE INDEX IF NOT EXISTS idx_asset_files_source_item_id ON asset_files(source_item_id);
            CREATE INDEX IF NOT EXISTS idx_asset_files_kind ON asset_files(kind);

            CREATE TABLE IF NOT EXISTS clipboard_items (
              id TEXT PRIMARY KEY,
              source_item_id TEXT,
              content_type TEXT NOT NULL DEFAULT 'text',
              text TEXT,
              asset_file_ids TEXT,
              source_app TEXT,
              is_sensitive INTEGER NOT NULL DEFAULT 0,
              is_pinned INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE SET NULL
            );
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_created_at ON clipboard_items(created_at);
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_content_type ON clipboard_items(content_type);
            CREATE INDEX IF NOT EXISTS idx_clipboard_items_is_pinned ON clipboard_items(is_pinned);

            CREATE TABLE IF NOT EXISTS shelf_items (
              id TEXT PRIMARY KEY,
              source_item_id TEXT,
              asset_file_ids TEXT NOT NULL DEFAULT '[]',
              label TEXT,
              origin TEXT,
              status TEXT NOT NULL DEFAULT 'temporary',
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
              FOREIGN KEY (source_item_id) REFERENCES source_items(id) ON DELETE SET NULL
            );
            CREATE INDEX IF NOT EXISTS idx_shelf_items_status ON shelf_items(status);
            CREATE INDEX IF NOT EXISTS idx_shelf_items_created_at ON shelf_items(created_at);

            CREATE TABLE IF NOT EXISTS ai_actions (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL DEFAULT '',
              input_types TEXT NOT NULL DEFAULT '[]',
              action_type TEXT NOT NULL DEFAULT 'custom',
              prompt_profile_id TEXT,
              enabled INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_ai_actions_enabled ON ai_actions(enabled);

            CREATE TABLE IF NOT EXISTS pin_pool_items (
              id TEXT PRIMARY KEY,
              capture_item_id TEXT NOT NULL DEFAULT '',
              original_id TEXT NOT NULL DEFAULT '',
              source_type TEXT NOT NULL DEFAULT 'clipboard_text',
              title TEXT NOT NULL DEFAULT '',
              preview_text TEXT,
              raw_text TEXT,
              raw_file_path TEXT,
              status TEXT NOT NULL DEFAULT 'pinned',
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              pinned_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
              prefilter_result TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_pin_pool_items_status ON pin_pool_items(status);
            CREATE INDEX IF NOT EXISTS idx_pin_pool_items_created_at ON pin_pool_items(created_at);
            CREATE INDEX IF NOT EXISTS idx_pin_pool_items_original_id ON pin_pool_items(original_id);
          `);
        }

        // v15: process_jobs table
        if (currentVersion < 15) {
          db.exec(`
            CREATE TABLE IF NOT EXISTS process_jobs (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL DEFAULT 'markitdown',
              source_item_id TEXT,
              asset_file_ids TEXT NOT NULL DEFAULT '[]',
              status TEXT NOT NULL DEFAULT 'queued',
              progress INTEGER DEFAULT 0,
              error_message TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
              started_at INTEGER,
              completed_at INTEGER,
              metadata TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_process_jobs_status ON process_jobs(status);
            CREATE INDEX IF NOT EXISTS idx_process_jobs_type ON process_jobs(type);
            CREATE INDEX IF NOT EXISTS idx_process_jobs_created_at ON process_jobs(created_at);
          `);
        }

        if (currentVersion < 16) {
          db.exec(`
            CREATE TABLE IF NOT EXISTS distilled_notes (
              id TEXT PRIMARY KEY,
              source_item_ids TEXT NOT NULL DEFAULT '[]',
              title TEXT NOT NULL DEFAULT '',
              summary TEXT NOT NULL DEFAULT '',
              tags TEXT NOT NULL DEFAULT '[]',
              suggested_folder TEXT,
              body_markdown TEXT NOT NULL DEFAULT '',
              quality_flags TEXT NOT NULL DEFAULT '[]',
              model_provider TEXT,
              model_name TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
              metadata TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_distilled_notes_created_at ON distilled_notes(created_at);
          `);
        }

        if (currentVersion < 17) {
          db.exec(`
            CREATE TABLE IF NOT EXISTS knowledge_projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              status TEXT NOT NULL DEFAULT 'active',
              color TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE TABLE IF NOT EXISTS project_items (
              id TEXT PRIMARY KEY,
              project_id TEXT NOT NULL REFERENCES knowledge_projects(id) ON DELETE CASCADE,
              item_type TEXT NOT NULL,
              item_id TEXT NOT NULL,
              added_at INTEGER NOT NULL DEFAULT (unixepoch()),
              UNIQUE(project_id, item_type, item_id)
            );
            CREATE INDEX IF NOT EXISTS idx_project_items_project ON project_items(project_id);
            CREATE TABLE IF NOT EXISTS datasets (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              purpose TEXT NOT NULL DEFAULT 'archive',
              status TEXT NOT NULL DEFAULT 'draft',
              item_count INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE TABLE IF NOT EXISTS dataset_items (
              id TEXT PRIMARY KEY,
              dataset_id TEXT NOT NULL REFERENCES datasets(id) ON DELETE CASCADE,
              source_type TEXT NOT NULL,
              source_id TEXT NOT NULL,
              title TEXT,
              content TEXT,
              quality TEXT NOT NULL DEFAULT 'medium',
              privacy_level TEXT NOT NULL DEFAULT 'private',
              included INTEGER NOT NULL DEFAULT 1,
              reason TEXT,
              created_at INTEGER NOT NULL DEFAULT (unixepoch()),
              updated_at INTEGER NOT NULL DEFAULT (unixepoch())
            );
            CREATE INDEX IF NOT EXISTS idx_dataset_items_dataset ON dataset_items(dataset_id);
          `);
        }

        // v19: Rename vaultkeeper → external in DB
        if (currentVersion < 19) {
          // errors / error_records.error_type: vaultkeeper_unavailable → external_service_unavailable
          for (const tableName of ['error_records', 'errors']) {
            if (this.tableExists(db, tableName)) {
              db.exec(`
                UPDATE ${tableName} SET error_type = 'external_service_unavailable'
                WHERE error_type = 'vaultkeeper_unavailable'
              `);
            }
          }
          // source_items.metadata: external_processor 'vaultkeeper' → 'external'
          const rows = db.prepare(
            `SELECT id, metadata FROM source_items WHERE metadata LIKE '%"vaultkeeper"%'`
          ).all() as { id: string; metadata: string | null }[];
          const updateStmt = db.prepare(
            `UPDATE source_items SET metadata = ? WHERE id = ?`
          );
          for (const row of rows) {
            if (!row.metadata) continue;
            try {
              const meta = JSON.parse(row.metadata);
              if (meta.external_processor === 'vaultkeeper') {
                meta.external_processor = 'external';
                updateStmt.run(JSON.stringify(meta), row.id);
              }
            } catch { /* skip malformed JSON */ }
          }
        }

        // ── v20: ToolBench tables ──
        if (currentVersion < 20) {
          db.exec(`
            CREATE TABLE IF NOT EXISTS tool_projects (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              repo_url TEXT,
              local_path TEXT,
              launch_command TEXT,
              docs_path TEXT,
              category TEXT NOT NULL DEFAULT 'other',
              tags_json TEXT NOT NULL DEFAULT '[]',
              status TEXT NOT NULL DEFAULT 'saved',
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              last_used_at TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_tool_projects_category ON tool_projects(category);
            CREATE INDEX IF NOT EXISTS idx_tool_projects_updated_at ON tool_projects(updated_at);

            CREATE TABLE IF NOT EXISTS local_script_tools (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              command TEXT NOT NULL,
              working_directory TEXT,
              description TEXT NOT NULL DEFAULT '',
              tags_json TEXT NOT NULL DEFAULT '[]',
              safety_level TEXT NOT NULL DEFAULT 'safe',
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              last_used_at TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_local_script_tools_updated_at ON local_script_tools(updated_at);
          `);
        }

        // v21: Add file-related columns to source_items
        if (currentVersion < 21) {
          try { db.exec(`ALTER TABLE source_items ADD COLUMN file_path TEXT`); } catch { /* column may already exist */ }
          try { db.exec(`ALTER TABLE source_items ADD COLUMN thumbnail_path TEXT`); } catch { /* column may already exist */ }
          try { db.exec(`ALTER TABLE source_items ADD COLUMN updated_at INTEGER`); } catch { /* column may already exist */ }
          try { db.exec(`ALTER TABLE source_items ADD COLUMN file_size INTEGER`); } catch { /* column may already exist */ }
          try { db.exec(`ALTER TABLE source_items ADD COLUMN mime_type TEXT`); } catch { /* column may already exist */ }
        }

        db.prepare(
          'INSERT OR REPLACE INTO _migration (version) VALUES (?)',
        ).run(CURRENT_SCHEMA_VERSION);
      });

      migrate();
      logger.info('app', 'storage', 'migrate', `Migrated from v${currentVersion} to v${CURRENT_SCHEMA_VERSION}`);

      // v18: one-time legacy contentPath migration (runs outside transaction)
      if (currentVersion < 18) {
        import('./migrateLegacyContent').then(({ migrateLegacyContentPath }) => {
          try {
            migrateLegacyContentPath();
          } catch (error) {
            logger.error('app', 'storage', 'migrate', 'v18 legacy content migration failed', {
              error: error instanceof Error ? error.message : String(error),
            });
          }
        });
      }
    }

    // Defensive schema reconciliation. Some older migrations used a non-constant
    // SQLite default expression in ALTER TABLE, then swallowed the failure while
    // still advancing _migration. Keep critical columns present regardless of
    // migration version so runtime statements cannot fail on existing databases.
    this.ensureAiTasksUpdatedAtColumn(db);
  }

  private ensureAiTasksUpdatedAtColumn(db: Database.Database): void {
    const columns = db.prepare('PRAGMA table_info(ai_tasks)').all() as Array<{ name: string }>;
    if (!columns.some((column) => column.name === 'updated_at')) {
      db.exec(`ALTER TABLE ai_tasks ADD COLUMN updated_at INTEGER NOT NULL DEFAULT 0`);
    }
    db.exec(`UPDATE ai_tasks SET updated_at = created_at WHERE updated_at IS NULL OR updated_at = 0`);
  }

  private tableExists(db: Database.Database, tableName: string): boolean {
    const row = db.prepare(
      `SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1`,
    ).get(tableName);
    return !!row;
  }

  /**
   * Seed a small set of curated tool entries so useful local projects show up
   * in ToolBench without manual import.
   */
  private seedFeaturedToolProjects(): void {
    const featuredProjects = [
      {
        id: 'featured_ztools_search',
        name: 'ZTools',
        description: '一个高性能、可扩展的桌面搜索工具和插件平台，适合作为 AcMind 的搜索能力参考项目。',
        repoUrl: 'https://github.com/ZToolsCenter/ZTools',
        localPath: '/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main',
        launchCommand: 'cd "/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main" && pnpm dev',
        docsPath: '/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main/README.md',
        category: 'knowledge',
        tags: ['搜索', '启动器', '插件平台'],
        status: 'saved',
      },
    ];

    for (const project of featuredProjects) {
      if (project.localPath && !existsSync(project.localPath)) {
        continue;
      }
      const existing = project.localPath ? this.getGithubProjectByLocalPath(project.localPath) : null;
      if (existing) {
        continue;
      }
      this.insertGithubProject({ ...project });
    }
  }

  /**
   * Get the raw database instance (for ErrorService initialization).
   */
  getDb(): Database.Database | null {
    return this._db;
  }

  /**
   * Prepare frequently-used statements for performance.
   */
  private prepareStatements(): void {
    const db = this._db!;

    this.stmtInsertSourceItem = db.prepare(`
      INSERT INTO source_items (id, capture_item_id, type, source, content_path, content_hash, preview_text, ocr_text, source_app, original_url, created_at, status, title, tags, vault_import_path, original_id, metadata, file_path, thumbnail_path, updated_at, file_size, mime_type)
      VALUES (@id, @capture_item_id, @type, @source, @content_path, @content_hash, @preview_text, @ocr_text, @source_app, @original_url, @created_at, @status, @title, @tags, @vault_import_path, @original_id, @metadata, @file_path, @thumbnail_path, @updated_at, @file_size, @mime_type)
    `);

    this.stmtGetSourceItem = db.prepare('SELECT * FROM source_items WHERE id = ?');
    this.stmtGetSourceItemByCaptureItemId = db.prepare('SELECT * FROM source_items WHERE capture_item_id = ? LIMIT 1');

    this.stmtUpdateSourceItem = db.prepare(`
      UPDATE source_items SET
        capture_item_id = @capture_item_id, type = @type, source = @source, content_path = @content_path, content_hash = @content_hash,
        preview_text = @preview_text, ocr_text = @ocr_text, source_app = @source_app,
        original_url = @original_url, status = @status, title = @title, tags = @tags,
        vault_import_path = @vault_import_path, original_id = @original_id, metadata = @metadata,
        file_path = @file_path, thumbnail_path = @thumbnail_path, updated_at = @updated_at, file_size = @file_size, mime_type = @mime_type
      WHERE id = @id
    `);

    this.stmtDeleteSourceItem = db.prepare('DELETE FROM source_items WHERE id = ?');

    this.stmtInsertAiTask = db.prepare(`
      INSERT INTO ai_tasks (id, source_item_id, tier, operation, status, provider, model, input, output, error, created_at, updated_at, started_at, finished_at, latency_ms)
      VALUES (@id, @source_item_id, @tier, @operation, @status, @provider, @model, @input, @output, @error, @created_at, @updated_at, @started_at, @finished_at, @latency_ms)
    `);

    this.stmtUpdateAiTask = db.prepare(`
      UPDATE ai_tasks SET
        status = @status, output = @output, error = @error, started_at = @started_at, finished_at = @finished_at, latency_ms = @latency_ms, updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtInsertDistilledOutput = db.prepare(`
      INSERT INTO distilled_outputs (id, source_item_id, task_id, operation, suggested_title, summary, category, tags, document_type, content_markdown, value_score, clean_suggestion, confidence, review_status, reviewed_at, accepted_knowledge_card_id, created_at)
      VALUES (@id, @source_item_id, @task_id, @operation, @suggested_title, @summary, @category, @tags, @document_type, @content_markdown, @value_score, @clean_suggestion, @confidence, @review_status, @reviewed_at, @accepted_knowledge_card_id, @created_at)
    `);

    this.stmtUpdateDistilledOutput = db.prepare(`
      UPDATE distilled_outputs SET
        suggested_title = @suggested_title,
        summary = @summary,
        category = @category,
        tags = @tags,
        document_type = @document_type,
        content_markdown = @content_markdown,
        value_score = @value_score,
        clean_suggestion = @clean_suggestion,
        confidence = @confidence,
        review_status = @review_status,
        reviewed_at = @reviewed_at,
        accepted_knowledge_card_id = @accepted_knowledge_card_id
      WHERE id = @id
    `);

    this.stmtInsertExportRecord = db.prepare(`
      INSERT INTO export_records (id, source_item_id, distilled_output_id, knowledge_card_id, vault_path, relative_file_path, frontmatter, exported_at, status, conflict_resolution, error)
      VALUES (@id, @source_item_id, @distilled_output_id, @knowledge_card_id, @vault_path, @relative_file_path, @frontmatter, @exported_at, @status, @conflict_resolution, @error)
    `);

    this.stmtInsertKnowledgeCard = db.prepare(`
      INSERT INTO knowledge_cards (id, source_item_id, distilled_output_id, canonical_title, summary, category, tags, body, status, created_at, updated_at)
      VALUES (@id, @source_item_id, @distilled_output_id, @canonical_title, @summary, @category, @tags, @body, @status, @created_at, @updated_at)
    `);

    this.stmtUpdateKnowledgeCard = db.prepare(`
      UPDATE knowledge_cards SET
        distilled_output_id = @distilled_output_id,
        canonical_title = @canonical_title,
        summary = @summary,
        category = @category,
        tags = @tags,
        body = @body,
        status = @status,
        updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtGetKnowledgeCardBySourceItemId = db.prepare('SELECT * FROM knowledge_cards WHERE source_item_id = ? LIMIT 1');

    this.stmtInsertKnowledgeEdge = db.prepare(`
      INSERT INTO knowledge_edges (id, from_knowledge_card_id, to_knowledge_card_id, relation_type, status, confidence, reason, created_at, updated_at)
      VALUES (@id, @from_knowledge_card_id, @to_knowledge_card_id, @relation_type, @status, @confidence, @reason, @created_at, @updated_at)
    `);

    this.stmtInsertReviewEvent = db.prepare(`
      INSERT INTO review_events (id, source_item_id, distilled_output_id, knowledge_card_id, action, before, after, actor, provider, model, task_id, created_at)
      VALUES (@id, @source_item_id, @distilled_output_id, @knowledge_card_id, @action, @before, @after, @actor, @provider, @model, @task_id, @created_at)
    `);

    this.stmtInsertTrainingExample = db.prepare(`
      INSERT INTO training_examples (id, capability, source_item_id, distilled_output_id, knowledge_card_id, input, teacher_output, target_output, metadata, created_at)
      VALUES (@id, @capability, @source_item_id, @distilled_output_id, @knowledge_card_id, @input, @teacher_output, @target_output, @metadata, @created_at)
    `);

    this.stmtInsertDatasetSnapshot = db.prepare(`
      INSERT INTO dataset_snapshots (id, name, description, manifest_path, split_config, counts, status, created_at, frozen_at)
      VALUES (@id, @name, @description, @manifest_path, @split_config, @counts, @status, @created_at, @frozen_at)
    `);

    this.stmtUpdateDatasetSnapshot = db.prepare(`
      UPDATE dataset_snapshots SET
        name = @name,
        description = @description,
        manifest_path = @manifest_path,
        split_config = @split_config,
        counts = @counts,
        status = @status,
        frozen_at = @frozen_at
      WHERE id = @id
    `);

    this.stmtInsertTrainingRun = db.prepare(`
      INSERT INTO training_runs (id, snapshot_id, base_model, status, manifest_path, artifact_path, metrics, error, created_at, finished_at)
      VALUES (@id, @snapshot_id, @base_model, @status, @manifest_path, @artifact_path, @metrics, @error, @created_at, @finished_at)
    `);

    this.stmtUpdateTrainingRun = db.prepare(`
      UPDATE training_runs SET
        snapshot_id = @snapshot_id,
        base_model = @base_model,
        status = @status,
        manifest_path = @manifest_path,
        artifact_path = @artifact_path,
        metrics = @metrics,
        error = @error,
        finished_at = @finished_at
      WHERE id = @id
    `);

    this.stmtInsertEvalRun = db.prepare(`
      INSERT INTO eval_runs (id, snapshot_id, training_run_id, model_version_id, metrics, created_at)
      VALUES (@id, @snapshot_id, @training_run_id, @model_version_id, @metrics, @created_at)
    `);

    this.stmtInsertModelVersion = db.prepare(`
      INSERT INTO model_versions (id, name, base_model, artifact_path, modelfile_path, provider, status, notes, created_at, updated_at)
      VALUES (@id, @name, @base_model, @artifact_path, @modelfile_path, @provider, @status, @notes, @created_at, @updated_at)
    `);

    this.stmtUpdateModelVersion = db.prepare(`
      UPDATE model_versions SET
        name = @name,
        base_model = @base_model,
        artifact_path = @artifact_path,
        modelfile_path = @modelfile_path,
        provider = @provider,
        status = @status,
        notes = @notes,
        updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtGetSetting = db.prepare('SELECT value FROM app_settings WHERE key = ?');

    this.stmtSetSetting = db.prepare(
      'INSERT OR REPLACE INTO app_settings (key, value) VALUES (@key, @value)',
    );

    this.stmtUpsertProviderConfig = db.prepare(`
      INSERT INTO provider_configs (id, name, type, tier, base_url, api_key, model_id, enabled, capabilities)
      VALUES (@id, @name, @type, @tier, @base_url, @api_key, @model_id, @enabled, @capabilities)
      ON CONFLICT(id) DO UPDATE SET
        name = @name, type = @type, tier = @tier, base_url = @base_url,
        api_key = @api_key, model_id = @model_id, enabled = @enabled, capabilities = @capabilities
    `);

    this.stmtDeleteProviderConfig = db.prepare('DELETE FROM provider_configs WHERE id = ?');

    this.stmtGetVaultConfig = db.prepare('SELECT * FROM vault_config WHERE id = 1');

    this.stmtUpdateVaultConfig = db.prepare(`
      UPDATE vault_config SET
        vault_path = @vault_path, default_folder = @default_folder, template = @template,
        path_rule = @path_rule, conflict_strategy = @conflict_strategy,
        auto_frontmatter = @auto_frontmatter, frontmatter_template = @frontmatter_template
      WHERE id = 1
    `);

    this.stmtInsertImportTask = db.prepare(`
      INSERT INTO import_tasks (id, vault_path, folder_path, status, total_files, imported_count, skipped_count, failed_count, exclude_patterns, include_patterns, created_at, started_at, finished_at, error)
      VALUES (@id, @vault_path, @folder_path, @status, @total_files, @imported_count, @skipped_count, @failed_count, @exclude_patterns, @include_patterns, @created_at, @started_at, @finished_at, @error)
    `);

    this.stmtGetImportTask = db.prepare('SELECT * FROM import_tasks WHERE id = ?');

    this.stmtUpdateImportTask = db.prepare(`
      UPDATE import_tasks SET
        status = @status, total_files = @total_files, imported_count = @imported_count,
        skipped_count = @skipped_count, failed_count = @failed_count,
        started_at = @started_at, finished_at = @finished_at, error = @error
      WHERE id = @id
    `);

    // Capture Inbox prepared statements
    this.stmtInsertCaptureItem = db.prepare(`
      INSERT INTO capture_items (id, type, status, title, raw_text, source_url, file_path, user_note, captured_at, updated_at)
      VALUES (@id, @type, @status, @title, @raw_text, @source_url, @file_path, @user_note, @captured_at, @updated_at)
    `);

    this.stmtGetCaptureItem = db.prepare('SELECT * FROM capture_items WHERE id = ?');

    this.stmtUpdateCaptureItem = db.prepare(`
      UPDATE capture_items SET
        type = @type, status = @status, title = @title, raw_text = @raw_text,
        source_url = @source_url, file_path = @file_path, user_note = @user_note,
        captured_at = @captured_at, updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtDeleteCaptureItem = db.prepare('DELETE FROM capture_items WHERE id = ?');

    // Phase A: Agent Chat prepared statements
    this.stmtInsertChatSession = db.prepare(`
      INSERT INTO chat_sessions (id, title, provider_id, model_id, status, metadata, created_at, updated_at)
      VALUES (@id, @title, @provider_id, @model_id, @status, @metadata, @created_at, @updated_at)
    `);

    this.stmtGetChatSession = db.prepare('SELECT * FROM chat_sessions WHERE id = ?');

    this.stmtUpdateChatSession = db.prepare(`
      UPDATE chat_sessions SET
        title = @title, provider_id = @provider_id, model_id = @model_id,
        status = @status, metadata = @metadata, updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtDeleteChatSession = db.prepare('DELETE FROM chat_sessions WHERE id = ?');

    this.stmtListChatSessions = db.prepare(`
      SELECT * FROM chat_sessions
      WHERE status = @status
      ORDER BY updated_at DESC
      LIMIT @limit OFFSET @offset
    `);

    this.stmtInsertChatMessage = db.prepare(`
      INSERT INTO chat_messages (id, session_id, role, content, status, model_id, provider_id, prompt_tokens, completion_tokens, latency_ms, error, action_proposals, created_at)
      VALUES (@id, @session_id, @role, @content, @status, @model_id, @provider_id, @prompt_tokens, @completion_tokens, @latency_ms, @error, @action_proposals, @created_at)
    `);

    this.stmtGetChatMessage = db.prepare('SELECT * FROM chat_messages WHERE id = ?');

    this.stmtUpdateChatMessage = db.prepare(`
      UPDATE chat_messages SET
        content = @content, status = @status, model_id = @model_id, provider_id = @provider_id,
        prompt_tokens = @prompt_tokens, completion_tokens = @completion_tokens, latency_ms = @latency_ms,
        error = @error, action_proposals = @action_proposals
      WHERE id = @id
    `);

    this.stmtListChatMessages = db.prepare(`
      SELECT * FROM chat_messages
      WHERE session_id = @session_id
      ORDER BY created_at ASC
      LIMIT @limit
    `);

    // Phase C: Agent Tasks prepared statements
    this.stmtInsertAgentTask = db.prepare(`
      INSERT INTO agent_tasks (id, session_id, name, status, skill_name, input_params, result, error, started_at, completed_at, created_at, updated_at)
      VALUES (@id, @session_id, @name, @status, @skill_name, @input_params, @result, @error, @started_at, @completed_at, @created_at, @updated_at)
    `);

    this.stmtGetAgentTask = db.prepare('SELECT * FROM agent_tasks WHERE id = ?');

    this.stmtUpdateAgentTask = db.prepare(`
      UPDATE agent_tasks SET
        name = @name, status = @status, skill_name = @skill_name,
        input_params = @input_params, result = @result, error = @error,
        started_at = @started_at, completed_at = @completed_at, updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtDeleteAgentTask = db.prepare('DELETE FROM agent_tasks WHERE id = ?');

    this.stmtListAgentTasks = db.prepare(`
      SELECT * FROM agent_tasks
      WHERE status = @status
      ORDER BY updated_at DESC
      LIMIT @limit OFFSET @offset
    `);

    this.stmtInsertAgentTaskEvent = db.prepare(`
      INSERT INTO agent_task_events (id, task_id, event_type, description, metadata, created_at)
      VALUES (@id, @task_id, @event_type, @description, @metadata, @created_at)
    `);

    this.stmtListAgentTaskEvents = db.prepare(`
      SELECT * FROM agent_task_events
      WHERE task_id = @task_id
      ORDER BY created_at ASC
      LIMIT @limit
    `);

    // Phase D: Scheduled Agent Tasks prepared statements
    this.stmtInsertScheduledAgentTask = db.prepare(`
      INSERT INTO scheduled_agent_tasks (id, name, cron_expression, skill_name, input_params, enabled, last_run_at, last_run_status, last_run_task_id, created_at, updated_at)
      VALUES (@id, @name, @cron_expression, @skill_name, @input_params, @enabled, @last_run_at, @last_run_status, @last_run_task_id, @created_at, @updated_at)
    `);

    this.stmtGetScheduledAgentTask = db.prepare('SELECT * FROM scheduled_agent_tasks WHERE id = ?');

    this.stmtUpdateScheduledAgentTask = db.prepare(`
      UPDATE scheduled_agent_tasks SET
        name = @name, cron_expression = @cron_expression, skill_name = @skill_name,
        input_params = @input_params, enabled = @enabled, last_run_at = @last_run_at,
        last_run_status = @last_run_status, last_run_task_id = @last_run_task_id, updated_at = @updated_at
      WHERE id = @id
    `);

    this.stmtDeleteScheduledAgentTask = db.prepare('DELETE FROM scheduled_agent_tasks WHERE id = ?');

    this.stmtListScheduledAgentTasks = db.prepare(`
      SELECT * FROM scheduled_agent_tasks
      ORDER BY updated_at DESC
    `);
  }

  // -------------------------------------------------------------------------
  // SourceItem CRUD
  // -------------------------------------------------------------------------

  getSourceItems(filter?: { status?: SourceItemStatus; type?: string; source?: SourceItemSource; limit?: number; offset?: number }): SourceItem[] {
    const db = this._db!;
    let sql = 'SELECT * FROM source_items';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.type) {
      conditions.push('type = ?');
      params.push(filter.type);
    }
    if (filter?.source) {
      conditions.push('source = ?');
      params.push(filter.source);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
      if (filter?.offset) {
        sql += ' OFFSET ?';
        params.push(filter.offset);
      }
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToSourceItem);
  }

  getSourceItem(id: string): SourceItem | null {
    const row = this.stmtGetSourceItem.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToSourceItem(row) : null;
  }

  getSourceItemByCaptureItemId(captureItemId: string): SourceItem | null {
    const row = this.stmtGetSourceItemByCaptureItemId.get(captureItemId) as Record<string, unknown> | undefined;
    return row ? this.rowToSourceItem(row) : null;
  }

  // V2.1: Lookup source item by original_id (for dedup)
  getSourceItemByOriginalId(originalId: string): SourceItem | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM source_items WHERE original_id = ? LIMIT 1').get(originalId) as Record<string, unknown> | undefined;
    return row ? this.rowToSourceItem(row) : null;
  }

  // V2.1 Phase 9: Find source item by metadata key-value (JSON search)
  findSourceItemByMetadata(key: string, value: string): SourceItem | null {
    const db = this._db!;
    // metadata is stored as JSON string; use LIKE to find matching key-value pair
    const pattern = `%"${key}":"${value}"%`;
    const row = db.prepare(
      'SELECT * FROM source_items WHERE metadata LIKE ? LIMIT 1',
    ).get(pattern) as Record<string, unknown> | undefined;
    return row ? this.rowToSourceItem(row) : null;
  }

  // V2.1: Get state history for a source item
  getContentStateHistory(sourceItemId: string): Array<{
    id: string;
    sourceItemId: string;
    fromState: string;
    toState: string;
    actor: string;
    reason?: string;
    error?: string;
    createdAt: number;
  }> {
    const db = this._db!;
    const rows = db.prepare(
      'SELECT id, source_item_id, from_state, to_state, actor, reason, error, created_at FROM content_state_history WHERE source_item_id = ? ORDER BY created_at DESC',
    ).all(sourceItemId) as Array<Record<string, unknown>>;
    return rows.map((row) => ({
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      fromState: row.from_state as string,
      toState: row.to_state as string,
      actor: row.actor as string,
      reason: (row.reason as string) ?? undefined,
      error: (row.error as string) ?? undefined,
      createdAt: row.created_at as number,
    }));
  }

  // V2.1: Record a state transition in history
  insertContentStateHistory(params: {
    sourceItemId: string;
    fromState: string;
    toState: string;
    actor?: string;
    reason?: string;
    error?: string;
  }): void {
    const db = this._db!;
    const id = `csh_${Date.now()}_${randomUUID().slice(0, 8)}`;
    db.prepare(`
      INSERT INTO content_state_history (id, source_item_id, from_state, to_state, actor, reason, error)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(id, params.sourceItemId, params.fromState, params.toState, params.actor ?? 'system', params.reason ?? null, params.error ?? null);
  }

  // ---------------------------------------------------------------------------
  // Capture → SourceItem bridge helpers
  // ---------------------------------------------------------------------------

  /**
   * Map CaptureItem.type to SourceItem.source.
   * Preserves capture origin semantics instead of hardcoding 'manual'.
   */
  private mapCaptureTypeToSource(type: CaptureItem['type']): SourceItem['source'] {
    switch (type) {
      case 'image': return 'screenshot';
      case 'audio': return 'audio';
      case 'text': return 'clipboard';
      case 'link': return 'manual';
      default: return 'manual';
    }
  }

  createSourceItemFromCaptureItem(captureItemId: string): SourceItem {
    const existing = this.getSourceItemByCaptureItemId(captureItemId);
    if (existing) {
      return existing;
    }

    const captureItem = this.getCaptureItem(captureItemId);
    if (!captureItem) {
      throw new Error(`CaptureItem not found: ${captureItemId}`);
    }

    const now = Math.max(captureItem.capturedAt, Math.floor(Date.now() / 1000));
    const storageRoot = this.storageRoot ?? process.cwd();
    const dateDir = new Date(now * 1000).toISOString().slice(0, 10);
    const bridgeDir = path.join(storageRoot, 'sources', dateDir, 'capture-bridge');
    mkdirSync(bridgeDir, { recursive: true });

    const sourceId = captureItemId;
    let contentPath = captureItem.filePath || '';
    let sourceType: SourceItem['type'] = captureItem.type === 'image' ? 'image' : captureItem.type === 'link' ? 'url' : 'text';
    let contentText = captureItem.rawText || captureItem.sourceUrl || captureItem.title || '';

    if (sourceType === 'image' && captureItem.filePath && existsSync(captureItem.filePath)) {
      const ext = path.extname(captureItem.filePath) || '.png';
      contentPath = path.join(bridgeDir, `${captureItemId}${ext}`);
      if (!existsSync(contentPath)) {
        copyFileSync(captureItem.filePath, contentPath);
      }
    } else if (sourceType === 'url') {
      contentPath = path.join(bridgeDir, `${captureItemId}.txt`);
      if (!existsSync(contentPath)) {
        writeFileSync(contentPath, captureItem.sourceUrl || captureItem.rawText || '', 'utf8');
      }
      contentText = captureItem.sourceUrl || captureItem.rawText || '';
    } else {
      contentPath = path.join(bridgeDir, `${captureItemId}.txt`);
      if (!existsSync(contentPath)) {
        writeFileSync(contentPath, contentText, 'utf8');
      }
    }

    const contentHash = createHash('sha256')
      .update([captureItem.type, captureItem.title, captureItem.rawText, captureItem.sourceUrl, captureItem.filePath].join('|'))
      .digest('hex');

    const sourceItem: SourceItem = {
      id: sourceId,
      captureItemId,
      type: sourceType,
      source: this.mapCaptureTypeToSource(captureItem.type),
      contentPath,
      contentHash,
      previewText: captureItem.title || contentText.slice(0, 240) || captureItem.userNote || '',
      originalUrl: captureItem.sourceUrl || undefined,
      createdAt: now,
      status: 'inbox',
      title: captureItem.title || undefined,
      tags: captureItem.userNote ? captureItem.userNote.split(',').map((t) => t.trim()).filter(Boolean) : undefined,
    };

    this.insertSourceItem(sourceItem);
    return sourceItem;
  }

  insertSourceItem(item: SourceItem): void {
    this.stmtInsertSourceItem.run({
      id: item.id,
      capture_item_id: item.captureItemId ?? null,
      type: item.type,
      source: item.source,
      content_path: item.contentPath,
      content_hash: item.contentHash ?? null,
      preview_text: item.previewText ?? null,
      ocr_text: item.ocrText ?? null,
      source_app: item.sourceApp ?? null,
      original_url: item.originalUrl ?? null,
      created_at: item.createdAt,
      status: item.status,
      title: item.title ?? null,
      tags: item.tags ? JSON.stringify(item.tags) : null,
      vault_import_path: item.vaultImportPath ?? null,
      original_id: item.originalId ?? null,
      metadata: item.metadata ? JSON.stringify(item.metadata) : null,
      file_path: item.filePath ?? null,
      thumbnail_path: item.thumbnailPath ?? null,
      updated_at: item.updatedAt ?? null,
      file_size: item.fileSize ?? null,
      mime_type: item.mimeType ?? null,
    });

    logger.info('app', 'storage', 'insertSourceItem', `SourceItem created: ${item.id}`, {
      type: item.type,
      status: item.status,
    });
  }

  updateSourceItem(id: string, patch: Partial<SourceItem>): void {
    const existing = this.getSourceItem(id);
    if (!existing) {
      throw new Error(`SourceItem not found: ${id}`);
    }

    const merged: SourceItem = {
      ...existing,
      ...patch,
      id,
    };

    this.stmtUpdateSourceItem.run({
      id: merged.id,
      capture_item_id: merged.captureItemId ?? null,
      type: merged.type,
      source: merged.source,
      content_path: merged.contentPath,
      content_hash: merged.contentHash ?? null,
      preview_text: merged.previewText ?? null,
      ocr_text: merged.ocrText ?? null,
      source_app: merged.sourceApp ?? null,
      original_url: merged.originalUrl ?? null,
      status: merged.status,
      title: merged.title ?? null,
      tags: merged.tags ? JSON.stringify(merged.tags) : null,
      vault_import_path: merged.vaultImportPath ?? null,
      original_id: merged.originalId ?? null,
      metadata: merged.metadata ? JSON.stringify(merged.metadata) : null,
      file_path: merged.filePath ?? null,
      thumbnail_path: merged.thumbnailPath ?? null,
      updated_at: merged.updatedAt ?? null,
      file_size: merged.fileSize ?? null,
      mime_type: merged.mimeType ?? null,
    });

    logger.info('app', 'storage', 'updateSourceItem', `SourceItem updated: ${id}`);
  }

  deleteSourceItem(id: string): void {
    const result = this.stmtDeleteSourceItem.run(id);
    if (result.changes === 0) {
      throw new Error(`SourceItem not found: ${id}`);
    }
    logger.info('app', 'storage', 'deleteSourceItem', `SourceItem deleted: ${id}`);
  }

  importFileAsSourceItem(filePath: string): SourceItem {
    if (!existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    const stat = statSync(filePath);
    const ext = path.extname(filePath).toLowerCase();
    const mimeTypeMap: Record<string, string> = {
      '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg',
      '.gif': 'image/gif', '.webp': 'image/webp', '.svg': 'image/svg+xml',
      '.bmp': 'image/bmp', '.mp3': 'audio/mpeg', '.wav': 'audio/wav',
      '.mp4': 'video/mp4', '.pdf': 'application/pdf', '.txt': 'text/plain',
      '.md': 'text/markdown', '.json': 'application/json',
    };
    const mimeType = mimeTypeMap[ext] || 'application/octet-stream';

    let itemType: SourceItem['type'] = 'file';
    if (mimeType.startsWith('image/')) itemType = 'image';
    else if (mimeType.startsWith('audio/')) itemType = 'audio';
    else if (mimeType.startsWith('video/')) itemType = 'video';

    const now = Math.floor(Date.now() / 1000);
    const storageRoot = this.storageRoot ?? process.cwd();
    const dateDir = new Date(now * 1000).toISOString().slice(0, 10);
    const importDir = path.join(storageRoot, 'sources', dateDir, 'file-import');
    mkdirSync(importDir, { recursive: true });

    const id = randomUUID();
    const destPath = path.join(importDir, `${id}${ext}`);
    copyFileSync(filePath, destPath);

    const contentHash = createHash('sha256').update(readFileSync(filePath)).digest('hex');

    const sourceItem: SourceItem = {
      id,
      type: itemType,
      source: 'file_import',
      contentPath: destPath,
      filePath: filePath,
      contentHash,
      previewText: path.basename(filePath),
      title: path.basename(filePath, ext),
      createdAt: now,
      status: 'inbox',
      fileSize: stat.size,
      mimeType,
    };

    this.insertSourceItem(sourceItem);
    return sourceItem;
  }

  saveUrlAsSourceItem(url: string): SourceItem {
    if (!url || typeof url !== 'string') {
      throw new Error('Invalid URL');
    }

    const now = Math.floor(Date.now() / 1000);
    const storageRoot = this.storageRoot ?? process.cwd();
    const dateDir = new Date(now * 1000).toISOString().slice(0, 10);
    const urlDir = path.join(storageRoot, 'sources', dateDir, 'url-import');
    mkdirSync(urlDir, { recursive: true });

    const id = randomUUID();
    const contentPath = path.join(urlDir, `${id}.txt`);
    writeFileSync(contentPath, url, 'utf8');

    const contentHash = createHash('sha256').update(url).digest('hex');

    let parsedTitle: string | undefined;
    try {
      parsedTitle = new URL(url).hostname;
    } catch {
      parsedTitle = undefined;
    }

    const sourceItem: SourceItem = {
      id,
      type: 'url',
      source: 'url_paste',
      contentPath,
      contentHash,
      previewText: url,
      originalUrl: url,
      title: parsedTitle,
      createdAt: now,
      status: 'inbox',
    };

    this.insertSourceItem(sourceItem);
    return sourceItem;
  }

  searchSourceItems(query: string): SourceItem[] {
    const db = this._db!;
    const pattern = `%${query}%`;
    const rows = db
      .prepare(
        'SELECT * FROM source_items WHERE preview_text LIKE ? OR ocr_text LIKE ? OR original_url LIKE ? ORDER BY created_at DESC LIMIT 50',
      )
      .all(pattern, pattern, pattern) as Record<string, unknown>[];
    return rows.map(this.rowToSourceItem);
  }

  // -------------------------------------------------------------------------
  // AiTask CRUD
  // -------------------------------------------------------------------------

  insertAiTask(task: AiTask): void {
    this.stmtInsertAiTask.run({
      id: task.id,
      source_item_id: task.sourceItemId,
      tier: task.tier,
      operation: task.operation,
      status: task.status,
      provider: task.provider,
      model: task.model,
      input: JSON.stringify(task.input),
      output: task.output ? JSON.stringify(task.output) : null,
      error: task.error ?? null,
      created_at: task.createdAt,
      updated_at: task.updatedAt,
      started_at: task.startedAt ?? null,
      finished_at: task.finishedAt ?? null,
      latency_ms: task.latencyMs ?? null,
    });

    logger.info('ai', 'storage', 'insertAiTask', `AiTask created: ${task.id}`, {
      operation: task.operation,
      sourceItemId: task.sourceItemId,
    });
  }

  updateAiTask(id: string, patch: Partial<AiTask>): void {
    const db = this._db!;
    const existing = db.prepare('SELECT * FROM ai_tasks WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    if (!existing) {
      throw new Error(`AiTask not found: ${id}`);
    }

    this.stmtUpdateAiTask.run({
      id,
      status: patch.status ?? (existing.status as AiTaskStatus),
      output: patch.output ? JSON.stringify(patch.output) : (existing.output as string | null),
      error: patch.error ?? (existing.error as string | null),
      started_at: patch.startedAt ?? (existing.started_at as number | null),
      finished_at: patch.finishedAt ?? (existing.finished_at as number | null),
      latency_ms: patch.latencyMs ?? (existing.latency_ms as number | null),
      updated_at: Math.floor(Date.now() / 1000),
    });

    logger.info('ai', 'storage', 'updateAiTask', `AiTask updated: ${id}`, {
      status: patch.status,
    });
  }

  getAiTask(id: string): AiTask | null {
    const row = this._db!.prepare('SELECT * FROM ai_tasks WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToAiTask(row) : null;
  }

  getAiTasks(filter?: { status?: AiTaskStatus; sourceItemId?: string; limit?: number }): AiTask[] {
    const db = this._db!;
    let sql = 'SELECT * FROM ai_tasks';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToAiTask);
  }

  // -------------------------------------------------------------------------
  // DistilledOutput CRUD
  // -------------------------------------------------------------------------

  insertDistilledOutput(output: DistilledOutput): void {
    this.stmtInsertDistilledOutput.run({
      id: output.id,
      source_item_id: output.sourceItemId,
      task_id: output.taskId,
      operation: output.operation ?? null,
      suggested_title: output.suggestedTitle ?? null,
      summary: output.summary ?? null,
      category: output.category ?? null,
      tags: output.tags ? JSON.stringify(output.tags) : null,
      document_type: output.documentType ?? null,
      content_markdown: output.contentMarkdown ?? null,
      value_score: output.valueScore ?? null,
      clean_suggestion: output.cleanSuggestion ?? null,
      confidence: output.confidence ?? null,
      review_status: output.reviewStatus ?? 'pending',
      reviewed_at: output.reviewedAt ?? null,
      accepted_knowledge_card_id: output.acceptedKnowledgeCardId ?? null,
      created_at: output.createdAt,
    });

    logger.info('ai', 'storage', 'insertDistilledOutput', `DistilledOutput created: ${output.id}`);
  }

  updateDistilledOutput(id: string, patch: Partial<DistilledOutput>): DistilledOutput | null {
    const db = this._db!;
    const existing = db.prepare('SELECT * FROM distilled_outputs WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    if (!existing) {
      return null;
    }

    const nextOutput: DistilledOutput = {
      ...this.rowToDistilledOutput(existing),
      ...patch,
      id,
    };

    this.stmtUpdateDistilledOutput.run({
      id,
      suggested_title: nextOutput.suggestedTitle ?? null,
      summary: nextOutput.summary ?? null,
      category: nextOutput.category ?? null,
      tags: nextOutput.tags ? JSON.stringify(nextOutput.tags) : null,
      document_type: nextOutput.documentType ?? null,
      content_markdown: nextOutput.contentMarkdown ?? null,
      value_score: nextOutput.valueScore ?? null,
      clean_suggestion: nextOutput.cleanSuggestion ?? null,
      confidence: nextOutput.confidence ?? null,
      review_status: nextOutput.reviewStatus ?? 'pending',
      reviewed_at: nextOutput.reviewedAt ?? null,
      accepted_knowledge_card_id: nextOutput.acceptedKnowledgeCardId ?? null,
    });

    const row = db.prepare('SELECT * FROM distilled_outputs WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToDistilledOutput(row) : null;
  }

  getDistilledOutputs(filter?: { sourceItemId?: string; reviewStatus?: string; limit?: number }): DistilledOutput[] {
    const db = this._db!;
    let sql = 'SELECT * FROM distilled_outputs';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }

    if (filter?.reviewStatus) {
      conditions.push('review_status = ?');
      params.push(filter.reviewStatus);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToDistilledOutput);
  }

  getKnowledgeEdges(filter?: {
    status?: KnowledgeEdge['status'];
    relationType?: KnowledgeEdge['relationType'];
    fromKnowledgeCardId?: string;
    toKnowledgeCardId?: string;
    limit?: number;
  }): KnowledgeEdge[] {
    const db = this._db!;
    let sql = 'SELECT * FROM knowledge_edges';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.relationType) {
      conditions.push('relation_type = ?');
      params.push(filter.relationType);
    }
    if (filter?.fromKnowledgeCardId) {
      conditions.push('from_knowledge_card_id = ?');
      params.push(filter.fromKnowledgeCardId);
    }
    if (filter?.toKnowledgeCardId) {
      conditions.push('to_knowledge_card_id = ?');
      params.push(filter.toKnowledgeCardId);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToKnowledgeEdge);
  }

  getKnowledgeGraph(filter?: { cardId?: string; includeSuggested?: boolean; category?: string; tag?: string; limit?: number }): { cards: KnowledgeCard[]; edges: KnowledgeEdge[] } {
    const cards = filter?.cardId
      ? [this.getKnowledgeCard(filter.cardId)].filter((item): item is KnowledgeCard => Boolean(item))
      : this.listKnowledgeCards({
          status: undefined,
          category: filter?.category,
          tag: filter?.tag,
          limit: filter?.limit,
        });

    const cardIds = new Set(cards.map((card) => card.id));
    const edges = this.getKnowledgeEdges({
      status: filter?.includeSuggested ? undefined : 'accepted',
      limit: filter?.limit,
    }).filter((edge) => cardIds.size === 0 || cardIds.has(edge.fromKnowledgeCardId) || cardIds.has(edge.toKnowledgeCardId));

    return { cards, edges };
  }

  reviewDistilledOutput(
    id: string,
    action: 'approve' | 'edit' | 'discard',
    data?: Partial<DistilledOutput>,
  ): { output: DistilledOutput; knowledgeCard: KnowledgeCard | null; reviewEvent: ReviewEvent } {
    const existing = this.getDistilledOutputs({}).find((item) => item.id === id);
    if (!existing) {
      throw new Error(`DistilledOutput not found: ${id}`);
    }

    const before = existing;
    const nextOutput =
      action === 'edit' && data
        ? this.updateDistilledOutput(id, { ...data, reviewStatus: 'edited', reviewedAt: Math.floor(Date.now() / 1000) })
        : this.updateDistilledOutput(id, {
            reviewStatus: action === 'discard' ? 'rejected' : 'accepted',
            reviewedAt: Math.floor(Date.now() / 1000),
          });

    if (!nextOutput) {
      throw new Error(`Failed to update distilled output: ${id}`);
    }

    const knowledgeCard = this.upsertKnowledgeCardFromReview(nextOutput, action, data);
    const reviewEvent: ReviewEvent = {
      id: randomUUID(),
      sourceItemId: nextOutput.sourceItemId,
      distilledOutputId: nextOutput.id,
      knowledgeCardId: knowledgeCard?.id,
      action,
      before: {
        suggestedTitle: before.suggestedTitle,
        summary: before.summary,
        category: before.category,
        tags: before.tags,
        valueScore: before.valueScore,
        cleanSuggestion: before.cleanSuggestion,
        confidence: before.confidence,
        reviewStatus: before.reviewStatus,
      },
      after: {
        suggestedTitle: nextOutput.suggestedTitle,
        summary: nextOutput.summary,
        category: nextOutput.category,
        tags: nextOutput.tags,
        valueScore: nextOutput.valueScore,
        cleanSuggestion: nextOutput.cleanSuggestion,
        confidence: nextOutput.confidence,
        reviewStatus: nextOutput.reviewStatus,
      },
      actor: 'user',
      provider: undefined,
      model: undefined,
      taskId: nextOutput.taskId,
      createdAt: Math.floor(Date.now() / 1000),
    };

    this.insertReviewEvent(reviewEvent);

    if (knowledgeCard && action !== 'discard') {
      this.insertTrainingExample({
        id: randomUUID(),
        capability: 'summary',
        sourceItemId: nextOutput.sourceItemId,
        distilledOutputId: nextOutput.id,
        knowledgeCardId: knowledgeCard.id,
        input: {
          sourceItemId: nextOutput.sourceItemId,
          distilledOutputId: nextOutput.id,
        },
        teacherOutput: {
          suggestedTitle: nextOutput.suggestedTitle,
          summary: nextOutput.summary,
          category: nextOutput.category,
          tags: nextOutput.tags ?? [],
        },
        targetOutput: {
          canonicalTitle: knowledgeCard.canonicalTitle,
          summary: knowledgeCard.summary,
          category: knowledgeCard.category,
          tags: knowledgeCard.tags,
        },
        metadata: {
          action,
          taskId: nextOutput.taskId,
          reviewedAt: reviewEvent.createdAt,
        },
        createdAt: reviewEvent.createdAt,
      });
    }

    if (action === 'approve' || action === 'edit') {
      const sourceItem = this.getSourceItem(nextOutput.sourceItemId);
      if (sourceItem && sourceItem.status !== 'distilled') {
        this.updateSourceItem(sourceItem.id, { status: 'distilled' });
      }
    }

    return { output: nextOutput, knowledgeCard, reviewEvent };
  }

  getKnowledgeCard(id: string): KnowledgeCard | null {
    const row = this._db!.prepare('SELECT * FROM knowledge_cards WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToKnowledgeCard(row) : null;
  }

  getKnowledgeCardBySourceItemId(sourceItemId: string): KnowledgeCard | null {
    const row = this.stmtGetKnowledgeCardBySourceItemId.get(sourceItemId) as Record<string, unknown> | undefined;
    return row ? this.rowToKnowledgeCard(row) : null;
  }

  listKnowledgeCards(filter?: { status?: KnowledgeCard['status']; category?: string; tag?: string; limit?: number }): KnowledgeCard[] {
    const db = this._db!;
    let sql = 'SELECT * FROM knowledge_cards';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.category) {
      conditions.push('category = ?');
      params.push(filter.category);
    }
    if (filter?.tag) {
      conditions.push("tags LIKE ?");
      params.push(`%"${filter.tag}"%`);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY updated_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToKnowledgeCard);
  }

  upsertKnowledgeCardFromReview(output: DistilledOutput, action: 'approve' | 'edit' | 'discard', patch?: Partial<DistilledOutput>): KnowledgeCard | null {
    if (action === 'discard') {
      return this.getKnowledgeCardBySourceItemId(output.sourceItemId);
    }

    const nextOutput = patch ? { ...output, ...patch, id: output.id } : output;
    const existing = this.getKnowledgeCardBySourceItemId(output.sourceItemId);
    const now = Math.floor(Date.now() / 1000);
    const card: KnowledgeCard = {
      id: existing?.id ?? randomUUID(),
      sourceItemId: output.sourceItemId,
      distilledOutputId: output.id,
      canonicalTitle: nextOutput.suggestedTitle ?? nextOutput.summary?.slice(0, 40) ?? existing?.canonicalTitle ?? '未命名知识',
      summary: nextOutput.summary ?? existing?.summary,
      category: nextOutput.category ?? existing?.category,
      tags: nextOutput.tags ?? existing?.tags ?? [],
      body:
        nextOutput.summary ??
        existing?.body ??
        [nextOutput.suggestedTitle, nextOutput.summary, nextOutput.category].filter(Boolean).join('\n'),
      status: 'active',
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    };

    const tagsJson = JSON.stringify(card.tags ?? []);
    if (existing) {
      this.stmtUpdateKnowledgeCard.run({
        id: card.id,
        distilled_output_id: card.distilledOutputId ?? null,
        canonical_title: card.canonicalTitle,
        summary: card.summary ?? null,
        category: card.category ?? null,
        tags: tagsJson,
        body: card.body ?? null,
        status: card.status,
        updated_at: card.updatedAt,
      });
    } else {
      this.stmtInsertKnowledgeCard.run({
        id: card.id,
        source_item_id: card.sourceItemId,
        distilled_output_id: card.distilledOutputId ?? null,
        canonical_title: card.canonicalTitle,
        summary: card.summary ?? null,
        category: card.category ?? null,
        tags: tagsJson,
        body: card.body ?? null,
        status: card.status,
        created_at: card.createdAt,
        updated_at: card.updatedAt,
      });
    }

    return this.getKnowledgeCard(card.id);
  }

  insertReviewEvent(event: ReviewEvent): void {
    this.stmtInsertReviewEvent.run({
      id: event.id,
      source_item_id: event.sourceItemId,
      distilled_output_id: event.distilledOutputId,
      knowledge_card_id: event.knowledgeCardId ?? null,
      action: event.action,
      before: JSON.stringify(event.before),
      after: JSON.stringify(event.after),
      actor: event.actor,
      provider: event.provider ?? null,
      model: event.model ?? null,
      task_id: event.taskId ?? null,
      created_at: event.createdAt,
    });
  }

  insertTrainingExample(example: TrainingExample): void {
    this.stmtInsertTrainingExample.run({
      id: example.id,
      capability: example.capability,
      source_item_id: example.sourceItemId,
      distilled_output_id: example.distilledOutputId ?? null,
      knowledge_card_id: example.knowledgeCardId ?? null,
      input: JSON.stringify(example.input),
      teacher_output: JSON.stringify(example.teacherOutput),
      target_output: JSON.stringify(example.targetOutput),
      metadata: JSON.stringify(example.metadata),
      created_at: example.createdAt,
    });
  }

  getTrainingExamples(filter?: { capability?: TrainingExample['capability']; sourceItemId?: string; limit?: number }): TrainingExample[] {
    const db = this._db!;
    let sql = 'SELECT * FROM training_examples';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.capability) {
      conditions.push('capability = ?');
      params.push(filter.capability);
    }
    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToTrainingExample);
  }

  getReviewEvents(filter?: { sourceItemId?: string; distilledOutputId?: string; limit?: number }): ReviewEvent[] {
    const db = this._db!;
    let sql = 'SELECT * FROM review_events';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }
    if (filter?.distilledOutputId) {
      conditions.push('distilled_output_id = ?');
      params.push(filter.distilledOutputId);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToReviewEvent);
  }

  /** @deprecated Use createDataset (v2) instead */
  createDatasetSnapshot(snapshot: DatasetSnapshot): void {
    this.stmtInsertDatasetSnapshot.run({
      id: snapshot.id,
      name: snapshot.name,
      description: snapshot.description ?? null,
      manifest_path: snapshot.manifestPath,
      split_config: JSON.stringify(snapshot.splitConfig),
      counts: JSON.stringify(snapshot.counts),
      status: snapshot.status,
      created_at: snapshot.createdAt,
      frozen_at: snapshot.frozenAt ?? null,
    });
  }

  /** @deprecated Use updateDataset (v2) instead */
  updateDatasetSnapshot(id: string, patch: Partial<DatasetSnapshot>): DatasetSnapshot | null {
    const existing = this.getDatasetSnapshot(id);
    if (!existing) {
      return null;
    }

    const merged: DatasetSnapshot = {
      ...existing,
      ...patch,
      id,
    };

    this.stmtUpdateDatasetSnapshot.run({
      id,
      name: merged.name,
      description: merged.description ?? null,
      manifest_path: merged.manifestPath,
      split_config: JSON.stringify(merged.splitConfig),
      counts: JSON.stringify(merged.counts),
      status: merged.status,
      frozen_at: merged.frozenAt ?? null,
    });

    return this.getDatasetSnapshot(id);
  }

  /** @deprecated Use getDatasets (v2) instead */
  getDatasetSnapshots(): DatasetSnapshot[] {
    const rows = this._db!.prepare('SELECT * FROM dataset_snapshots ORDER BY created_at DESC').all() as Record<string, unknown>[];
    return rows.map(this.rowToDatasetSnapshot);
  }

  /** @deprecated Use getDataset (v2) instead */
  getDatasetSnapshot(id: string): DatasetSnapshot | null {
    const row = this._db!.prepare('SELECT * FROM dataset_snapshots WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToDatasetSnapshot(row) : null;
  }

  createTrainingRun(run: TrainingRun): void {
    this.stmtInsertTrainingRun.run({
      id: run.id,
      snapshot_id: run.snapshotId,
      base_model: run.baseModel,
      status: run.status,
      manifest_path: run.manifestPath ?? null,
      artifact_path: run.artifactPath ?? null,
      metrics: JSON.stringify(run.metrics ?? {}),
      error: run.error ?? null,
      created_at: run.createdAt,
      finished_at: run.finishedAt ?? null,
    });
  }

  updateTrainingRun(id: string, patch: Partial<TrainingRun>): TrainingRun | null {
    const existing = this.getTrainingRun(id);
    if (!existing) return null;
    const merged: TrainingRun = { ...existing, ...patch, id };
    this.stmtUpdateTrainingRun.run({
      id,
      snapshot_id: merged.snapshotId,
      base_model: merged.baseModel,
      status: merged.status,
      manifest_path: merged.manifestPath ?? null,
      artifact_path: merged.artifactPath ?? null,
      metrics: JSON.stringify(merged.metrics ?? {}),
      error: merged.error ?? null,
      finished_at: merged.finishedAt ?? null,
    });
    return this.getTrainingRun(id);
  }

  getTrainingRun(id: string): TrainingRun | null {
    const row = this._db!.prepare('SELECT * FROM training_runs WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToTrainingRun(row) : null;
  }

  getTrainingRuns(): TrainingRun[] {
    const rows = this._db!.prepare('SELECT * FROM training_runs ORDER BY created_at DESC').all() as Record<string, unknown>[];
    return rows.map(this.rowToTrainingRun);
  }

  createEvalRun(run: EvalRun): void {
    this.stmtInsertEvalRun.run({
      id: run.id,
      snapshot_id: run.snapshotId,
      training_run_id: run.trainingRunId ?? null,
      model_version_id: run.modelVersionId ?? null,
      metrics: JSON.stringify(run.metrics ?? {}),
      created_at: run.createdAt,
    });
  }

  getEvalRuns(): EvalRun[] {
    const rows = this._db!.prepare('SELECT * FROM eval_runs ORDER BY created_at DESC').all() as Record<string, unknown>[];
    return rows.map(this.rowToEvalRun);
  }

  createModelVersion(model: ModelVersion): void {
    this.stmtInsertModelVersion.run({
      id: model.id,
      name: model.name,
      base_model: model.baseModel,
      artifact_path: model.artifactPath,
      modelfile_path: model.modelfilePath ?? null,
      provider: model.provider,
      status: model.status,
      notes: model.notes ?? null,
      created_at: model.createdAt,
      updated_at: model.updatedAt,
    });
  }

  updateModelVersion(id: string, patch: Partial<ModelVersion>): ModelVersion | null {
    const existing = this.getModelVersion(id);
    if (!existing) return null;
    const merged: ModelVersion = { ...existing, ...patch, id, updatedAt: Math.floor(Date.now() / 1000) };
    this.stmtUpdateModelVersion.run({
      id,
      name: merged.name,
      base_model: merged.baseModel,
      artifact_path: merged.artifactPath,
      modelfile_path: merged.modelfilePath ?? null,
      provider: merged.provider,
      status: merged.status,
      notes: merged.notes ?? null,
      updated_at: merged.updatedAt,
    });
    return this.getModelVersion(id);
  }

  getModelVersion(id: string): ModelVersion | null {
    const row = this._db!.prepare('SELECT * FROM model_versions WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToModelVersion(row) : null;
  }

  listModelVersions(): ModelVersion[] {
    const rows = this._db!.prepare('SELECT * FROM model_versions ORDER BY created_at DESC').all() as Record<string, unknown>[];
    return rows.map(this.rowToModelVersion);
  }

  // -------------------------------------------------------------------------
  // ExportRecord CRUD
  // -------------------------------------------------------------------------

  insertExportRecord(record: ExportRecord): void {
    this.stmtInsertExportRecord.run({
      id: record.id,
      source_item_id: record.sourceItemId,
      distilled_output_id: record.distilledOutputId,
      knowledge_card_id: record.knowledgeCardId ?? null,
      vault_path: record.vaultPath,
      relative_file_path: record.relativeFilePath,
      frontmatter: JSON.stringify(record.frontmatter),
      exported_at: record.exportedAt,
      status: record.status,
      conflict_resolution: record.conflictResolution ?? null,
      error: record.error ?? null,
    });

    logger.info('export', 'storage', 'insertExportRecord', `ExportRecord created: ${record.id}`, {
      status: record.status,
      vaultPath: record.vaultPath,
    });
  }

  getExportRecords(filter?: { sourceItemId?: string; distilledOutputId?: string; status?: string; limit?: number }): ExportRecord[] {
    const db = this._db!;
    let sql = 'SELECT * FROM export_records';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }
    if (filter?.distilledOutputId) {
      conditions.push('distilled_output_id = ?');
      params.push(filter.distilledOutputId);
    }
    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY exported_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToExportRecord);
  }

  // -------------------------------------------------------------------------
  // Settings (key-value)
  // -------------------------------------------------------------------------

  getSetting(key: string): string | null {
    if (!this._db || !this.stmtGetSetting) {
      return null;
    }
    const row = this.stmtGetSetting.get(key) as { value: string } | undefined;
    return row?.value ?? null;
  }

  setSetting(key: string, value: string): void {
    if (!this._db || !this.stmtSetSetting) {
      return;
    }
    this.stmtSetSetting.run({ key, value });
  }

  // -------------------------------------------------------------------------
  // ProviderConfig CRUD
  // -------------------------------------------------------------------------

  getProviderConfigs(): ProviderConfig[] {
    if (!this._db) {
      return [];
    }
    const db = this._db!;
    const rows = db.prepare('SELECT * FROM provider_configs ORDER BY rowid').all() as Record<string, unknown>[];
    return rows.map(this.rowToProviderConfig);
  }

  upsertProviderConfig(config: ProviderConfig): void {
    if (!this._db || !this.stmtUpsertProviderConfig) {
      return;
    }
    this.stmtUpsertProviderConfig.run({
      id: config.id,
      name: config.name,
      type: config.type,
      tier: config.tier,
      base_url: config.baseUrl,
      api_key: config.apiKey ?? null,
      model_id: config.modelId,
      enabled: config.enabled ? 1 : 0,
      capabilities: JSON.stringify(config.capabilities),
    });

    logger.info('ai', 'storage', 'upsertProviderConfig', `ProviderConfig saved: ${config.id}`);
  }

  deleteProviderConfig(id: string): void {
    const result = this.stmtDeleteProviderConfig.run(id);
    if (result.changes === 0) {
      throw new Error(`ProviderConfig not found: ${id}`);
    }
    logger.info('ai', 'storage', 'deleteProviderConfig', `ProviderConfig deleted: ${id}`);
  }

  // -------------------------------------------------------------------------
  // VaultConfig
  // -------------------------------------------------------------------------

  getVaultConfig(): VaultConfig {
    if (!this._db || !this.stmtGetVaultConfig) {
      return {
        vaultPath: '',
        defaultFolder: 'Inbox',
        template: '',
        pathRule: 'category_date',
        conflictStrategy: 'rename',
        autoFrontmatter: true,
        frontmatterTemplate: {},
      };
    }
    let row = this.stmtGetVaultConfig.get() as Record<string, unknown> | undefined;

    if (!row) {
      const db = this._db!;
      db.prepare(`
        INSERT OR IGNORE INTO vault_config (id, vault_path, default_folder, template, path_rule, conflict_strategy, auto_frontmatter, frontmatter_template)
        VALUES (1, '', 'Inbox', '', 'category_date', 'rename', 1, '{}')
      `).run();
      row = this.stmtGetVaultConfig.get() as Record<string, unknown>;
    }

    return {
      vaultPath: (row.vault_path as string) ?? '',
      defaultFolder: (row.default_folder as string) ?? 'Inbox',
      template: (row.template as string) ?? '',
      pathRule: (row.path_rule as VaultConfig['pathRule']) ?? 'category_date',
      conflictStrategy: (row.conflict_strategy as VaultConfig['conflictStrategy']) ?? 'rename',
      autoFrontmatter: Boolean(row.auto_frontmatter),
      frontmatterTemplate: parseJson<Record<string, unknown>>(row.frontmatter_template as string, {}),
    };
  }

  updateVaultConfig(config: Partial<VaultConfig>): void {
    if (!this._db || !this.stmtUpdateVaultConfig) {
      return;
    }
    this.getVaultConfig(); // ensure row exists

    this.stmtUpdateVaultConfig.run({
      vault_path: config.vaultPath ?? '',
      default_folder: config.defaultFolder ?? 'Inbox',
      template: config.template ?? '',
      path_rule: config.pathRule ?? 'category_date',
      conflict_strategy: config.conflictStrategy ?? 'rename',
      auto_frontmatter: config.autoFrontmatter !== undefined ? (config.autoFrontmatter ? 1 : 0) : 1,
      frontmatter_template: config.frontmatterTemplate ? JSON.stringify(config.frontmatterTemplate) : '{}',
    });

    logger.info('app', 'storage', 'updateVaultConfig', 'VaultConfig updated');
  }

  // -------------------------------------------------------------------------
  // Storage statistics
  // -------------------------------------------------------------------------

  getStorageStats(): StorageStats {
    if (!this._db) {
      return { sourceItems: 0, aiTasks: 0, distilledOutputs: 0, exportRecords: 0 };
    }
    const db = this._db!;
    const sourceItems = (
      db.prepare('SELECT COUNT(*) as count FROM source_items').get() as { count: number }
    ).count;
    const aiTasks = (
      db.prepare('SELECT COUNT(*) as count FROM ai_tasks').get() as { count: number }
    ).count;
    const distilledOutputs = (
      db.prepare('SELECT COUNT(*) as count FROM distilled_outputs').get() as { count: number }
    ).count;
    const exportRecords = (
      db.prepare('SELECT COUNT(*) as count FROM export_records').get() as { count: number }
    ).count;

    return { sourceItems, aiTasks, distilledOutputs, exportRecords };
  }

  // -------------------------------------------------------------------------
  // Utility
  // -------------------------------------------------------------------------

  getDbPath(): string {
    return this.dbPathValue!;
  }

  getSourceItemByHash(hash: string): SourceItem | null {
    const row = this._db!
      .prepare('SELECT * FROM source_items WHERE content_hash = ? LIMIT 1')
      .get(hash) as Record<string, unknown> | undefined;
    return row ? this.rowToSourceItem(row) : null;
  }

  // -------------------------------------------------------------------------
  // ImportTask CRUD
  // -------------------------------------------------------------------------

  insertImportTask(task: ImportTask): void {
    this.stmtInsertImportTask.run({
      id: task.id,
      vault_path: task.vaultPath,
      folder_path: task.folderPath,
      status: task.status,
      total_files: task.totalFiles,
      imported_count: task.importedCount,
      skipped_count: task.skippedCount,
      failed_count: task.failedCount,
      exclude_patterns: JSON.stringify(task.excludePatterns),
      include_patterns: JSON.stringify(task.includePatterns),
      created_at: task.createdAt,
      started_at: task.startedAt ?? null,
      finished_at: task.finishedAt ?? null,
      error: task.error ?? null,
    });

    logger.info('export', 'storage', 'insertImportTask', `ImportTask created: ${task.id}`);
  }

  getImportTask(id: string): ImportTask | null {
    const row = this.stmtGetImportTask.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToImportTask(row) : null;
  }

  updateImportTask(id: string, patch: Partial<ImportTask>): void {
    const existing = this.getImportTask(id);
    if (!existing) {
      throw new Error(`ImportTask not found: ${id}`);
    }

    const merged: ImportTask = { ...existing, ...patch, id };

    this.stmtUpdateImportTask.run({
      id: merged.id,
      status: merged.status,
      total_files: merged.totalFiles,
      imported_count: merged.importedCount,
      skipped_count: merged.skippedCount,
      failed_count: merged.failedCount,
      started_at: merged.startedAt ?? null,
      finished_at: merged.finishedAt ?? null,
      error: merged.error ?? null,
    });
  }

  getImportTasks(filter?: { limit?: number }): ImportTask[] {
    const db = this._db!;
    let sql = 'SELECT * FROM import_tasks';
    const params: unknown[] = [];

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToImportTask);
  }

  // -------------------------------------------------------------------------
  // Row-to-model mappers
  // -------------------------------------------------------------------------

  private rowToSourceItem(row: Record<string, unknown>): SourceItem {
    return {
      id: row.id as string,
      captureItemId: (row.capture_item_id as string) ?? undefined,
      type: row.type as SourceItem['type'],
      source: row.source as SourceItem['source'],
      contentPath: row.content_path as string,
      contentHash: (row.content_hash as string) ?? undefined,
      previewText: (row.preview_text as string) ?? undefined,
      ocrText: (row.ocr_text as string) ?? undefined,
      sourceApp: (row.source_app as string) ?? undefined,
      originalUrl: (row.original_url as string) ?? undefined,
      createdAt: row.created_at as number,
      status: row.status as SourceItemStatus,
      title: (row.title as string) ?? undefined,
      tags: parseJson<string[] | undefined>(row.tags as string, undefined),
      vaultImportPath: (row.vault_import_path as string) ?? undefined,
      originalId: (row.original_id as string) ?? undefined,
      metadata: parseJson<Record<string, unknown> | undefined>(row.metadata as string, undefined),
      filePath: (row.file_path as string) ?? undefined,
      thumbnailPath: (row.thumbnail_path as string) ?? undefined,
      updatedAt: (row.updated_at as number) ?? undefined,
      fileSize: (row.file_size as number) ?? undefined,
      mimeType: (row.mime_type as string) ?? undefined,
    };
  }

  private rowToAiTask(row: Record<string, unknown>): AiTask {
    return {
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      tier: row.tier as AiTask['tier'],
      operation: row.operation as AiTask['operation'],
      status: row.status as AiTaskStatus,
      provider: row.provider as string,
      model: row.model as string,
      input: parseJson<Record<string, unknown>>(row.input as string, {}),
      output: parseJson<Record<string, unknown> | undefined>(row.output as string, undefined),
      error: (row.error as string) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: (row.updated_at as number) ?? (row.created_at as number),
      startedAt: (row.started_at as number) ?? undefined,
      finishedAt: (row.finished_at as number) ?? undefined,
      latencyMs: (row.latency_ms as number) ?? undefined,
    };
  }

  private rowToDistilledOutput(row: Record<string, unknown>): DistilledOutput {
    return {
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      taskId: row.task_id as string,
      operation: (row.operation as import('../shared/types').AiOperation) ?? undefined,
      suggestedTitle: (row.suggested_title as string) ?? undefined,
      summary: (row.summary as string) ?? undefined,
      category: (row.category as string) ?? undefined,
      tags: parseJson<string[] | undefined>(row.tags as string, undefined),
      documentType: (row.document_type as DistilledOutput['documentType']) ?? undefined,
      contentMarkdown: (row.content_markdown as string) ?? undefined,
      valueScore: (row.value_score as number) ?? undefined,
      cleanSuggestion: (row.clean_suggestion as DistilledOutput['cleanSuggestion']) ?? undefined,
      confidence: (row.confidence as number) ?? undefined,
      reviewStatus: (row.review_status as DistilledOutput['reviewStatus']) ?? 'pending',
      reviewedAt: (row.reviewed_at as number) ?? undefined,
      acceptedKnowledgeCardId: (row.accepted_knowledge_card_id as string) ?? undefined,
      createdAt: row.created_at as number,
    };
  }

  private rowToExportRecord(row: Record<string, unknown>): ExportRecord {
    return {
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      distilledOutputId: row.distilled_output_id as string,
      knowledgeCardId: (row.knowledge_card_id as string) ?? undefined,
      vaultPath: row.vault_path as string,
      relativeFilePath: row.relative_file_path as string,
      frontmatter: parseJson<Record<string, unknown>>(row.frontmatter as string, {}),
      exportedAt: row.exported_at as number,
      status: row.status as ExportRecord['status'],
      conflictResolution: (row.conflict_resolution as ExportRecord['conflictResolution']) ?? undefined,
    };
  }

  private rowToKnowledgeCard(row: Record<string, unknown>): KnowledgeCard {
    return {
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      distilledOutputId: (row.distilled_output_id as string) ?? undefined,
      canonicalTitle: row.canonical_title as string,
      summary: (row.summary as string) ?? undefined,
      category: (row.category as string) ?? undefined,
      tags: parseJson<string[]>(row.tags as string, []),
      body: (row.body as string) ?? undefined,
      status: row.status as KnowledgeCard['status'],
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  private rowToKnowledgeEdge(row: Record<string, unknown>): KnowledgeEdge {
    return {
      id: row.id as string,
      fromKnowledgeCardId: row.from_knowledge_card_id as string,
      toKnowledgeCardId: row.to_knowledge_card_id as string,
      relationType: row.relation_type as KnowledgeEdge['relationType'],
      status: row.status as KnowledgeEdge['status'],
      confidence: (row.confidence as number) ?? undefined,
      reason: (row.reason as string) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  private rowToReviewEvent(row: Record<string, unknown>): ReviewEvent {
    return {
      id: row.id as string,
      sourceItemId: row.source_item_id as string,
      distilledOutputId: row.distilled_output_id as string,
      knowledgeCardId: (row.knowledge_card_id as string) ?? undefined,
      action: row.action as ReviewEvent['action'],
      before: parseJson<Record<string, unknown>>(row.before as string, {}),
      after: parseJson<Record<string, unknown>>(row.after as string, {}),
      actor: row.actor as ReviewEvent['actor'],
      provider: (row.provider as string) ?? undefined,
      model: (row.model as string) ?? undefined,
      taskId: (row.task_id as string) ?? undefined,
      createdAt: row.created_at as number,
    };
  }

  private rowToTrainingExample(row: Record<string, unknown>): TrainingExample {
    return {
      id: row.id as string,
      capability: row.capability as TrainingExample['capability'],
      sourceItemId: row.source_item_id as string,
      distilledOutputId: (row.distilled_output_id as string) ?? undefined,
      knowledgeCardId: (row.knowledge_card_id as string) ?? undefined,
      input: parseJson<Record<string, unknown>>(row.input as string, {}),
      teacherOutput: parseJson<Record<string, unknown>>(row.teacher_output as string, {}),
      targetOutput: parseJson<Record<string, unknown>>(row.target_output as string, {}),
      metadata: parseJson<Record<string, unknown>>(row.metadata as string, {}),
      createdAt: row.created_at as number,
    };
  }

  private rowToDatasetSnapshot(row: Record<string, unknown>): DatasetSnapshot {
    return {
      id: row.id as string,
      name: row.name as string,
      description: (row.description as string) ?? undefined,
      manifestPath: row.manifest_path as string,
      splitConfig: parseJson<Record<string, unknown>>(row.split_config as string, {}),
      counts: parseJson<Record<string, number>>(row.counts as string, {}),
      status: row.status as DatasetSnapshot['status'],
      createdAt: row.created_at as number,
      frozenAt: (row.frozen_at as number) ?? undefined,
    };
  }

  private rowToTrainingRun(row: Record<string, unknown>): TrainingRun {
    return {
      id: row.id as string,
      snapshotId: row.snapshot_id as string,
      baseModel: row.base_model as string,
      status: row.status as TrainingRun['status'],
      manifestPath: (row.manifest_path as string) ?? undefined,
      artifactPath: (row.artifact_path as string) ?? undefined,
      metrics: parseJson<Record<string, unknown>>(row.metrics as string, {}),
      error: (row.error as string) ?? undefined,
      createdAt: row.created_at as number,
      finishedAt: (row.finished_at as number) ?? undefined,
    };
  }

  private rowToEvalRun(row: Record<string, unknown>): EvalRun {
    return {
      id: row.id as string,
      snapshotId: row.snapshot_id as string,
      trainingRunId: (row.training_run_id as string) ?? undefined,
      modelVersionId: (row.model_version_id as string) ?? undefined,
      metrics: parseJson<Record<string, unknown>>(row.metrics as string, {}),
      createdAt: row.created_at as number,
    };
  }

  private rowToModelVersion(row: Record<string, unknown>): ModelVersion {
    return {
      id: row.id as string,
      name: row.name as string,
      baseModel: row.base_model as string,
      artifactPath: row.artifact_path as string,
      modelfilePath: (row.modelfile_path as string) ?? undefined,
      provider: row.provider as ModelVersion['provider'],
      status: row.status as ModelVersion['status'],
      notes: (row.notes as string) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  private rowToProviderConfig(row: Record<string, unknown>): ProviderConfig {
    return {
      id: row.id as string,
      name: row.name as string,
      type: row.type as ProviderConfig['type'],
      tier: row.tier as ProviderConfig['tier'],
      baseUrl: row.base_url as string,
      apiKey: (row.api_key as string) ?? undefined,
      modelId: row.model_id as string,
      enabled: Boolean(row.enabled),
      capabilities: parseJson<string[]>(row.capabilities as string, []),
    };
  }

  private rowToImportTask(row: Record<string, unknown>): ImportTask {
    return {
      id: row.id as string,
      vaultPath: row.vault_path as string,
      folderPath: row.folder_path as string,
      status: row.status as ImportTask['status'],
      totalFiles: row.total_files as number,
      importedCount: row.imported_count as number,
      skippedCount: row.skipped_count as number,
      failedCount: row.failed_count as number,
      excludePatterns: parseJson<string[]>(row.exclude_patterns as string, []),
      includePatterns: parseJson<string[]>(row.include_patterns as string, []),
      createdAt: row.created_at as number,
      startedAt: (row.started_at as number) ?? undefined,
      finishedAt: (row.finished_at as number) ?? undefined,
      error: (row.error as string) ?? undefined,
    };
  }

  // -------------------------------------------------------------------------
  // CaptureItem CRUD (Capture Inbox v0.1)
  // -------------------------------------------------------------------------

  getCaptureItems(filter?: CaptureItemListFilter): CaptureItem[] {
    const db = this._db!;
    let sql = 'SELECT * FROM capture_items';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.type) {
      conditions.push('type = ?');
      params.push(filter.type);
    }
    if (filter?.todayOnly) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      const todayStartSec = Math.floor(todayStart.getTime() / 1000);
      conditions.push('captured_at >= ?');
      params.push(todayStartSec);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY captured_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
      if (filter?.offset) {
        sql += ' OFFSET ?';
        params.push(filter.offset);
      }
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToCaptureItem);
  }

  getCaptureItem(id: string): CaptureItem | null {
    const row = this.stmtGetCaptureItem.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToCaptureItem(row) : null;
  }

  insertCaptureItem(item: CaptureItem): void {
    this.stmtInsertCaptureItem.run({
      id: item.id,
      type: item.type,
      status: item.status,
      title: item.title,
      raw_text: item.rawText,
      source_url: item.sourceUrl,
      file_path: item.filePath,
      user_note: item.userNote,
      captured_at: item.capturedAt,
      updated_at: item.updatedAt,
    });

    logger.info('app', 'storage', 'insertCaptureItem', `CaptureItem created: ${item.id}`, {
      type: item.type,
      status: item.status,
    });
  }

  updateCaptureItem(id: string, patch: Partial<CaptureItem>): void {
    const existing = this.getCaptureItem(id);
    if (!existing) {
      throw new Error(`CaptureItem not found: ${id}`);
    }

    const merged: CaptureItem = {
      ...existing,
      ...patch,
      id,
      updatedAt: Math.floor(Date.now() / 1000),
    };

    this.stmtUpdateCaptureItem.run({
      id: merged.id,
      type: merged.type,
      status: merged.status,
      title: merged.title,
      raw_text: merged.rawText,
      source_url: merged.sourceUrl,
      file_path: merged.filePath,
      user_note: merged.userNote,
      captured_at: merged.capturedAt,
      updated_at: merged.updatedAt,
    });

    logger.info('app', 'storage', 'updateCaptureItem', `CaptureItem updated: ${id}`);
  }

  deleteCaptureItem(id: string): void {
    const result = this.stmtDeleteCaptureItem.run(id);
    if (result.changes === 0) {
      throw new Error(`CaptureItem not found: ${id}`);
    }
    logger.info('app', 'storage', 'deleteCaptureItem', `CaptureItem deleted: ${id}`);
  }

  private rowToCaptureItem(row: Record<string, unknown>): CaptureItem {
    return {
      id: row.id as string,
      type: row.type as CaptureItem['type'],
      status: row.status as CaptureItemStatus,
      title: row.title as string,
      rawText: row.raw_text as string,
      sourceUrl: row.source_url as string,
      filePath: row.file_path as string,
      userNote: row.user_note as string,
      capturedAt: row.captured_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  // -------------------------------------------------------------------------
  // Distill Loop: Lineage queries
  // -------------------------------------------------------------------------

  /**
   * Get the full distill lineage for a capture item:
   * CaptureItem -> SourceItem -> AiTasks -> DistilledOutputs -> ExportRecords
   */
  getDistillLineageStatus(captureItemId: string): import('../shared/types').DistillLineageStatus {
    const sourceItem = this.getSourceItemByCaptureItemId(captureItemId);
    const bridgeExists = sourceItem !== null;

    let aiTasks: import('../shared/types').AiTask[] = [];
    let distilledOutputs: import('../shared/types').DistilledOutput[] = [];
    let exportRecords: import('../shared/types').ExportRecord[] = [];

    if (sourceItem) {
      aiTasks = this.getAiTasks({ sourceItemId: sourceItem.id });
      distilledOutputs = this.getDistilledOutputs({ sourceItemId: sourceItem.id });

      // Get export records for all distilled outputs of this source item
      if (distilledOutputs.length > 0) {
        const outputIds = distilledOutputs.map((o) => o.id);
        const allRecords = this.getExportRecords({});
        exportRecords = allRecords.filter((r) => outputIds.includes(r.distilledOutputId));
      }
    }

    return {
      captureItemId,
      sourceItemId: sourceItem?.id ?? null,
      sourceItemStatus: sourceItem?.status ?? null,
      aiTasks,
      distilledOutputs,
      exportRecords,
      bridgeExists,
    };
  }

  /**
   * Get export record with full lineage (SourceItem + DistilledOutput).
   */
  getExportRecordWithLineage(recordId: string): {
    record: import('../shared/types').ExportRecord | null;
    sourceItem: import('../shared/types').SourceItem | null;
    distilledOutput: import('../shared/types').DistilledOutput | null;
  } {
    const allRecords = this.getExportRecords({});
    const record = allRecords.find((r) => r.id === recordId) ?? null;

    if (!record) {
      return { record: null, sourceItem: null, distilledOutput: null };
    }

    const distilledOutput = this.getDistilledOutputs({}).find((o) => o.id === record.distilledOutputId) ?? null;
    const sourceItem = record.sourceItemId ? this.getSourceItem(record.sourceItemId) : null;

    return { record, sourceItem, distilledOutput };
  }

  /**
   * Get all export records with lineage data.
   */
  getExportRecordsWithLineage(filter?: { sourceItemId?: string; status?: string; limit?: number }): Array<{
    record: import('../shared/types').ExportRecord;
    sourceItem: import('../shared/types').SourceItem | null;
    distilledOutput: import('../shared/types').DistilledOutput | null;
  }> {
    const records = this.getExportRecords(filter);
    return records.map((record) => {
      const distilledOutput = this.getDistilledOutputs({}).find((o) => o.id === record.distilledOutputId) ?? null;
      const sourceItem = record.sourceItemId ? this.getSourceItem(record.sourceItemId) : null;
      return { record, sourceItem, distilledOutput };
    });
  }

  /**
   * Get distilled outputs with review status filter.
   */
  getDistilledOutputsWithReviewStatus(filter?: { sourceItemId?: string; reviewStatus?: string; limit?: number }): DistilledOutput[] {
    const db = this._db!;
    let sql = 'SELECT * FROM distilled_outputs';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.sourceItemId) {
      conditions.push('source_item_id = ?');
      params.push(filter.sourceItemId);
    }
    if (filter?.reviewStatus) {
      conditions.push('review_status = ?');
      params.push(filter.reviewStatus);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToDistilledOutput);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase 0: AcMind 新表 CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── AssetFile ──────────────────────────────────────────────

  insertAssetFile(file: AssetFile): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO asset_files (id, source_item_id, kind, original_name, local_path, mime_type, size_bytes, sha256, created_at, metadata)
      VALUES (@id, @source_item_id, @kind, @original_name, @local_path, @mime_type, @size_bytes, @sha256, @created_at, @metadata)
    `).run({
      id: file.id,
      source_item_id: file.sourceItemId ?? null,
      kind: file.kind,
      original_name: file.originalName ?? null,
      local_path: file.localPath,
      mime_type: file.mimeType ?? null,
      size_bytes: file.sizeBytes ?? null,
      sha256: file.sha256 ?? null,
      created_at: file.createdAt,
      metadata: file.metadata ? JSON.stringify(file.metadata) : null,
    });
  }

  getAssetFile(id: string): AssetFile | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM asset_files WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToAssetFile(row) : null;
  }

  listAssetFilesBySourceItem(sourceItemId: string): AssetFile[] {
    const db = this._db!;
    const rows = db.prepare('SELECT * FROM asset_files WHERE source_item_id = ? ORDER BY created_at DESC').all(sourceItemId) as Record<string, unknown>[];
    return rows.map(this.rowToAssetFile);
  }

  deleteAssetFile(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM asset_files WHERE id = ?').run(id);
  }

  updateAssetFileSourceItemId(id: string, sourceItemId: string): void {
    const db = this._db!;
    db.prepare('UPDATE asset_files SET source_item_id = ? WHERE id = ?').run(sourceItemId, id);
  }

  private rowToAssetFile(row: Record<string, unknown>): AssetFile {
    return {
      id: row.id as string,
      sourceItemId: (row.source_item_id as string) ?? undefined,
      kind: row.kind as AssetFile['kind'],
      originalName: (row.original_name as string) ?? undefined,
      localPath: row.local_path as string,
      mimeType: (row.mime_type as string) ?? undefined,
      sizeBytes: (row.size_bytes as number) ?? undefined,
      sha256: (row.sha256 as string) ?? undefined,
      createdAt: row.created_at as number,
      metadata: parseJson(row.metadata as string | null, undefined),
    };
  }

  // ─── ClipboardItem ──────────────────────────────────────────

  insertClipboardItem(item: ClipboardItem): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO clipboard_items (id, source_item_id, content_type, text, asset_file_ids, source_app, is_sensitive, is_pinned, created_at)
      VALUES (@id, @source_item_id, @content_type, @text, @asset_file_ids, @source_app, @is_sensitive, @is_pinned, @created_at)
    `).run({
      id: item.id,
      source_item_id: item.sourceItemId ?? null,
      content_type: item.contentType,
      text: item.text ?? null,
      asset_file_ids: item.assetFileIds ? JSON.stringify(item.assetFileIds) : null,
      source_app: item.sourceApp ?? null,
      is_sensitive: item.isSensitive ? 1 : 0,
      is_pinned: item.isPinned ? 1 : 0,
      created_at: item.createdAt,
    });
  }

  getClipboardItem(id: string): ClipboardItem | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM clipboard_items WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToClipboardItem(row) : null;
  }

  listClipboardItems(limit = 100, offset = 0): ClipboardItem[] {
    const db = this._db!;
    const rows = db.prepare('SELECT * FROM clipboard_items ORDER BY created_at DESC LIMIT ? OFFSET ?').all(limit, offset) as Record<string, unknown>[];
    return rows.map(this.rowToClipboardItem);
  }

  updateClipboardItemPinned(id: string, pinned: boolean): void {
    const db = this._db!;
    db.prepare('UPDATE clipboard_items SET is_pinned = ? WHERE id = ?').run(pinned ? 1 : 0, id);
  }

  deleteClipboardItem(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM clipboard_items WHERE id = ?').run(id);
  }

  searchClipboardItems(query: string, contentType?: string): ClipboardItem[] {
    const db = this._db!;
    const pattern = `%${query}%`;
    if (contentType && contentType !== 'all') {
      const rows = db.prepare(
        'SELECT * FROM clipboard_items WHERE content_type = ? AND text LIKE ? ORDER BY created_at DESC LIMIT 100',
      ).all(contentType, pattern) as Record<string, unknown>[];
      return rows.map(this.rowToClipboardItem);
    }
    const rows = db.prepare(
      'SELECT * FROM clipboard_items WHERE text LIKE ? ORDER BY created_at DESC LIMIT 100',
    ).all(pattern) as Record<string, unknown>[];
    return rows.map(this.rowToClipboardItem);
  }

  clearClipboardItems(): void {
    const db = this._db!;
    db.prepare('DELETE FROM clipboard_items WHERE is_pinned = 0').run();
  }

  updateClipboardItemSourceItemId(id: string, sourceItemId: string): void {
    const db = this._db!;
    db.prepare('UPDATE clipboard_items SET source_item_id = ? WHERE id = ?').run(sourceItemId, id);
  }

  private rowToClipboardItem(row: Record<string, unknown>): ClipboardItem {
    return {
      id: row.id as string,
      sourceItemId: (row.source_item_id as string) ?? undefined,
      contentType: row.content_type as ClipboardItem['contentType'],
      text: (row.text as string) ?? undefined,
      assetFileIds: parseJson(row.asset_file_ids as string | null, undefined),
      sourceApp: (row.source_app as string) ?? undefined,
      isSensitive: (row.is_sensitive as number) === 1,
      isPinned: (row.is_pinned as number) === 1,
      createdAt: row.created_at as number,
    };
  }

  // ─── ShelfItem ──────────────────────────────────────────────

  insertShelfItem(item: ShelfItem): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO shelf_items (id, source_item_id, asset_file_ids, label, origin, status, created_at, updated_at)
      VALUES (@id, @source_item_id, @asset_file_ids, @label, @origin, @status, @created_at, @updated_at)
    `).run({
      id: item.id,
      source_item_id: item.sourceItemId ?? null,
      asset_file_ids: JSON.stringify(item.assetFileIds),
      label: item.label ?? null,
      origin: item.origin ?? null,
      status: item.status,
      created_at: item.createdAt,
      updated_at: item.updatedAt,
    });
  }

  getShelfItem(id: string): ShelfItem | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM shelf_items WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToShelfItem(row) : null;
  }

  listShelfItems(status?: ShelfItem['status']): ShelfItem[] {
    const db = this._db!;
    let sql = 'SELECT * FROM shelf_items';
    const params: unknown[] = [];
    if (status) {
      sql += ' WHERE status = ?';
      params.push(status);
    }
    sql += ' ORDER BY created_at DESC';
    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToShelfItem);
  }

  updateShelfItemStatus(id: string, status: ShelfItem['status']): void {
    const db = this._db!;
    db.prepare('UPDATE shelf_items SET status = ?, updated_at = unixepoch() WHERE id = ?').run(status, id);
  }

  deleteShelfItem(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM shelf_items WHERE id = ?').run(id);
  }

  updateShelfItemSourceItemId(id: string, sourceItemId: string): void {
    const db = this._db!;
    db.prepare('UPDATE shelf_items SET source_item_id = ?, updated_at = unixepoch() WHERE id = ?').run(sourceItemId, id);
  }

  updateShelfItemLabel(id: string, label: string): void {
    const db = this._db!;
    db.prepare('UPDATE shelf_items SET label = ?, updated_at = unixepoch() WHERE id = ?').run(label, id);
  }

  private rowToShelfItem(row: Record<string, unknown>): ShelfItem {
    return {
      id: row.id as string,
      sourceItemId: (row.source_item_id as string) ?? undefined,
      assetFileIds: parseJson(row.asset_file_ids as string, []),
      label: (row.label as string) ?? undefined,
      origin: (row.origin as ShelfItem['origin']) ?? undefined,
      status: row.status as ShelfItem['status'],
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  // ─── AIAction ───────────────────────────────────────────────

  insertAIAction(action: AIAction): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO ai_actions (id, name, input_types, action_type, prompt_profile_id, enabled, created_at, updated_at)
      VALUES (@id, @name, @input_types, @action_type, @prompt_profile_id, @enabled, @created_at, @updated_at)
    `).run({
      id: action.id,
      name: action.name,
      input_types: JSON.stringify(action.inputTypes),
      action_type: action.actionType,
      prompt_profile_id: action.promptProfileId ?? null,
      enabled: action.enabled ? 1 : 0,
      created_at: action.createdAt,
      updated_at: action.updatedAt,
    });
  }

  getAIAction(id: string): AIAction | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM ai_actions WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToAIAction(row) : null;
  }

  listAIActions(enabledOnly = false): AIAction[] {
    const db = this._db!;
    let sql = 'SELECT * FROM ai_actions';
    if (enabledOnly) {
      sql += ' WHERE enabled = 1';
    }
    sql += ' ORDER BY created_at DESC';
    const rows = db.prepare(sql).all() as Record<string, unknown>[];
    return rows.map(this.rowToAIAction);
  }

  updateAIAction(action: AIAction): void {
    const db = this._db!;
    db.prepare(`
      UPDATE ai_actions SET
        name = @name, input_types = @input_types, action_type = @action_type,
        prompt_profile_id = @prompt_profile_id, enabled = @enabled, updated_at = @updated_at
      WHERE id = @id
    `).run({
      id: action.id,
      name: action.name,
      input_types: JSON.stringify(action.inputTypes),
      action_type: action.actionType,
      prompt_profile_id: action.promptProfileId ?? null,
      enabled: action.enabled ? 1 : 0,
      updated_at: action.updatedAt,
    });
  }

  deleteAIAction(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM ai_actions WHERE id = ?').run(id);
  }

  private rowToAIAction(row: Record<string, unknown>): AIAction {
    return {
      id: row.id as string,
      name: row.name as string,
      inputTypes: parseJson(row.input_types as string, []),
      actionType: row.action_type as AIAction['actionType'],
      promptProfileId: (row.prompt_profile_id as string) ?? undefined,
      enabled: (row.enabled as number) === 1,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  // ─── Pin Pool (pin_pool_items) ──────────────────────────────

  insertPinItem(pin: PinItem): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO pin_pool_items (id, capture_item_id, original_id, source_type, title, preview_text, raw_text, raw_file_path, status, created_at, pinned_at, updated_at, prefilter_result)
      VALUES (@id, @capture_item_id, @original_id, @source_type, @title, @preview_text, @raw_text, @raw_file_path, @status, @created_at, @pinned_at, @updated_at, @prefilter_result)
    `).run({
      id: pin.id,
      capture_item_id: pin.captureItemId,
      original_id: pin.originalId,
      source_type: pin.sourceType,
      title: pin.title,
      preview_text: pin.previewText ?? null,
      raw_text: pin.rawText ?? null,
      raw_file_path: pin.rawFilePath ?? null,
      status: pin.status,
      created_at: pin.createdAt,
      pinned_at: pin.pinnedAt,
      updated_at: pin.updatedAt,
      prefilter_result: pin.prefilterResult ? JSON.stringify(pin.prefilterResult) : null,
    });
  }

  getPinItem(id: string): PinItem | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM pin_pool_items WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToPinItem(row) : null;
  }

  getPinItemByOriginalId(originalId: string): PinItem | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM pin_pool_items WHERE original_id = ? LIMIT 1').get(originalId) as Record<string, unknown> | undefined;
    return row ? this.rowToPinItem(row) : null;
  }

  listPinItems(filter?: PinItemListFilter): PinItem[] {
    const db = this._db!;
    let sql = 'SELECT * FROM pin_pool_items';
    const conditions: string[] = [];
    const params: unknown[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }
    if (filter?.sourceType) {
      conditions.push('source_type = ?');
      params.push(filter.sourceType);
    }
    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }
    sql += ' ORDER BY created_at DESC';
    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }
    if (filter?.offset) {
      sql += ' OFFSET ?';
      params.push(filter.offset);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map((row) => this.rowToPinItem(row));
  }

  updatePinItem(id: string, patch: Partial<PinItem>): void {
    const db = this._db!;
    const sets: string[] = [];
    const params: Record<string, unknown> = { id, updated_at: Math.floor(Date.now() / 1000) };

    if (patch.status !== undefined) { sets.push('status = @status'); params.status = patch.status; }
    if (patch.title !== undefined) { sets.push('title = @title'); params.title = patch.title; }
    if (patch.previewText !== undefined) { sets.push('preview_text = @preview_text'); params.preview_text = patch.previewText; }
    if (patch.rawText !== undefined) { sets.push('raw_text = @raw_text'); params.raw_text = patch.rawText; }
    if (patch.prefilterResult !== undefined) { sets.push('prefilter_result = @prefilter_result'); params.prefilter_result = JSON.stringify(patch.prefilterResult); }

    sets.push('updated_at = @updated_at');
    db.prepare(`UPDATE pin_pool_items SET ${sets.join(', ')} WHERE id = @id`).run(params);
  }

  deletePinItem(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM pin_pool_items WHERE id = ?').run(id);
  }

  private rowToPinItem(row: Record<string, unknown>): PinItem {
    return {
      id: row.id as string,
      captureItemId: (row.capture_item_id as string) ?? '',
      originalId: (row.original_id as string) ?? '',
      sourceType: (row.source_type as PinItem['sourceType']) ?? 'clipboard_text',
      title: (row.title as string) ?? '',
      previewText: (row.preview_text as string) ?? undefined,
      rawText: (row.raw_text as string) ?? undefined,
      rawFilePath: (row.raw_file_path as string) ?? undefined,
      status: (row.status as PinItem['status']) ?? 'pinned',
      createdAt: row.created_at as number,
      pinnedAt: row.pinned_at as number,
      updatedAt: row.updated_at as number,
      prefilterResult: row.prefilter_result ? parseJson(row.prefilter_result as string, undefined) : undefined,
    };
  }

  // ── ProcessJob CRUD ──────────────────────────────────────────────

  insertProcessJob(job: ProcessJob): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO process_jobs (id, type, source_item_id, asset_file_ids, status, progress, error_message, created_at, updated_at, started_at, completed_at, metadata)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      job.id,
      job.type,
      job.sourceItemId ?? null,
      JSON.stringify(job.assetFileIds ?? []),
      job.status,
      job.progress ?? 0,
      job.errorMessage ?? null,
      job.createdAt,
      job.updatedAt,
      job.startedAt ?? null,
      job.completedAt ?? null,
      job.metadata ? JSON.stringify(job.metadata) : null,
    );
  }

  getProcessJob(id: string): ProcessJob | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM process_jobs WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToProcessJob(row) : null;
  }

  listProcessJobs(filter?: { type?: string; status?: string; limit?: number }): ProcessJob[] {
    const db = this._db!;
    let sql = 'SELECT * FROM process_jobs';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.type) {
      conditions.push('type = ?');
      params.push(filter.type);
    }
    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY created_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToProcessJob);
  }

  updateProcessJob(id: string, patch: Partial<ProcessJob>): void {
    const db = this._db!;
    const sets: string[] = ['updated_at = ?'];
    const params: unknown[] = [Math.floor(Date.now() / 1000)];

    if (patch.status !== undefined) { sets.push('status = ?'); params.push(patch.status); }
    if (patch.progress !== undefined) { sets.push('progress = ?'); params.push(patch.progress); }
    if (patch.errorMessage !== undefined) { sets.push('error_message = ?'); params.push(patch.errorMessage); }
    if (patch.startedAt !== undefined) { sets.push('started_at = ?'); params.push(patch.startedAt); }
    if (patch.completedAt !== undefined) { sets.push('completed_at = ?'); params.push(patch.completedAt); }
    if (patch.sourceItemId !== undefined) { sets.push('source_item_id = ?'); params.push(patch.sourceItemId); }
    if (patch.assetFileIds !== undefined) { sets.push('asset_file_ids = ?'); params.push(JSON.stringify(patch.assetFileIds)); }
    if (patch.metadata !== undefined) { sets.push('metadata = ?'); params.push(JSON.stringify(patch.metadata)); }

    params.push(id);
    db.prepare(`UPDATE process_jobs SET ${sets.join(', ')} WHERE id = ?`).run(...params);
  }

  deleteProcessJob(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM process_jobs WHERE id = ?').run(id);
  }

  // ─── DistilledNote ──────────────────────────────────────────────

  insertDistilledNote(note: DistilledNote): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO distilled_notes (id, source_item_ids, title, summary, tags, suggested_folder, body_markdown, quality_flags, model_provider, model_name, created_at, updated_at, metadata)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      note.id,
      JSON.stringify(note.sourceItemIds ?? []),
      note.title ?? '',
      note.summary ?? '',
      JSON.stringify(note.tags ?? []),
      note.suggestedFolder ?? null,
      note.bodyMarkdown ?? '',
      JSON.stringify(note.qualityFlags ?? []),
      note.modelProvider ?? null,
      note.modelName ?? null,
      note.createdAt,
      note.updatedAt,
      note.metadata ? JSON.stringify(note.metadata) : null,
    );
  }

  getDistilledNote(id: string): DistilledNote | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM distilled_notes WHERE id = ?').get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToDistilledNote(row) : null;
  }

  listDistilledNotes(filter?: { limit?: number; offset?: number }): DistilledNote[] {
    const db = this._db!;
    let sql = 'SELECT * FROM distilled_notes ORDER BY created_at DESC';
    const params: unknown[] = [];

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
    }
    if (filter?.offset) {
      sql += ' OFFSET ?';
      params.push(filter.offset);
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToDistilledNote);
  }

  updateDistilledNote(id: string, patch: Partial<DistilledNote>): void {
    const db = this._db!;
    const sets: string[] = ['updated_at = ?'];
    const params: unknown[] = [Math.floor(Date.now() / 1000)];

    if (patch.title !== undefined) { sets.push('title = ?'); params.push(patch.title); }
    if (patch.summary !== undefined) { sets.push('summary = ?'); params.push(patch.summary); }
    if (patch.tags !== undefined) { sets.push('tags = ?'); params.push(JSON.stringify(patch.tags)); }
    if (patch.suggestedFolder !== undefined) { sets.push('suggested_folder = ?'); params.push(patch.suggestedFolder); }
    if (patch.bodyMarkdown !== undefined) { sets.push('body_markdown = ?'); params.push(patch.bodyMarkdown); }
    if (patch.qualityFlags !== undefined) { sets.push('quality_flags = ?'); params.push(JSON.stringify(patch.qualityFlags)); }
    if (patch.modelProvider !== undefined) { sets.push('model_provider = ?'); params.push(patch.modelProvider); }
    if (patch.modelName !== undefined) { sets.push('model_name = ?'); params.push(patch.modelName); }
    if (patch.sourceItemIds !== undefined) { sets.push('source_item_ids = ?'); params.push(JSON.stringify(patch.sourceItemIds)); }
    if (patch.metadata !== undefined) { sets.push('metadata = ?'); params.push(JSON.stringify(patch.metadata)); }

    params.push(id);
    db.prepare(`UPDATE distilled_notes SET ${sets.join(', ')} WHERE id = ?`).run(...params);
  }

  deleteDistilledNote(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM distilled_notes WHERE id = ?').run(id);
  }

  private rowToDistilledNote(row: Record<string, unknown>): DistilledNote {
    return {
      id: row.id as string,
      sourceItemIds: parseJson(row.source_item_ids as string, []),
      title: (row.title as string) ?? '',
      summary: (row.summary as string) ?? '',
      tags: parseJson(row.tags as string, []),
      suggestedFolder: (row.suggested_folder as string) ?? undefined,
      bodyMarkdown: (row.body_markdown as string) ?? '',
      qualityFlags: parseJson(row.quality_flags as string, []),
      modelProvider: (row.model_provider as string) ?? undefined,
      modelName: (row.model_name as string) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
      metadata: row.metadata ? parseJson(row.metadata as string, undefined) : undefined,
    };
  }

  private rowToProcessJob(row: Record<string, unknown>): ProcessJob {
    return {
      id: row.id as string,
      type: (row.type as ProcessJob['type']) ?? 'markitdown',
      sourceItemId: (row.source_item_id as string) ?? undefined,
      assetFileIds: parseJson(row.asset_file_ids as string, []),
      status: (row.status as ProcessJob['status']) ?? 'queued',
      progress: (row.progress as number) ?? 0,
      errorMessage: (row.error_message as string) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
      startedAt: (row.started_at as number) ?? undefined,
      completedAt: (row.completed_at as number) ?? undefined,
      metadata: row.metadata ? parseJson(row.metadata as string, undefined) : undefined,
    };
  }

  // ─── Batch 6: Knowledge Projects ──────────────────────────────

  createKnowledgeProject(data: { name: string; description?: string; color?: string }): { id: string } {
    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    this.db!.prepare(
      'INSERT INTO knowledge_projects (id, name, description, status, color, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).run(id, data.name, data.description || null, 'active', data.color || null, now, now);
    return { id };
  }

  listKnowledgeProjects(): any[] {
    return (this.db!.prepare('SELECT * FROM knowledge_projects ORDER BY updated_at DESC').all() as any[]).map(row => ({
      id: row.id,
      name: row.name,
      description: row.description,
      status: row.status,
      color: row.color,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
  }

  updateKnowledgeProject(data: { id: string; name?: string; description?: string; status?: string; color?: string }): void {
    const sets: string[] = ['updated_at = ?'];
    const vals: any[] = [Math.floor(Date.now() / 1000)];
    if (data.name !== undefined) { sets.push('name = ?'); vals.push(data.name); }
    if (data.description !== undefined) { sets.push('description = ?'); vals.push(data.description); }
    if (data.status !== undefined) { sets.push('status = ?'); vals.push(data.status); }
    if (data.color !== undefined) { sets.push('color = ?'); vals.push(data.color); }
    vals.push(data.id);
    this.db!.prepare(`UPDATE knowledge_projects SET ${sets.join(', ')} WHERE id = ?`).run(...vals);
  }

  deleteKnowledgeProject(id: string): void {
    this.db!.prepare('DELETE FROM project_items WHERE project_id = ?').run(id);
    this.db!.prepare('DELETE FROM knowledge_projects WHERE id = ?').run(id);
  }

  addProjectItem(data: { projectId: string; itemType: string; itemId: string }): void {
    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    this.db!.prepare(
      'INSERT OR IGNORE INTO project_items (id, project_id, item_type, item_id, added_at) VALUES (?, ?, ?, ?, ?)'
    ).run(id, data.projectId, data.itemType, data.itemId, now);
  }

  removeProjectItem(data: { projectId: string; itemId: string }): void {
    this.db!.prepare('DELETE FROM project_items WHERE project_id = ? AND item_id = ?').run(data.projectId, data.itemId);
  }

  // ─── Batch 6: Tags ────────────────────────────────────────────

  listTagSummaries(): any[] {
    const tags: Map<string, { count: number; sources: Set<string> }> = new Map();
    const addTags = (jsonStr: string | null, source: string) => {
      if (!jsonStr) return;
      try {
        const arr = JSON.parse(jsonStr);
        if (Array.isArray(arr)) {
          for (const t of arr) {
            if (typeof t === 'string' && t.trim()) {
              const existing = tags.get(t.trim()) || { count: 0, sources: new Set<string>() };
              existing.count++;
              existing.sources.add(source);
              tags.set(t.trim(), existing);
            }
          }
        }
      } catch { /* ignore */ }
    };
    for (const row of this.db!.prepare('SELECT tags FROM distilled_outputs WHERE tags IS NOT NULL').all() as any[]) {
      addTags(row.tags, 'distilled_output');
    }
    for (const row of this.db!.prepare('SELECT tags FROM knowledge_cards WHERE tags IS NOT NULL').all() as any[]) {
      addTags(row.tags, 'knowledge_card');
    }
    return Array.from(tags.entries()).map(([name, data]) => ({
      name,
      count: data.count,
      sources: Array.from(data.sources),
    })).sort((a, b) => b.count - a.count);
  }

  renameTag(data: { oldName: string; newName: string }): number {
    let total = 0;
    const tables = ['distilled_outputs', 'knowledge_cards'];
    for (const table of tables) {
      const rows = this.db!.prepare(`SELECT id, tags FROM ${table} WHERE tags LIKE ?`).run(`%"${data.oldName}"%`);
      const all = this.db!.prepare(`SELECT id, tags FROM ${table} WHERE tags LIKE ?`).all(`%"${data.oldName}"%`) as any[];
      for (const row of all) {
        try {
          const arr = JSON.parse(row.tags);
          const newArr = arr.map((t: string) => t === data.oldName ? data.newName : t);
          this.db!.prepare(`UPDATE ${table} SET tags = ? WHERE id = ?`).run(JSON.stringify(newArr), row.id);
          total++;
        } catch { /* skip */ }
      }
    }
    return total;
  }

  deleteTag(name: string): number {
    let total = 0;
    const tables = ['distilled_outputs', 'knowledge_cards'];
    for (const table of tables) {
      const all = this.db!.prepare(`SELECT id, tags FROM ${table} WHERE tags LIKE ?`).all(`%"${name}"%`) as any[];
      for (const row of all) {
        try {
          const arr: string[] = JSON.parse(row.tags);
          const newArr = arr.filter((t: string) => t !== name);
          this.db!.prepare(`UPDATE ${table} SET tags = ? WHERE id = ?`).run(JSON.stringify(newArr), row.id);
          total++;
        } catch { /* skip */ }
      }
    }
    return total;
  }

  // ─── Batch 6: Datasets ────────────────────────────────────────

  createDataset(data: { name: string; description?: string; purpose?: string }): { id: string } {
    const id = randomUUID();
    const now = Math.floor(Date.now() / 1000);
    this.db!.prepare(
      'INSERT INTO datasets (id, name, description, purpose, status, item_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, 0, ?, ?)'
    ).run(id, data.name, data.description || null, data.purpose || 'archive', 'draft', now, now);
    return { id };
  }

  listDatasets(): any[] {
    return (this.db!.prepare('SELECT * FROM datasets ORDER BY updated_at DESC').all() as any[]).map(row => ({
      id: row.id,
      name: row.name,
      description: row.description,
      purpose: row.purpose,
      status: row.status,
      itemCount: row.item_count,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    }));
  }

  getDataset(id: string): any | null {
    const row = this.db!.prepare('SELECT * FROM datasets WHERE id = ?').get(id) as any;
    if (!row) return null;
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      purpose: row.purpose,
      status: row.status,
      itemCount: row.item_count,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  addDatasetItems(data: { datasetId: string; items: Array<{ sourceType: string; sourceId: string }> }): number {
    const now = Math.floor(Date.now() / 1000);
    let count = 0;
    for (const item of data.items) {
      const id = randomUUID();
      let title = '';
      let content = '';
      if (item.sourceType === 'distilled_output') {
        const output = this.db!.prepare('SELECT suggested_title, content_markdown FROM distilled_outputs WHERE id = ?').get(item.sourceId) as any;
        if (output) { title = output.suggested_title || ''; content = output.content_markdown || ''; }
      } else {
        const si = this.db!.prepare('SELECT title, preview_text FROM source_items WHERE id = ?').get(item.sourceId) as any;
        if (si) { title = si.title || ''; content = si.preview_text || ''; }
      }
      this.db!.prepare(
        'INSERT OR IGNORE INTO dataset_items (id, dataset_id, source_type, source_id, title, content, quality, privacy_level, included, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ).run(id, data.datasetId, item.sourceType, item.sourceId, title, content, 'medium', 'private', true, now, now);
      count++;
    }
    this.db!.prepare('UPDATE datasets SET item_count = (SELECT COUNT(*) FROM dataset_items WHERE dataset_id = ?), updated_at = ? WHERE id = ?')
      .run(data.datasetId, now, data.datasetId);
    return count;
  }

  updateDatasetItem(data: { id: string; quality?: string; privacyLevel?: string; included?: boolean; reason?: string }): void {
    const sets: string[] = ['updated_at = ?'];
    const vals: any[] = [Math.floor(Date.now() / 1000)];
    if (data.quality !== undefined) { sets.push('quality = ?'); vals.push(data.quality); }
    if (data.privacyLevel !== undefined) { sets.push('privacy_level = ?'); vals.push(data.privacyLevel); }
    if (data.included !== undefined) { sets.push('included = ?'); vals.push(data.included ? 1 : 0); }
    if (data.reason !== undefined) { sets.push('reason = ?'); vals.push(data.reason); }
    vals.push(data.id);
    this.db!.prepare(`UPDATE dataset_items SET ${sets.join(', ')} WHERE id = ?`).run(...vals);
  }

  deleteDataset(id: string): void {
    this.db!.prepare('DELETE FROM dataset_items WHERE dataset_id = ?').run(id);
    this.db!.prepare('DELETE FROM datasets WHERE id = ?').run(id);
  }

  async exportDataset(data: { datasetId: string; format: string; includeExcluded?: boolean }): Promise<{ path: string; count: number }> {
    const items = this.db!.prepare(
      `SELECT * FROM dataset_items WHERE dataset_id = ?${data.includeExcluded ? '' : ' AND included = 1'}`
    ).all(data.datasetId) as any[];

    const fs = await import('fs');
    const path = await import('path');
    const os = await import('os');
    const exportDir = path.join(os.tmpdir(), 'acmind-datasets');
    if (!fs.existsSync(exportDir)) fs.mkdirSync(exportDir, { recursive: true });

    const dataset = this.getDataset(data.datasetId);
    const safeName = (dataset?.name || 'dataset').replace(/[^a-zA-Z0-9_\u4e00-\u9fff-]/g, '_');
    const timestamp = new Date().toISOString().slice(0, 10);

    if (data.format === 'jsonl') {
      const filePath = path.join(exportDir, `${safeName}_${timestamp}.jsonl`);
      const lines = items.map(item => JSON.stringify({
        sourceId: item.source_id,
        sourceType: item.source_type,
        title: item.title,
        content: item.content,
        quality: item.quality,
        privacyLevel: item.privacy_level,
        included: Boolean(item.included),
      }));
      fs.writeFileSync(filePath, lines.join('\n'), 'utf-8');
      return { path: filePath, count: items.length };
    } else {
      // markdown bundle
      const dirPath = path.join(exportDir, `${safeName}_${timestamp}`);
      if (!fs.existsSync(dirPath)) fs.mkdirSync(dirPath, { recursive: true });
      for (const item of items) {
        const fileName = `${(item.title || item.source_id).replace(/[^a-zA-Z0-9_\u4e00-\u9fff-]/g, '_').slice(0, 80)}.md`;
        const frontmatter = [
          '---',
          `source_id: ${item.source_id}`,
          `source_type: ${item.source_type}`,
          `quality: ${item.quality}`,
          `privacy: ${item.privacy_level}`,
          '---',
          '',
          `# ${item.title || 'Untitled'}`,
          '',
          item.content || '',
        ].join('\n');
        fs.writeFileSync(path.join(dirPath, fileName), frontmatter, 'utf-8');
      }
      return { path: dirPath, count: items.length };
    }
  }

  // ─── ToolBench: GitHub Projects ──────────────────────────────────

  insertGithubProject(p: {
    id: string; name: string; description: string;
    repoUrl?: string; localPath?: string; launchCommand?: string; docsPath?: string;
    category: string; tags: string[]; status: string;
  }): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO tool_projects (id, name, description, repo_url, local_path, launch_command, docs_path, category, tags_json, status)
      VALUES (@id, @name, @description, @repo_url, @local_path, @launch_command, @docs_path, @category, @tags_json, @status)
    `).run({
      id: p.id, name: p.name, description: p.description,
      repo_url: p.repoUrl ?? null, local_path: p.localPath ?? null,
      launch_command: p.launchCommand ?? null, docs_path: p.docsPath ?? null,
      category: p.category, tags_json: JSON.stringify(p.tags), status: p.status,
    });
  }

  listGithubProjects(): any[] {
    const db = this._db!;
    return (db.prepare('SELECT * FROM tool_projects ORDER BY updated_at DESC').all() as any[]).map(this.rowToGithubProject);
  }

  getGithubProject(id: string): any | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM tool_projects WHERE id = ?').get(id);
    return row ? this.rowToGithubProject(row) : null;
  }

  updateGithubProject(id: string, patch: Record<string, unknown>): void {
    const db = this._db!;
    const allowed = ['name', 'description', 'repo_url', 'local_path', 'launch_command', 'docs_path', 'category', 'tags_json', 'status', 'last_used_at'];
    const sets: string[] = [];
    const values: Record<string, unknown> = { id };
    for (const key of allowed) {
      if (key in patch) {
        const col = key;
        sets.push(`${col} = @${key}`);
        values[key] = key === 'tags_json' && Array.isArray(patch[key]) ? JSON.stringify(patch[key]) : patch[key];
      }
    }
    if (sets.length === 0) return;
    sets.push("updated_at = datetime('now')");
    db.prepare(`UPDATE tool_projects SET ${sets.join(', ')} WHERE id = @id`).run(values);
  }

  deleteGithubProject(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM tool_projects WHERE id = ?').run(id);
  }

  getGithubProjectByLocalPath(localPath: string): any | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM tool_projects WHERE local_path = ?').get(localPath);
    return row ? this.rowToGithubProject(row) : null;
  }

  private rowToGithubProject(row: any): any {
    return {
      id: row.id,
      name: row.name,
      description: row.description,
      repoUrl: row.repo_url,
      localPath: row.local_path,
      launchCommand: row.launch_command,
      docsPath: row.docs_path,
      category: row.category,
      tags: parseJson<string[]>(row.tags_json, []),
      status: row.status,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      lastUsedAt: row.last_used_at,
    };
  }

  // ─── ToolBench: Local Scripts ────────────────────────────────────

  insertLocalScript(s: {
    id: string; name: string; command: string;
    workingDirectory?: string; description: string;
    tags: string[]; safetyLevel: string;
  }): void {
    const db = this._db!;
    db.prepare(`
      INSERT INTO local_script_tools (id, name, command, working_directory, description, tags_json, safety_level)
      VALUES (@id, @name, @command, @working_directory, @description, @tags_json, @safety_level)
    `).run({
      id: s.id, name: s.name, command: s.command,
      working_directory: s.workingDirectory ?? null, description: s.description,
      tags_json: JSON.stringify(s.tags), safety_level: s.safetyLevel,
    });
  }

  listLocalScripts(): any[] {
    const db = this._db!;
    return (db.prepare('SELECT * FROM local_script_tools ORDER BY updated_at DESC').all() as any[]).map(this.rowToLocalScript);
  }

  getLocalScript(id: string): any | null {
    const db = this._db!;
    const row = db.prepare('SELECT * FROM local_script_tools WHERE id = ?').get(id);
    return row ? this.rowToLocalScript(row) : null;
  }

  updateLocalScript(id: string, patch: Record<string, unknown>): void {
    const db = this._db!;
    const allowed = ['name', 'command', 'working_directory', 'description', 'tags_json', 'safety_level', 'last_used_at'];
    const sets: string[] = [];
    const values: Record<string, unknown> = { id };
    for (const key of allowed) {
      if (key in patch) {
        sets.push(`${key} = @${key}`);
        values[key] = key === 'tags_json' && Array.isArray(patch[key]) ? JSON.stringify(patch[key]) : patch[key];
      }
    }
    if (sets.length === 0) return;
    sets.push("updated_at = datetime('now')");
    db.prepare(`UPDATE local_script_tools SET ${sets.join(', ')} WHERE id = @id`).run(values);
  }

  deleteLocalScript(id: string): void {
    const db = this._db!;
    db.prepare('DELETE FROM local_script_tools WHERE id = ?').run(id);
  }

  private rowToLocalScript(row: any): any {
    return {
      id: row.id,
      name: row.name,
      command: row.command,
      workingDirectory: row.working_directory,
      description: row.description,
      tags: parseJson<string[]>(row.tags_json, []),
      safetyLevel: row.safety_level,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
      lastUsedAt: row.last_used_at,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Phase A: Agent Chat CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  // ─── Chat Session ─────────────────────────────────────────────

  insertChatSession(session: import('../shared/types').ChatSession): void {
    this.stmtInsertChatSession.run({
      id: session.id,
      title: session.title,
      provider_id: session.providerId ?? null,
      model_id: session.modelId ?? null,
      status: session.status,
      metadata: JSON.stringify(session.metadata ?? {}),
      created_at: session.createdAt,
      updated_at: session.updatedAt,
    });
  }

  getChatSession(id: string): import('../shared/types').ChatSession | null {
    const row = this.stmtGetChatSession.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToChatSession(row) : null;
  }

  updateChatSession(id: string, patch: Partial<import('../shared/types').ChatSession>): void {
    const existing = this.getChatSession(id);
    if (!existing) return;
    const merged: import('../shared/types').ChatSession = { ...existing, ...patch, id, updatedAt: Math.floor(Date.now() / 1000) };
    this.stmtUpdateChatSession.run({
      id,
      title: merged.title,
      provider_id: merged.providerId ?? null,
      model_id: merged.modelId ?? null,
      status: merged.status,
      metadata: JSON.stringify(merged.metadata ?? {}),
      updated_at: merged.updatedAt,
    });
  }

  deleteChatSession(id: string): void {
    this.stmtDeleteChatSession.run(id);
  }

  listChatSessions(filter?: { status?: string; limit?: number; offset?: number }): import('../shared/types').ChatSession[] {
    const rows = this.stmtListChatSessions.all({
      status: filter?.status ?? 'active',
      limit: filter?.limit ?? 100,
      offset: filter?.offset ?? 0,
    }) as Record<string, unknown>[];
    return rows.map(this.rowToChatSession);
  }

  private rowToChatSession(row: Record<string, unknown>): import('../shared/types').ChatSession {
    return {
      id: row.id as string,
      title: row.title as string,
      providerId: (row.provider_id as string) ?? null,
      modelId: (row.model_id as string) ?? null,
      status: row.status as import('../shared/types').ChatSession['status'],
      metadata: parseJson(row.metadata as string, {}),
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  // ─── Chat Message ─────────────────────────────────────────────

  insertChatMessage(message: import('../shared/types').ChatMessage): void {
    this.stmtInsertChatMessage.run({
      id: message.id,
      session_id: message.sessionId,
      role: message.role,
      content: message.content,
      status: message.status,
      model_id: message.modelId ?? null,
      provider_id: message.providerId ?? null,
      prompt_tokens: message.promptTokens ?? null,
      completion_tokens: message.completionTokens ?? null,
      latency_ms: message.latencyMs ?? null,
      error: message.error ?? null,
      action_proposals: JSON.stringify(message.actionProposals ?? []),
      created_at: message.createdAt,
    });
  }

  getChatMessage(id: string): import('../shared/types').ChatMessage | null {
    const row = this.stmtGetChatMessage.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToChatMessage(row) : null;
  }

  updateChatMessage(id: string, patch: Partial<import('../shared/types').ChatMessage>): void {
    const existing = this.getChatMessage(id);
    if (!existing) return;
    const merged: import('../shared/types').ChatMessage = { ...existing, ...patch, id };
    this.stmtUpdateChatMessage.run({
      id,
      content: merged.content,
      status: merged.status,
      model_id: merged.modelId ?? null,
      provider_id: merged.providerId ?? null,
      prompt_tokens: merged.promptTokens ?? null,
      completion_tokens: merged.completionTokens ?? null,
      latency_ms: merged.latencyMs ?? null,
      error: merged.error ?? null,
      action_proposals: JSON.stringify(merged.actionProposals ?? []),
    });
  }

  listChatMessages(sessionId: string, filter?: { limit?: number }): import('../shared/types').ChatMessage[] {
    const rows = this.stmtListChatMessages.all({
      session_id: sessionId,
      limit: filter?.limit ?? 1000,
    }) as Record<string, unknown>[];
    return rows.map(this.rowToChatMessage);
  }

  private rowToChatMessage(row: Record<string, unknown>): import('../shared/types').ChatMessage {
    return {
      id: row.id as string,
      sessionId: row.session_id as string,
      role: row.role as import('../shared/types').ChatMessage['role'],
      content: row.content as string,
      status: row.status as import('../shared/types').ChatMessage['status'],
      modelId: (row.model_id as string) ?? null,
      providerId: (row.provider_id as string) ?? null,
      promptTokens: (row.prompt_tokens as number) ?? null,
      completionTokens: (row.completion_tokens as number) ?? null,
      latencyMs: (row.latency_ms as number) ?? null,
      error: (row.error as string) ?? null,
      actionProposals: parseJson(row.action_proposals as string, []),
      createdAt: row.created_at as number,
    };
  }

  // ─── Agent Task (Phase C) ─────────────────────────────────────

  insertAgentTask(task: import('../shared/types').AgentTask): void {
    this.stmtInsertAgentTask.run({
      id: task.id,
      session_id: task.sessionId,
      name: task.name,
      status: task.status,
      skill_name: task.skillName ?? null,
      input_params: JSON.stringify(task.inputParams),
      result: task.result ?? null,
      error: task.error ?? null,
      started_at: task.startedAt ?? null,
      completed_at: task.completedAt ?? null,
      created_at: task.createdAt,
      updated_at: task.updatedAt,
    });
  }

  getAgentTask(id: string): import('../shared/types').AgentTask | null {
    const row = this.stmtGetAgentTask.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToAgentTask(row) : null;
  }

  updateAgentTask(id: string, patch: Partial<import('../shared/types').AgentTask>): void {
    const existing = this.getAgentTask(id);
    if (!existing) return;
    const merged: import('../shared/types').AgentTask = { ...existing, ...patch, id, updatedAt: Math.floor(Date.now() / 1000) };
    this.stmtUpdateAgentTask.run({
      id,
      name: merged.name,
      status: merged.status,
      skill_name: merged.skillName ?? null,
      input_params: JSON.stringify(merged.inputParams),
      result: merged.result ?? null,
      error: merged.error ?? null,
      started_at: merged.startedAt ?? null,
      completed_at: merged.completedAt ?? null,
      updated_at: merged.updatedAt,
    });
  }

  deleteAgentTask(id: string): void {
    this.stmtDeleteAgentTask.run(id);
  }

  listAgentTasks(filter?: { status?: string; limit?: number; offset?: number }): import('../shared/types').AgentTask[] {
    const rows = this.stmtListAgentTasks.all({
      status: filter?.status ?? 'pending',
      limit: filter?.limit ?? 100,
      offset: filter?.offset ?? 0,
    }) as Record<string, unknown>[];
    return rows.map(this.rowToAgentTask);
  }

  listAllAgentTasks(filter?: { status?: string; limit?: number; offset?: number }): import('../shared/types').AgentTask[] {
    const db = this._db!;
    let sql = 'SELECT * FROM agent_tasks';
    const params: unknown[] = [];
    const conditions: string[] = [];

    if (filter?.status) {
      conditions.push('status = ?');
      params.push(filter.status);
    }

    if (conditions.length > 0) {
      sql += ' WHERE ' + conditions.join(' AND ');
    }

    sql += ' ORDER BY updated_at DESC';

    if (filter?.limit) {
      sql += ' LIMIT ?';
      params.push(filter.limit);
      if (filter?.offset) {
        sql += ' OFFSET ?';
        params.push(filter.offset);
      }
    }

    const rows = db.prepare(sql).all(...params) as Record<string, unknown>[];
    return rows.map(this.rowToAgentTask);
  }

  private rowToAgentTask(row: Record<string, unknown>): import('../shared/types').AgentTask {
    return {
      id: row.id as string,
      sessionId: row.session_id as string,
      name: row.name as string,
      status: row.status as import('../shared/types').AgentTask['status'],
      skillName: (row.skill_name as string) ?? undefined,
      inputParams: parseJson(row.input_params as string, {}),
      result: (row.result as string) ?? undefined,
      error: (row.error as string) ?? undefined,
      startedAt: (row.started_at as number) ?? undefined,
      completedAt: (row.completed_at as number) ?? undefined,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }

  // ─── Agent Task Event (Phase C) ───────────────────────────────

  insertAgentTaskEvent(event: import('../shared/types').AgentTaskEvent): void {
    this.stmtInsertAgentTaskEvent.run({
      id: event.id,
      task_id: event.taskId,
      event_type: event.eventType,
      description: event.description,
      metadata: JSON.stringify(event.metadata),
      created_at: event.createdAt,
    });
  }

  listAgentTaskEvents(taskId: string, filter?: { limit?: number }): import('../shared/types').AgentTaskEvent[] {
    const rows = this.stmtListAgentTaskEvents.all({
      task_id: taskId,
      limit: filter?.limit ?? 200,
    }) as Record<string, unknown>[];
    return rows.map(this.rowToAgentTaskEvent);
  }

  private rowToAgentTaskEvent(row: Record<string, unknown>): import('../shared/types').AgentTaskEvent {
    return {
      id: row.id as string,
      taskId: row.task_id as string,
      eventType: row.event_type as import('../shared/types').AgentTaskEvent['eventType'],
      description: row.description as string,
      metadata: parseJson(row.metadata as string, {}),
      createdAt: row.created_at as number,
    };
  }

  // ─── Scheduled Agent Task (Phase D) ─────────────────────────────

  insertScheduledAgentTask(task: import('../shared/types').ScheduledAgentTask): void {
    this.stmtInsertScheduledAgentTask.run({
      id: task.id,
      name: task.name,
      cron_expression: task.cronExpression,
      skill_name: task.skillName,
      input_params: JSON.stringify(task.inputParams),
      enabled: task.enabled ? 1 : 0,
      last_run_at: task.lastRunAt ?? null,
      last_run_status: task.lastRunStatus ?? null,
      last_run_task_id: task.lastRunTaskId ?? null,
      created_at: task.createdAt,
      updated_at: task.updatedAt,
    });
  }

  getScheduledAgentTask(id: string): import('../shared/types').ScheduledAgentTask | null {
    const row = this.stmtGetScheduledAgentTask.get(id) as Record<string, unknown> | undefined;
    return row ? this.rowToScheduledAgentTask(row) : null;
  }

  updateScheduledAgentTask(id: string, patch: Partial<import('../shared/types').ScheduledAgentTask>): void {
    const existing = this.getScheduledAgentTask(id);
    if (!existing) return;
    const merged: import('../shared/types').ScheduledAgentTask = { ...existing, ...patch, id, updatedAt: Math.floor(Date.now() / 1000) };
    this.stmtUpdateScheduledAgentTask.run({
      id,
      name: merged.name,
      cron_expression: merged.cronExpression,
      skill_name: merged.skillName,
      input_params: JSON.stringify(merged.inputParams),
      enabled: merged.enabled ? 1 : 0,
      last_run_at: merged.lastRunAt ?? null,
      last_run_status: merged.lastRunStatus ?? null,
      last_run_task_id: merged.lastRunTaskId ?? null,
      updated_at: merged.updatedAt,
    });
  }

  deleteScheduledAgentTask(id: string): void {
    this.stmtDeleteScheduledAgentTask.run(id);
  }

  listScheduledAgentTasks(): import('../shared/types').ScheduledAgentTask[] {
    const rows = this.stmtListScheduledAgentTasks.all() as Record<string, unknown>[];
    return rows.map(this.rowToScheduledAgentTask);
  }

  private rowToScheduledAgentTask(row: Record<string, unknown>): import('../shared/types').ScheduledAgentTask {
    return {
      id: row.id as string,
      name: row.name as string,
      cronExpression: row.cron_expression as string,
      skillName: row.skill_name as string,
      inputParams: parseJson(row.input_params as string, {}),
      enabled: (row.enabled as number) === 1,
      lastRunAt: (row.last_run_at as number) ?? null,
      lastRunStatus: (row.last_run_status as import('../shared/types').ScheduledAgentTask['lastRunStatus']) ?? null,
      lastRunTaskId: (row.last_run_task_id as string) ?? null,
      createdAt: row.created_at as number,
      updatedAt: row.updated_at as number,
    };
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const storage = new StorageService();
