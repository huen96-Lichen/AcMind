import { NavLink } from 'react-router-dom'

interface NavItem {
  path: string
  label: string
  icon: string
  shortcut?: string
}

const navItems: NavItem[] = [
  { path: '/agent', label: 'Agent', icon: '🤖', shortcut: '⌘1' },
  { path: '/inbox', label: '收集箱', icon: '📥', shortcut: '⌘2' },
  { path: '/clipboard', label: '剪贴板', icon: '📋', shortcut: '⌘3' },
  { path: '/schedule', label: '日程', icon: '📅', shortcut: '⌘4' },
  { path: '/workbench', label: '工作台', icon: '🛠️', shortcut: '⌘5' },
  { path: '/tools', label: '工具', icon: '🔧', shortcut: '⌘6' },
  { path: '/companion', label: '随身', icon: '✨', shortcut: '⌘7' },
]

function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-logo">AcMind</div>
      <nav className="sidebar-nav">
        {navItems.map((item) => (
          <NavLink
            key={item.path}
            to={item.path}
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <span>{item.icon}</span>
            <span className="nav-label">{item.label}</span>
            {item.shortcut && <span className="nav-shortcut">{item.shortcut}</span>}
          </NavLink>
        ))}
      </nav>
      <NavLink
        to="/settings"
        className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
        style={{ marginTop: 'auto' }}
      >
        <span>⚙️</span>
        <span>设置</span>
      </NavLink>
    </aside>
  )
}

export default Sidebar
