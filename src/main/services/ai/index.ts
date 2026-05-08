import log from 'electron-log'
import type { ProviderConfig, AiTier } from '../../../shared/types'

export interface AIResponse {
  content: string
  usage?: {
    promptTokens: number
    completionTokens: number
    totalTokens: number
  }
  model?: string
  provider?: string
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant'
  content: string
}

let providers: ProviderConfig[] = [
  {
    id: 'ollama-default',
    name: 'Ollama (本地)',
    type: 'ollama',
    tier: 'local_light',
    baseUrl: 'http://localhost:11434',
    modelId: 'llama3.2',
    enabled: true,
    capabilities: ['chat', 'completion']
  }
]

export function getProviders(): ProviderConfig[] {
  return providers
}

export function getProvider(id: string): ProviderConfig | undefined {
  return providers.find(p => p.id === id)
}

export function getDefaultProvider(): ProviderConfig | undefined {
  return providers.find(p => p.enabled)
}

export function addProvider(provider: ProviderConfig): void {
  const index = providers.findIndex(p => p.id === provider.id)
  if (index >= 0) {
    providers[index] = provider
  } else {
    providers.push(provider)
  }
  log.info('Provider added/updated:', provider.id)
}

export function removeProvider(id: string): void {
  providers = providers.filter(p => p.id !== id)
  log.info('Provider removed:', id)
}

export async function chat(
  providerId: string,
  messages: ChatMessage[],
  onChunk?: (chunk: string) => void
): Promise<AIResponse> {
  const provider = getProvider(providerId) || getDefaultProvider()
  if (!provider) {
    throw new Error('No AI provider available')
  }

  log.info(`AI chat request to ${provider.name} (${provider.modelId})`)

  try {
    const response = await fetch(`${provider.baseUrl}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: provider.modelId,
        messages: messages.map(m => ({ role: m.role, content: m.content })),
        stream: !!onChunk
      })
    })

    if (!response.ok) {
      throw new Error(`AI request failed: ${response.status}`)
    }

    if (onChunk) {
      const reader = response.body?.getReader()
      if (!reader) throw new Error('No response body')

      let fullContent = ''
      const decoder = new TextDecoder()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        const lines = chunk.split('\n').filter(Boolean)

        for (const line of lines) {
          try {
            const data = JSON.parse(line)
            if (data.message?.content) {
              fullContent += data.message.content
              onChunk(data.message.content)
            }
          } catch {}
        }
      }

      return { content: fullContent, provider: provider.name, model: provider.modelId }
    } else {
      const data = await response.json()
      return {
        content: data.message?.content || '',
        usage: data.usage,
        provider: provider.name,
        model: provider.modelId
      }
    }
  } catch (error) {
    log.error('AI chat error:', error)
    throw error
  }
}

export async function completion(
  providerId: string,
  prompt: string,
  onChunk?: (chunk: string) => void
): Promise<AIResponse> {
  const provider = getProvider(providerId) || getDefaultProvider()
  if (!provider) {
    throw new Error('No AI provider available')
  }

  log.info(`AI completion request to ${provider.name} (${provider.modelId})`)

  try {
    const response = await fetch(`${provider.baseUrl}/api/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: provider.modelId,
        prompt,
        stream: !!onChunk
      })
    })

    if (!response.ok) {
      throw new Error(`AI request failed: ${response.status}`)
    }

    if (onChunk) {
      const reader = response.body?.getReader()
      if (!reader) throw new Error('No response body')

      let fullContent = ''
      const decoder = new TextDecoder()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        const lines = chunk.split('\n').filter(Boolean)

        for (const line of lines) {
          try {
            const data = JSON.parse(line)
            if (data.response) {
              fullContent += data.response
              onChunk(data.response)
            }
          } catch {}
        }
      }

      return { content: fullContent, provider: provider.name, model: provider.modelId }
    } else {
      const data = await response.json()
      return {
        content: data.response || '',
        usage: data.usage,
        provider: provider.name,
        model: provider.modelId
      }
    }
  } catch (error) {
    log.error('AI completion error:', error)
    throw error
  }
}
