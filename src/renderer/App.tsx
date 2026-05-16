import { Routes, Route, Navigate } from 'react-router-dom'
import Sidebar from './components/layout/Sidebar'
import AgentPage from './pages/AgentPage'
import InboxPage from './pages/InboxPage'
import ClipboardPage from './pages/ClipboardPage'
import SchedulePage from './pages/SchedulePage'
import WorkbenchPage from './pages/WorkbenchPage'
import ToolsPage from './pages/ToolsPage'
import CompanionPage from './pages/CompanionPage'
import SettingsPage from './pages/SettingsPage'

function App() {
  return (
    // FIXED SHELL: keep the app chrome stable.
    // Feature work should live inside routed pages, not here.
    <div className="app-container">
      <Sidebar />
      <main className="main-content">
        <Routes>
          <Route path="/" element={<Navigate to="/inbox" replace />} />
          <Route path="/agent" element={<AgentPage />} />
          <Route path="/inbox" element={<InboxPage />} />
          <Route path="/clipboard" element={<ClipboardPage />} />
          <Route path="/schedule" element={<SchedulePage />} />
          <Route path="/workbench" element={<WorkbenchPage />} />
          <Route path="/tools" element={<ToolsPage />} />
          <Route path="/companion" element={<CompanionPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </main>
    </div>
  )
}

export default App
