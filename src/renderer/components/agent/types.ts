export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
  toolCalls?: Array<{ id: string; name: string; args: Record<string, unknown> }>
  toolResult?: { toolCallId: string; content: string }
}

export type AgentViewState = 'empty' | 'chatting' | 'running' | 'result'

export type AgentTab = 'chat' | 'distill'

export interface AgentSession {
  id: string
  title: string
  projectId?: string
  createdAt: Date
  messageCount: number
  lastMessageAt?: Date
}

export interface AgentToolAction {
  id: string
  name: string
  icon: string
  description: string
  enabled: boolean
}

export interface AgentContextInfo {
  sessionId?: string
  modelName?: string
  providerName?: string
  tokenUsage?: { prompt: number; completion: number }
  activeProject?: string
}

export interface AgentProject {
  id: string
  name: string
  description?: string
  icon?: string
  isActive: boolean
}
