/**
 * Skill Registry — Agent 技能注册表
 *
 * 职责：
 * 1. 注册/注销 AgentSkill
 * 2. 查询可用技能
 * 3. 生成 LLM function calling 定义
 */

import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface AgentSkill {
  name: string;
  description: string;
  parameters: Record<string, unknown>; // JSON Schema
  category: string;
  requiresConfirmation: boolean;
  execute(params: Record<string, unknown>, context: SkillContext): Promise<SkillResult>;
}

export interface SkillContext {
  taskId: string;
  sessionId: string;
  abortSignal: AbortSignal;
}

export interface SkillResult {
  success: boolean;
  content: string;
  error?: string;
  metadata?: Record<string, unknown>;
}

/** LLM function calling 格式的定义 */
export interface FunctionDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

// ---------------------------------------------------------------------------
// SkillRegistry
// ---------------------------------------------------------------------------

class SkillRegistry {
  private skills: Map<string, AgentSkill> = new Map();

  /** 注册一个技能 */
  register(skill: AgentSkill): void {
    if (this.skills.has(skill.name)) {
      logger.warn('app', 'skillRegistry', 'register', `Skill "${skill.name}" already registered, overwriting`);
    }
    this.skills.set(skill.name, skill);
    logger.info('app', 'skillRegistry', 'register', `Registered skill: ${skill.name} (${skill.category})`);
  }

  /** 注销一个技能 */
  unregister(name: string): void {
    this.skills.delete(name);
    logger.info('app', 'skillRegistry', 'unregister', `Unregistered skill: ${name}`);
  }

  /** 获取单个技能 */
  get(name: string): AgentSkill | undefined {
    return this.skills.get(name);
  }

  /** 获取所有已注册技能 */
  getAll(): AgentSkill[] {
    return Array.from(this.skills.values());
  }

  /** 获取技能名称列表 */
  getNames(): string[] {
    return Array.from(this.skills.keys());
  }

  /** 转换为 LLM function calling 定义列表 */
  toFunctionDefinitions(): FunctionDefinition[] {
    return this.getAll().map(skill => ({
      type: 'function' as const,
      function: {
        name: skill.name,
        description: skill.description,
        parameters: skill.parameters,
      },
    }));
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const skillRegistry = new SkillRegistry();
