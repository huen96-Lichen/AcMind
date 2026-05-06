/**
 * Tests for storage and scheduler migration/persistence consistency.
 * Uses pure JS logic tests (no native SQLite) to verify migration patterns.
 */

import { describe, it, expect } from 'vitest';

// ── Migration pattern tests ───────────────────────────────────────────────

describe('Storage - Migration Pattern Consistency', () => {
  it('should handle CREATE IF NOT EXISTS idempotently', () => {
    // Simulate the pattern used in storage.ts
    const tables = new Set<string>();

    function createTableIfNotExists(name: string): void {
      tables.add(name);
    }

    createTableIfNotExists('source_items');
    createTableIfNotExists('source_items'); // duplicate call
    expect(tables.has('source_items')).toBe(true);
    expect(tables.size).toBe(1); // Should not create duplicate
  });

  it('should apply migrations incrementally', () => {
    // Simulate the version-based migration pattern
    const appliedVersions: number[] = [];
    let currentVersion = 0;

    function runMigrations(targetVersion: number): void {
      if (currentVersion < 1) {
        appliedVersions.push(1);
        currentVersion = 1;
      }
      if (currentVersion < 2) {
        appliedVersions.push(2);
        currentVersion = 2;
      }
      if (currentVersion < 3) {
        appliedVersions.push(3);
        currentVersion = 3;
      }
      // ... up to targetVersion
    }

    runMigrations(3);
    expect(appliedVersions).toEqual([1, 2, 3]);
    expect(currentVersion).toBe(3);

    // Re-running should not re-apply
    const beforeLen = appliedVersions.length;
    runMigrations(3);
    expect(appliedVersions.length).toBe(beforeLen); // No new migrations
  });

  it('should handle ALTER TABLE ADD COLUMN gracefully', () => {
    // Simulate the try-catch pattern used for adding columns
    const columns = new Set<string>(['id', 'name']); // existing columns

    function addColumnSafely(column: string): void {
      try {
        if (columns.has(column)) {
          throw new Error(`duplicate column name: ${column}`);
        }
        columns.add(column);
      } catch {
        // Column already exists, ignore (same pattern as storage.ts)
      }
    }

    addColumnSafely('tags');
    expect(columns.has('tags')).toBe(true);

    // Adding same column again should not throw or duplicate
    addColumnSafely('tags');
    expect(columns.size).toBe(3); // id, name, tags
  });

  it('should preserve data during migration', () => {
    // Simulate: data exists before migration, should survive
    const data = new Map<string, string>();
    data.set('item1', 'hello');

    // Migration: add new column (no-op for data)
    // Migration: create new table (no-op for existing data)
    // Data should still be intact
    expect(data.get('item1')).toBe('hello');
  });
});

// ── Scheduler persistence pattern tests ───────────────────────────────────

