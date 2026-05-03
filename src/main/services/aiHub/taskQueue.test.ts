// AcMind TaskQueue Unit Tests
// Tests for the in-memory task queue (no mocks needed)

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { taskQueue } from './taskQueue';
import type { AiTask } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function makeTask(overrides: Partial<AiTask> = {}): AiTask {
  return {
    id: `task-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    sourceItemId: 'src-1',
    tier: 'local_light',
    operation: 'summarize',
    status: 'queued',
    provider: '',
    model: '',
    input: {},
    createdAt: Date.now(),
    updatedAt: Date.now(),
    ...overrides,
  };
}

/**
 * Reset the singleton queue to a clean state.
 * We access the private `queue` array and `processing` flag via (any) cast.
 */
function resetQueue(): void {
  (taskQueue as any).queue = [];
  (taskQueue as any).processing = false;
  (taskQueue as any).paused = false;
  (taskQueue as any).statusChangeCallbacks = [];
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('TaskQueue', () => {
  beforeEach(() => {
    resetQueue();
  });

  // -- enqueue / dequeue ----------------------------------------------------

  describe('enqueue and dequeue', () => {
    it('should add a task to the queue via enqueue', () => {
      const task = makeTask();
      taskQueue.enqueue(task);

      const found = taskQueue.getAll();
      expect(found.length).toBe(1);
      expect(found[0].id).toBe(task.id);
    });

    it('should auto-start processing the first enqueued task', () => {
      const task = makeTask();
      taskQueue.enqueue(task);

      // The first task should be running after enqueue
      const found = taskQueue.getAll().find((t) => t.id === task.id);
      expect(found?.status).toBe('running');
    });

    it('should remove and return the next queued task via dequeue', () => {
      const task1 = makeTask({ id: 'dq-1' });
      const task2 = makeTask({ id: 'dq-2' });

      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      // task1 is running, task2 is queued
      const dequeued = taskQueue.dequeue();
      expect(dequeued).toBeDefined();
      expect(dequeued!.id).toBe('dq-2');
    });

    it('should return undefined when no queued tasks remain', () => {
      const result = taskQueue.dequeue();
      expect(result).toBeUndefined();
    });
  });

  // -- cancel ---------------------------------------------------------------

  describe('cancel', () => {
    it('should cancel a queued task', () => {
      const task1 = makeTask({ id: 'cancel-q-1' });
      const task2 = makeTask({ id: 'cancel-q-2' });

      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      // task2 should still be queued
      const result = taskQueue.cancel('cancel-q-2');
      expect(result).toBe(true);

      const found = taskQueue.getAll().find((t) => t.id === 'cancel-q-2');
      expect(found?.status).toBe('cancelled');
    });

    it('should cancel a failed task', () => {
      const task = makeTask({ id: 'cancel-fail' });
      taskQueue.enqueue(task);

      // Fail the running task
      taskQueue.failTask('cancel-fail', 'test error');

      const result = taskQueue.cancel('cancel-fail');
      expect(result).toBe(true);

      const afterCancel = taskQueue.getAll().find((t) => t.id === 'cancel-fail');
      expect(afterCancel?.status).toBe('cancelled');
    });

    it('should not cancel a running task', () => {
      const task = makeTask({ id: 'cancel-run' });
      taskQueue.enqueue(task);

      // After enqueue, the task should be running
      const result = taskQueue.cancel('cancel-run');
      expect(result).toBe(false);
    });

    it('should not cancel a done task', () => {
      const task = makeTask({ id: 'cancel-done' });
      taskQueue.enqueue(task);

      // Complete the running task
      taskQueue.completeTask('cancel-done', { result: 'ok' });

      const result = taskQueue.cancel('cancel-done');
      expect(result).toBe(false);
    });

    it('should return false for a non-existent task', () => {
      const result = taskQueue.cancel('non-existent-id');
      expect(result).toBe(false);
    });

    it('should cancel queued tasks by source item without cancelling running task', () => {
      const running = makeTask({ id: 'cancel-src-running', sourceItemId: 'src-cancel' });
      const queued = makeTask({ id: 'cancel-src-queued', sourceItemId: 'src-cancel' });
      const other = makeTask({ id: 'cancel-src-other', sourceItemId: 'src-other' });

      taskQueue.enqueue(running);
      taskQueue.enqueue(queued);
      taskQueue.enqueue(other);

      const cancelled = taskQueue.cancelBySourceItem('src-cancel');

      expect(cancelled).toEqual(['cancel-src-queued']);
      expect(taskQueue.getAll().find((task) => task.id === 'cancel-src-running')?.status).toBe('running');
      expect(taskQueue.getAll().find((task) => task.id === 'cancel-src-queued')?.status).toBe('cancelled');
      expect(taskQueue.getAll().find((task) => task.id === 'cancel-src-other')?.status).toBe('queued');
    });
  });

  // -- retry ----------------------------------------------------------------

  describe('retry', () => {
    it('should retry a failed task', () => {
      const task = makeTask({ id: 'retry-fail' });
      taskQueue.enqueue(task);

      // Fail the running task
      taskQueue.failTask('retry-fail', 'test failure');

      const result = taskQueue.retry('retry-fail');
      expect(result).toBe(true);

      // retry() sets status to 'queued' then calls processNext() which sets it to 'running'
      const afterRetry = taskQueue.getAll().find((t) => t.id === 'retry-fail');
      expect(['queued', 'running']).toContain(afterRetry?.status);
      expect(afterRetry?.error).toBeUndefined();
    });

    it('should retry a cancelled task', () => {
      const task = makeTask({ id: 'retry-cancel' });
      taskQueue.enqueue(task);

      // Fail then cancel
      taskQueue.failTask('retry-cancel', 'test');
      taskQueue.cancel('retry-cancel');

      const result = taskQueue.retry('retry-cancel');
      expect(result).toBe(true);

      // retry() sets status to 'queued' then calls processNext() which sets it to 'running'
      const afterRetry = taskQueue.getAll().find((t) => t.id === 'retry-cancel');
      expect(['queued', 'running']).toContain(afterRetry?.status);
    });

    it('should not retry a running task', () => {
      const task = makeTask({ id: 'retry-run' });
      taskQueue.enqueue(task);

      const result = taskQueue.retry('retry-run');
      expect(result).toBe(false);
    });

    it('should not retry a queued task', () => {
      const task1 = makeTask({ id: 'retry-q-1' });
      const task2 = makeTask({ id: 'retry-q-2' });
      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      // task2 is queued
      const result = taskQueue.retry('retry-q-2');
      expect(result).toBe(false);
    });

    it('should return false for a non-existent task', () => {
      const result = taskQueue.retry('non-existent-id');
      expect(result).toBe(false);
    });
  });

  // -- completeTask / failTask ----------------------------------------------

  describe('completeTask', () => {
    it('should mark a running task as done with output', () => {
      const task = makeTask({ id: 'complete-1' });
      taskQueue.enqueue(task);

      const output = { summary: 'Test summary' };
      taskQueue.completeTask('complete-1', output);

      const completed = taskQueue.getAll().find((t) => t.id === 'complete-1');
      expect(completed?.status).toBe('done');
      expect(completed?.output).toEqual(output);
      expect(completed?.finishedAt).toBeDefined();
      expect(completed?.latencyMs).toBeGreaterThanOrEqual(0);
    });

    it('should do nothing for a non-existent task', () => {
      // Should not throw
      expect(() => taskQueue.completeTask('non-existent', {})).not.toThrow();
    });
  });

  describe('failTask', () => {
    it('should mark a running task as failed with error', () => {
      const task = makeTask({ id: 'fail-1' });
      taskQueue.enqueue(task);

      taskQueue.failTask('fail-1', 'Something went wrong');

      const failed = taskQueue.getAll().find((t) => t.id === 'fail-1');
      expect(failed?.status).toBe('failed');
      expect(failed?.error).toBe('Something went wrong');
      expect(failed?.finishedAt).toBeDefined();
      expect(failed?.latencyMs).toBeGreaterThanOrEqual(0);
    });

    it('should do nothing for a non-existent task', () => {
      expect(() => taskQueue.failTask('non-existent', 'error')).not.toThrow();
    });
  });

  // -- getStats -------------------------------------------------------------

  describe('getStats', () => {
    it('should return correct stats for an empty queue', () => {
      const stats = taskQueue.getStats();
      expect(stats.total).toBe(0);
      expect(stats.queued).toBe(0);
      expect(stats.running).toBe(0);
      expect(stats.done).toBe(0);
      expect(stats.failed).toBe(0);
      expect(stats.cancelled).toBe(0);
    });

    it('should count tasks correctly by status', () => {
      const task1 = makeTask({ id: 'stats-1' });
      const task2 = makeTask({ id: 'stats-2' });
      const task3 = makeTask({ id: 'stats-3' });

      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);
      taskQueue.enqueue(task3);

      // Complete the running task (task1)
      taskQueue.completeTask('stats-1', { result: 'ok' });

      // Fail the next running task (task2, auto-processed via setImmediate)
      // We need to wait for setImmediate
      // Instead, let's directly set task2 to running and fail it
      const t2 = taskQueue.getAll().find((t) => t.id === 'stats-2');
      if (t2 && (t2.status === 'queued' || t2.status === 'running')) {
        if (t2.status === 'queued') {
          // Manually set to running to simulate processNext
          (t2 as any).status = 'running';
        }
        taskQueue.failTask('stats-2', 'test error');
      }

      const stats = taskQueue.getStats();
      expect(stats.total).toBe(3);
      expect(stats.done).toBe(1);
      expect(stats.failed).toBe(1);
      // task3 should be queued or running
      expect(stats.queued + stats.running).toBe(1);
    });
  });

  // -- onStatusChange -------------------------------------------------------

  describe('onStatusChange', () => {
    it('should call the callback when a task status changes to running', () => {
      const callback = vi.fn();
      taskQueue.onStatusChange(callback);

      const task = makeTask({ id: 'cb-1' });
      taskQueue.enqueue(task);

      // enqueue triggers processNext which sets task to 'running' and emits
      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'cb-1', status: 'running' }),
      );
    });

    it('should call callback when task is completed', () => {
      const callback = vi.fn();
      taskQueue.onStatusChange(callback);

      const task = makeTask({ id: 'cb-2' });
      taskQueue.enqueue(task);
      taskQueue.completeTask('cb-2', { result: 'ok' });

      // Called once for running, once for done
      expect(callback).toHaveBeenCalledTimes(2);
      expect(callback).toHaveBeenLastCalledWith(
        expect.objectContaining({ id: 'cb-2', status: 'done' }),
      );
    });

    it('should call callback when task is cancelled', () => {
      const callback = vi.fn();
      taskQueue.onStatusChange(callback);

      const task1 = makeTask({ id: 'cb-cancel-1' });
      const task2 = makeTask({ id: 'cb-cancel-2' });
      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      // Clear previous calls
      callback.mockClear();

      taskQueue.cancel('cb-cancel-2');
      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'cb-cancel-2', status: 'cancelled' }),
      );
    });

    it('should support multiple callbacks', () => {
      const cb1 = vi.fn();
      const cb2 = vi.fn();
      taskQueue.onStatusChange(cb1);
      taskQueue.onStatusChange(cb2);

      const task = makeTask({ id: 'cb-multi' });
      taskQueue.enqueue(task);

      expect(cb1).toHaveBeenCalledTimes(1);
      expect(cb2).toHaveBeenCalledTimes(1);
    });

    it('should stop calling after unsubscribe', () => {
      const callback = vi.fn();
      const unsub = taskQueue.onStatusChange(callback);

      const task1 = makeTask({ id: 'cb-unsub-1' });
      taskQueue.enqueue(task1);

      expect(callback).toHaveBeenCalledTimes(1);
      unsub();

      const task2 = makeTask({ id: 'cb-unsub-2' });
      taskQueue.enqueue(task2);

      // Should still be 1 (unsubscribed before second enqueue)
      expect(callback).toHaveBeenCalledTimes(1);
    });
  });

  // -- Sequential processing ------------------------------------------------

  describe('sequential processing', () => {
    it('should only process one task at a time (running count <= 1)', () => {
      const tasks = Array.from({ length: 5 }, (_, i) =>
        makeTask({ id: `seq-${i}` }),
      );

      for (const t of tasks) {
        taskQueue.enqueue(t);
      }

      const stats = taskQueue.getStats();
      expect(stats.running).toBeLessThanOrEqual(1);
    });

    it('should process next task after completing the current one', async () => {
      const task1 = makeTask({ id: 'seq-comp-1' });
      const task2 = makeTask({ id: 'seq-comp-2' });

      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      // Complete the running task
      taskQueue.completeTask('seq-comp-1', { result: 'ok' });

      // Wait for setImmediate to process the next task
      await new Promise<void>((resolve) => setImmediate(resolve));

      const nextRunning = taskQueue.getAll().find((t) => t.status === 'running');
      expect(nextRunning).toBeDefined();
      expect(nextRunning!.id).toBe('seq-comp-2');
    });

    it('should process next task after failing the current one', async () => {
      const task1 = makeTask({ id: 'seq-fail-1' });
      const task2 = makeTask({ id: 'seq-fail-2' });

      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      taskQueue.failTask('seq-fail-1', 'intentional failure');

      await new Promise<void>((resolve) => setImmediate(resolve));

      const nextRunning = taskQueue.getAll().find((t) => t.status === 'running');
      expect(nextRunning).toBeDefined();
      expect(nextRunning!.id).toBe('seq-fail-2');
    });
  });

  // -- getAll with filter ---------------------------------------------------

  describe('getAll', () => {
    it('should return all tasks when no filter is provided', () => {
      const task1 = makeTask({ id: 'filter-all-1' });
      const task2 = makeTask({ id: 'filter-all-2' });
      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      const all = taskQueue.getAll();
      expect(all.length).toBe(2);
    });

    it('should filter by status', () => {
      const task = makeTask({ id: 'filter-st-1' });
      taskQueue.enqueue(task);
      taskQueue.completeTask('filter-st-1', {});

      const done = taskQueue.getAll({ status: 'done' });
      expect(done.length).toBe(1);
      expect(done[0].status).toBe('done');
    });

    it('should filter by sourceItemId', () => {
      const task1 = makeTask({ id: 'filter-src-1', sourceItemId: 'src-A' });
      const task2 = makeTask({ id: 'filter-src-2', sourceItemId: 'src-B' });
      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      const filtered = taskQueue.getAll({ sourceItemId: 'src-A' });
      expect(filtered.length).toBe(1);
      expect(filtered[0].sourceItemId).toBe('src-A');
    });

    it('should filter by operation', () => {
      const task1 = makeTask({ id: 'filter-op-1', operation: 'rename' });
      const task2 = makeTask({ id: 'filter-op-2', operation: 'tag' });
      taskQueue.enqueue(task1);
      taskQueue.enqueue(task2);

      const filtered = taskQueue.getAll({ operation: 'rename' });
      expect(filtered.length).toBe(1);
      expect(filtered[0].operation).toBe('rename');
    });
  });
});
