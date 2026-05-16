import { useState, useEffect, useRef } from 'react'
import type { ProviderConfig } from '../../shared/types'
import type { AgentSession, AgentViewState, ChatMessage } from '../components/agent/types'
import AgentWorkspaceLayout from '../components/agent/workspace/AgentWorkspaceLayout'
import AgentProjectSidebar from '../components/agent/workspace/AgentProjectSidebar'
import AgentHeaderBar from '../components/agent/workspace/AgentHeaderBar'
import AgentMessageList from '../components/agent/workspace/AgentMessageList'
import AgentComposer from '../components/agent/workspace/AgentComposer'
import AgentWelcome from '../components/agent/workspace/AgentWelcome'

function AgentPage() {
  const [providers, setProviders] = useState<ProviderConfig[]>([])
  const [selectedProvider, setSelectedProvider] = useState<string>('')
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [viewState, setViewState] = useState<AgentViewState>('empty')
  const [sessions] = useState<AgentSession[]>([])
  const [selectedSessionId, setSelectedSessionId] = useState<string | undefined>()
  const messagesEndRef = useRef<HTMLDivElement>(null)

  const selectedProviderObj = providers.find(p => p.id === selectedProvider)

  useEffect(() => {
    loadProviders()
  }, [])

  useEffect(() => {
    if (viewState !== 'empty') {
      messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [messages, viewState])

  const loadProviders = async () => {
    try {
      const result = await window.electronAPI.ai.getProviders()
      setProviders(result)
      if (result.length > 0 && !selectedProvider) {
        setSelectedProvider(result[0].id)
      }
    } catch (error) {
      console.error('Failed to load providers:', error)
    }
  }

  const handleSend = async (text?: string) => {
    const content = text ?? input.trim()
    if (!content || loading) return
    if (!selectedProvider && providers.length === 0) return

    const userMessage: ChatMessage = { role: 'user', content }
    setMessages(prev => [...prev, userMessage])
    setInput('')
    setViewState('chatting')
    setLoading(true)

    try {
      const allMessages = [...messages, userMessage]
      const providerId = selectedProvider || providers[0]?.id || ''
      const response = await window.electronAPI.ai.chat(providerId, allMessages)
      setMessages(prev => [...prev, { role: 'assistant', content: response.content }])
    } catch (error) {
      console.error('AI chat error:', error)
      setMessages(prev => [...prev, { role: 'assistant', content: '抱歉，发生了错误。请检查 AI 服务是否可用。' }])
    } finally {
      setLoading(false)
    }
  }

  const handleQuickDistill = async () => {
    if (!input.trim()) return

    setViewState('chatting')
    setLoading(true)
    try {
      const result = await window.electronAPI.distill.quick(input)
      setMessages(prev => [...prev, { role: 'assistant', content: `📝 快速蒸馏结果：\n\n${result}` }])
      setInput('')
    } catch (error) {
      console.error('Quick distill error:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleNewChat = () => {
    setMessages([])
    setSelectedSessionId(undefined)
    setViewState('empty')
    setInput('')
  }

  const handleSuggestionClick = (text: string) => {
    setInput(text)
    handleSend(text)
  }

  const handleClearContext = () => {
    setMessages([])
    setViewState('empty')
  }

  return (
    <div className="page-content" style={{ padding: 0, maxWidth: 'none', overflow: 'hidden' }}>
      <AgentWorkspaceLayout
        left={
          <AgentProjectSidebar
            history={sessions}
            selectedSessionId={selectedSessionId}
            onSelectHistory={setSelectedSessionId}
            onNewChat={handleNewChat}
            modelName={selectedProviderObj?.modelId}
          />
        }
        center={
          <div style={{ display: 'flex', flexDirection: 'column', height: '100%', overflow: 'hidden' }}>
            <AgentHeaderBar
              projectName="AcMind Agent"
              modelName={selectedProviderObj?.modelId}
              isOnline={true}
              onClearContext={handleClearContext}
            />

            {viewState === 'empty' ? (
              <AgentWelcome onSuggestionClick={handleSuggestionClick} />
            ) : (
              <AgentMessageList
                messages={messages}
                loading={loading}
                messagesEndRef={messagesEndRef}
              />
            )}

            <AgentComposer
              input={input}
              loading={loading}
              onInputChange={setInput}
              onSend={() => handleSend()}
              onQuickDistill={handleQuickDistill}
            />
          </div>
        }
      />
    </div>
  )
}

export default AgentPage
