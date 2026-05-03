// VaultKeeper Module — Barrel Export
// Phase 9.1-9.3: 统一导出 VaultKeeper 相关类型和单例

export { vaultKeeperAdapter } from './vaultKeeperAdapter';
export { processingJobService } from './processingJobService';
export { externalResultIngestionService } from './externalResultIngestionService';
export type { IngestionResult } from './externalResultIngestionService';
export type {
  IVaultKeeperAdapter,
  VKJobType,
  VKJobStatus,
  VKSubmitJobRequest,
  VKSubmitJobResponse,
  VKJobStatusResponse,
  VKJobResult,
  VKHealthStatus,
} from './types';