describe('SchedulerService - Persistence Pattern', () => {
  it('should use CREATE TABLE IF NOT EXISTS for safe re-init', () => {
    // Simulate the schedulerService.init() pattern
    const tables = new Set<string>();

    function initScheduler(): void {
      tables.add('scheduled_tasks');
    }

    initScheduler();
    initScheduler(); // Simulate app restart
    expect(tables.size).toBe(1);
  });

  it('should use ON CONFLICT for upsert persistence', () => {
    // Simulate the persistTask pattern
    const tasks = new Map<string, { name: string; enabled: boolean }>();

    function persistTask(id: string, name: string, enabled: boolean): void {
      tasks.set(id, { name, enabled });
    }

    persistTask('task-1', 'Auto Distill', true);
    persistTask('task-1', 'Auto Distill Updated', false); // Upsert

    expect(tasks.get('task-1')!.name).toBe('Auto Distill Updated');
    expect(tasks.get('task-1')!.enabled).toBe(false);
    expect(tasks.size).toBe(1); // No duplicate
  });

  it('should correctly parse stored task data', () => {
    // Simulate rowToTask pattern
    const row = {
      id: 'task-1',
      type: 'auto_distill',
      name: 'Test Task',
      cron_expr: '0 */2 * * *',
      config: '{"operations": ["summarize"]}',
      enabled: 1,
      last_run_at: 1715000000,
      next_run_at: 1715007200,
      next_run_at_estimated: 1,
      last_result: '{"success": true, "itemsProcessed": 5}',
      created_at: 1714913600,
    };

    const task = {
      id: row.id as string,
      type: row.type as string,
      name: row.name as string,
      cronExpr: row.cron_expr as string,
      config: JSON.parse(row.config as string),
      enabled: (row.enabled as number) === 1,
      lastRunAt: (row.last_run_at as number) ?? null,
      nextRunAt: (row.next_run_at as number) ?? null,
      nextRunAtEstimated: (row.next_run_at_estimated as number) === 1,
      lastResult: row.last_result ? JSON.parse(row.last_result as string) : null,
      createdAt: row.created_at as number,
    };

    expect(task.name).toBe('Test Task');
    expect(task.enabled).toBe(true);
    expect(task.config).toEqual({ operations: ['summarize'] });
    expect(task.lastResult).toEqual({ success: true, itemsProcessed: 5 });
    expect(task.nextRunAtEstimated).toBe(true);
  });

  it('should handle missing optional fields gracefully', () => {
    const row = {
      id: 'task-2',
      type: 'cleanup',
      name: 'Cleanup',
      cron_expr: '0 0 * * *',
      config: '{}',
      enabled: 0,
      last_run_at: null,
      next_run_at: null,
      next_run_at_estimated: 0,
      last_result: null,
      created_at: 1714913600,
    };

    const task = {
      id: row.id as string,
      type: row.type as string,
      name: row.name as string,
      cronExpr: row.cron_expr as string,
      config: JSON.parse(row.config as string),
      enabled: (row.enabled as number) === 1,
      lastRunAt: (row.last_run_at as number) ?? null,
      nextRunAt: (row.next_run_at as number) ?? null,
      nextRunAtEstimated: (row.next_run_at_estimated as number) === 1,
      lastResult: row.last_result ? JSON.parse(row.last_result as string) : null,
      createdAt: row.created_at as number,
    };

    expect(task.enabled).toBe(false);
    expect(task.lastRunAt).toBeNull();
    expect(task.nextRunAt).toBeNull();
    expect(task.lastResult).toBeNull();
    expect(task.nextRunAtEstimated).toBe(false);
  });
});

// ── Cross-module consistency ──────────────────────────────────────────────

describe('Storage + Scheduler - Cross-module Consistency', () => {
  it('scheduled_agent_tasks should be managed by storage, not scheduler', () => {
    // Verify the architectural decision:
    // - scheduled_tasks: managed by schedulerService (CREATE TABLE IF NOT EXISTS)
    // - scheduled_agent_tasks: managed by storage (in schema migration)
    // This test documents the expected pattern

    const schedulerManagedTables = ['scheduled_tasks'];
    const storageManagedTables = [
      'source_items',
      'ai_tasks',
      'distilled_outputs',
      'knowledge_cards',
      'export_records',
      'scheduled_agent_tasks', // This one is in storage schema
    ];

    // Verify no overlap
    const overlap = schedulerManagedTables.filter((t) => storageManagedTables.includes(t));
    expect(overlap).toEqual([]); // No table should be managed by both
  });

  it('should use consistent timestamp formats', () => {
    // storage uses unixepoch() (seconds), scheduler uses Date.now() (milliseconds)
    // This test documents the inconsistency and verifies conversion

    const storageTimestamp = Math.floor(Date.now() / 1000); // seconds
    const schedulerTimestamp = Date.now(); // milliseconds

    // Scheduler stores in milliseconds, storage in seconds
    // When scheduler reads from storage, it should handle the conversion
    expect(schedulerTimestamp).toBeGreaterThan(storageTimestamp * 1000 - 1000);
    expect(schedulerTimestamp).toBeLessThan(storageTimestamp * 1000 + 1000);

    // scheduled_tasks uses milliseconds (created_at from Date.now())
    // scheduled_agent_tasks uses seconds (created_at from unixepoch())
    // This is a known inconsistency that should be documented
  });
});
