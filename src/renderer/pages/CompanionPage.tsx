function CompanionPage() {
  return (
    <div className="page-content">
      <div className="page-header">
        <h1>说入法</h1>
        <p>只保留语音输入法配置与状态</p>
      </div>
      <div className="card">
        <div className="empty-state">
          <div>🎙️</div>
          <h3>语音输入法</h3>
          <p>模型、触发方式、输出策略和快捷键都在这里统一管理</p>
        </div>
      </div>
    </div>
  )
}

export default CompanionPage
