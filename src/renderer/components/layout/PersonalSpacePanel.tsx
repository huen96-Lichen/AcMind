import { useCallback, useEffect, useRef, useState } from 'react';
import { PinStackIcon } from '../../design-system/icons';
import { ScrollContainer } from '../shared/ScrollContainer';
import type { AppSettings, UserProfile, UserPreferences } from '../../../shared/types';
import { DEFAULT_USER_PROFILE, DEFAULT_USER_PREFERENCES } from '../../../shared/types';

/* ─── Types ─────────────────────────────────────────────────────────────────── */

interface PersonalSpacePanelProps {
  visible: boolean;
  onClose: () => void;
}

/* ─── Component ─────────────────────────────────────────────────────────────── */

export function PersonalSpacePanel({ visible, onClose }: PersonalSpacePanelProps): JSX.Element {
  const [settings, setSettings] = useState<AppSettings | null>(null);
  const [profileDraft, setProfileDraft] = useState<UserProfile>({ ...DEFAULT_USER_PROFILE });
  const [prefsDraft, setPrefsDraft] = useState<UserPreferences>({ ...DEFAULT_USER_PREFERENCES });
  const [saving, setSaving] = useState(false);
  const [saveMessage, setSaveMessage] = useState<string | null>(null);
  const [newTag, setNewTag] = useState('');
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const [selectingDir, setSelectingDir] = useState(false);
  const [openingDir, setOpeningDir] = useState(false);
  const [selectingVault, setSelectingVault] = useState(false);
  const [testingWrite, setTestingWrite] = useState(false);
  const panelRef = useRef<HTMLDivElement>(null);

  // Load settings on mount
  useEffect(() => {
    if (!visible) return;
    let cancelled = false;

    async function load() {
      try {
        const s = await window.acmind.settings.get();
        if (cancelled) return;
        setSettings(s);
        setProfileDraft({ ...DEFAULT_USER_PROFILE, ...s.profile });
        setPrefsDraft({ ...DEFAULT_USER_PREFERENCES, ...s.preferences });
      } catch {
        // Settings not available yet
      }
    }

    void load();
    return () => { cancelled = true; };
  }, [visible]);

  // Trigger slide-in animation
  useEffect(() => {
    if (visible) {
      requestAnimationFrame(() => {
        panelRef.current?.classList.add('is-visible');
      });
    } else {
      panelRef.current?.classList.remove('is-visible');
    }
  }, [visible]);

  // Save all (profile + prefs)
  const handleSaveAll = useCallback(async () => {
    setSaving(true);
    setSaveMessage(null);
    try {
      await Promise.all([
        window.acmind.settings.update({ profile: profileDraft }),
        window.acmind.settings.update({ preferences: prefsDraft }),
      ]);
      setSaveMessage('已保存');
      setTimeout(() => setSaveMessage(null), 2000);
    } catch {
      setSaveMessage('保存失败');
    } finally {
      setSaving(false);
    }
  }, [profileDraft, prefsDraft]);

  // Add role tag
  const handleAddTag = useCallback(() => {
    const tag = newTag.trim();
    if (tag && !profileDraft.roleTags.includes(tag)) {
      setProfileDraft(prev => ({ ...prev, roleTags: [...prev.roleTags, tag] }));
      setNewTag('');
    }
  }, [newTag, profileDraft.roleTags]);

  // Remove role tag
  const handleRemoveTag = useCallback((tag: string) => {
    setProfileDraft(prev => ({ ...prev, roleTags: prev.roleTags.filter(t => t !== tag) }));
  }, []);

  // Open data directory
  const handleOpenDataDir = useCallback(async () => {
    try {
      await window.acmind.app.openStorageRoot();
    } catch {
      // ignore
    }
  }, []);

  // Select data directory
  const handleSelectDataDir = useCallback(async () => {
    setSelectingDir(true);
    try {
      const result = await window.acmind.workspace.selectDirectory();
      if (result.success && result.path) {
        const newPath: string = result.path;
        await window.acmind.settings.update({ storageRoot: newPath });
        setSettings(prev => prev ? { ...prev, storageRoot: newPath } : prev);
        showToast('数据目录已更新');
      }
    } catch {
      showToast('选择目录失败');
    } finally {
      setSelectingDir(false);
    }
  }, []);

  // Open directory in Finder
  const handleOpenDir = useCallback(async (dirPath: string) => {
    setOpeningDir(true);
    try {
      const result = await window.acmind.workspace.openDirectory(dirPath);
      if (!result.success) {
        showToast('无法打开目录');
      }
    } catch {
      showToast('打开目录失败');
    } finally {
      setOpeningDir(false);
    }
  }, []);

  // Select Obsidian Vault
  const handleSelectVault = useCallback(async () => {
    setSelectingVault(true);
    try {
      const result = await window.acmind.workspace.selectDirectory();
      if (result.success && result.path) {
        const newPath: string = result.path;
        await window.acmind.vault.updateConfig({ vaultPath: newPath });
        setSettings(prev => prev ? { ...prev, vault: { ...prev.vault, vaultPath: newPath } } : prev);
        showToast('Vault 路径已更新');
      }
    } catch {
      showToast('选择 Vault 失败');
    } finally {
      setSelectingVault(false);
    }
  }, []);

  // Test write to directory
  const handleTestWrite = useCallback(async (dirPath: string) => {
    if (!dirPath) {
      showToast('请先选择目录');
      return;
    }
    setTestingWrite(true);
    try {
      const result = await window.acmind.workspace.testWrite(dirPath);
      if (result.success) {
        showToast('写入测试通过');
      } else {
        showToast(result.error || '写入测试失败');
      }
    } catch {
      showToast('写入测试失败');
    } finally {
      setTestingWrite(false);
    }
  }, []);

  // Show toast message
  const showToast = useCallback((msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 2500);
  }, []);

  const displayName = profileDraft.displayName;
  const avatarInitial = displayName ? displayName[0] : '?';

  return (
    <>
      {/* Toast */}
      {toastMessage && (
        <div
          className="fixed bottom-6 left-1/2 -translate-x-1/2 z-[9999] rounded-lg px-4 py-2 text-[13px] font-medium shadow-lg transition-opacity"
          style={{
            background: 'var(--pm-bg-elevated, #1a1a1a)',
            color: 'var(--pm-text-primary, #fff)',
            border: '1px solid var(--pm-border-subtle, rgba(255,255,255,0.1))',
          }}
        >
          {toastMessage}
        </div>
      )}

      {/* Overlay */}
      <div
        className={`acmind-personal-space-overlay ${visible ? 'is-visible' : ''}`}
        onClick={onClose}
      />

      {/* Panel */}
      <div ref={panelRef} className="acmind-personal-space-panel">
        {/* ── Header ── */}
        <div className="acmind-drawer-header">
          <div className="flex items-center gap-4 min-w-0">
            <div className="acmind-drawer-avatar">
              {avatarInitial}
            </div>
            <div className="min-w-0">
              <h2 className="acmind-drawer-title">设置你的空间</h2>
              <p className="acmind-drawer-subtitle">
                完成个人资料、工作空间和 Obsidian 连接
              </p>
            </div>
          </div>
          <button
            type="button"
            className="acmind-drawer-close-btn"
            onClick={onClose}
            title="关闭"
          >
            <PinStackIcon name="close" size={16} />
          </button>
        </div>

        {/* ── Scrollable Content ── */}
        <ScrollContainer className="flex-1 min-h-0">
          {/* Section 1: 个人资料 */}
          <div className="acmind-personal-space-section">
            <div className="acmind-section-header">
              <h3>个人资料</h3>
              <p>头像、名称和身份标签</p>
            </div>

            {/* Avatar Editor Card */}
            <div className="acmind-avatar-editor-card">
              <div className="acmind-avatar-preview">
                {avatarInitial}
              </div>
              <div className="min-w-0 flex-1">
                <p className="acmind-avatar-editor-title">头像将显示为姓名首字</p>
                <p className="acmind-avatar-editor-desc">点击后可上传图片或选择默认图标</p>
              </div>
              <button
                type="button"
                className="acmind-btn acmind-btn-ghost text-[12px]"
                style={{ height: 28, padding: '0 10px', flexShrink: 0 }}
              >
                更换头像
              </button>
            </div>

            {/* Display Name */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <label>显示名称</label>
              <input
                type="text"
                className="acmind-field"
                value={profileDraft.displayName}
                onChange={e => setProfileDraft(prev => ({ ...prev, displayName: e.target.value }))}
                placeholder="输入你的名称"
                onKeyDown={e => { if (e.key === 'Enter') handleSaveAll(); }}
              />
            </div>

            {/* Bio */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <div className="flex items-center justify-between">
                <label>个人简介</label>
                <span className="acmind-field-hint">{profileDraft.bio?.length ?? 0}/80</span>
              </div>
              <input
                type="text"
                className="acmind-field"
                value={profileDraft.bio ?? ''}
                onChange={e => {
                  if (e.target.value.length <= 80) {
                    setProfileDraft(prev => ({ ...prev, bio: e.target.value }));
                  }
                }}
                placeholder="一句话介绍自己"
                maxLength={80}
              />
            </div>

            {/* Workspace Name */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <label>工作空间名称</label>
              <input
                type="text"
                className="acmind-field"
                value={profileDraft.workspaceName}
                onChange={e => setProfileDraft(prev => ({ ...prev, workspaceName: e.target.value }))}
                placeholder="我的第二大脑"
                onKeyDown={e => { if (e.key === 'Enter') handleSaveAll(); }}
              />
            </div>

            {/* Role Tags */}
            <div className="acmind-personal-space-field">
              <label>角色标签</label>
              <div className="flex flex-wrap gap-1.5 mt-1">
                {profileDraft.roleTags.map(tag => (
                  <span
                    key={tag}
                    className="inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[12px] font-medium"
                    style={{
                      background: 'var(--pm-brand-soft)',
                      color: 'var(--pm-brand-text)',
                    }}
                  >
                    {tag}
                    <button
                      type="button"
                      className="ml-0.5 hover:opacity-70"
                      onClick={() => handleRemoveTag(tag)}
                    >
                      <PinStackIcon name="close" size={10} />
                    </button>
                  </span>
                ))}
                <div className="flex items-center gap-1">
                  <input
                    type="text"
                    className="acmind-field text-[12px]"
                    style={{ height: 28, width: 80, padding: '0 8px' }}
                    value={newTag}
                    onChange={e => setNewTag(e.target.value)}
                    onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); handleAddTag(); } }}
                    placeholder="添加标签"
                  />
                  <button
                    type="button"
                    className="flex h-7 w-7 items-center justify-center rounded-full text-[color:var(--pm-brand)] hover:bg-[color:var(--pm-brand-soft)]"
                    onClick={handleAddTag}
                    title="添加标签"
                  >
                    <PinStackIcon name="launcher" size={14} />
                  </button>
                </div>
              </div>
            </div>
          </div>

          {/* Section 2: 工作空间 */}
          <div className="acmind-personal-space-section">
            <div className="acmind-section-header">
              <h3>工作空间</h3>
              <p>数据目录、Obsidian Vault 和 AI 层级</p>
            </div>

            {/* Data Directory */}
            <div className="acmind-setting-row">
              <span className="acmind-setting-label">数据目录</span>
              <span className="acmind-setting-value">
                {settings?.storageRoot || '未配置'}
              </span>
              <div className="acmind-setting-actions">
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={() => settings?.storageRoot && handleTestWrite(settings.storageRoot)}
                  disabled={testingWrite}
                >
                  {testingWrite ? '测试中...' : '测试写入'}
                </button>
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={handleSelectDataDir}
                  disabled={selectingDir}
                >
                  {selectingDir ? '选择中...' : '选择目录'}
                </button>
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={() => settings?.storageRoot && handleOpenDir(settings.storageRoot)}
                  disabled={openingDir || !settings?.storageRoot}
                >
                  {openingDir ? '打开中...' : '打开目录'}
                </button>
              </div>
            </div>

            {/* Obsidian Vault */}
            <div className="acmind-setting-row">
              <span className="acmind-setting-label">Obsidian Vault</span>
              <span className="acmind-setting-value">
                {settings?.vault?.vaultPath || '未配置'}
              </span>
              <div className="acmind-setting-actions">
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={handleSelectVault}
                  disabled={selectingVault}
                >
                  {selectingVault ? '选择中...' : '选择 Vault'}
                </button>
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={() => settings?.vault?.vaultPath && handleOpenDir(settings.vault.vaultPath)}
                  disabled={openingDir || !settings?.vault?.vaultPath}
                >
                  {openingDir ? '打开中...' : '打开目录'}
                </button>
              </div>
            </div>

            {/* Default Tier */}
            <div className="acmind-setting-row">
              <span className="acmind-setting-label">默认 AI 层级</span>
              <span className="acmind-setting-value">
                {settings?.defaultTier ?? 'local_light'}
              </span>
              <div className="acmind-setting-actions">
                <button
                  type="button"
                  className="acmind-btn acmind-btn-ghost text-[12px]"
                  style={{ height: 28, padding: '0 10px' }}
                  onClick={() => window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'settings', tab: 'ai' } }))}
                >
                  前往 AI 控制台
                </button>
              </div>
            </div>
          </div>

          {/* Section 3: 偏好设置 */}
          <div className="acmind-personal-space-section">
            <div className="acmind-section-header">
              <h3>偏好设置</h3>
              <p>主题、密度和起始页</p>
            </div>

            {/* Theme Mode */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <label>主题模式</label>
              <select
                className="acmind-field"
                value={prefsDraft.themeMode}
                onChange={e => setPrefsDraft(prev => ({ ...prev, themeMode: e.target.value as UserPreferences['themeMode'] }))}
              >
                <option value="light">浅色</option>
                <option value="dark">深色</option>
                <option value="system">跟随系统</option>
              </select>
            </div>

            {/* Interface Density */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <label>界面密度</label>
              <select
                className="acmind-field"
                value={prefsDraft.density}
                onChange={e => setPrefsDraft(prev => ({ ...prev, density: e.target.value as UserPreferences['density'] }))}
              >
                <option value="comfortable">舒适</option>
                <option value="compact">紧凑</option>
              </select>
            </div>

            {/* Default Start Page */}
            <div className="acmind-personal-space-field" style={{ marginBottom: 16 }}>
              <label>默认起始页</label>
              <select
                className="acmind-field"
                value={prefsDraft.defaultStartPage}
                onChange={e => setPrefsDraft(prev => ({ ...prev, defaultStartPage: e.target.value }))}
              >
                <option value="capture-inbox">收集箱</option>
                <option value="daily-flow">工作台</option>
              </select>
            </div>

            {/* Show Status Bar */}
            <div className="flex items-center justify-between py-2">
              <label className="text-[12px] font-medium" style={{ color: 'var(--pm-text-secondary)' }}>
                显示状态栏
              </label>
              <button
                type="button"
                className="relative h-5 w-9 rounded-full transition-colors"
                style={{
                  background: prefsDraft.showStatusBar ? 'var(--pm-brand)' : 'var(--pm-border-subtle)',
                }}
                onClick={() => setPrefsDraft(prev => ({ ...prev, showStatusBar: !prev.showStatusBar }))}
              >
                <span
                  className="absolute top-0.5 h-4 w-4 rounded-full bg-white shadow transition-transform"
                  style={{
                    left: prefsDraft.showStatusBar ? 18 : 2,
                  }}
                />
              </button>
            </div>
          </div>

          {/* Section 4: 数据安全 */}
          <div className="acmind-personal-space-section">
            <div className="acmind-section-header">
              <h3>数据安全</h3>
              <p>本地存储与隐私说明</p>
            </div>

            {/* Local-first indicator */}
            <div className="flex items-center gap-2 mb-3">
              <span className="inline-block h-2 w-2 rounded-full bg-[#16A34A]" />
              <span className="text-[13px] font-medium" style={{ color: 'var(--pm-text-primary)' }}>本地优先</span>
            </div>

            <p className="text-[12px] leading-relaxed mb-3" style={{ color: 'var(--pm-text-tertiary)' }}>
              你的资料默认保存在本地。只有在你启用云端模型时，相关任务内容才会被发送到云端处理。
            </p>

            <p className="text-[11px] mb-3 truncate" style={{ color: 'var(--pm-text-tertiary)' }}>
              数据目录: {settings?.storageRoot || '未配置'}
            </p>

            <button
              type="button"
              className="acmind-btn acmind-btn-secondary text-[12px]"
              style={{ height: 30, padding: '0 12px' }}
              onClick={handleOpenDataDir}
            >
              打开数据目录
            </button>
          </div>
        </ScrollContainer>

        {/* ── Sticky Footer ── */}
        <div className="acmind-drawer-footer">
          {saveMessage && (
            <span className="text-[12px] mr-auto" style={{ color: 'var(--pm-status-success, #16A34A)' }}>
              {saveMessage}
            </span>
          )}
          <button
            type="button"
            className="acmind-btn acmind-btn-ghost"
            onClick={onClose}
          >
            取消
          </button>
          <button
            type="button"
            className="acmind-btn acmind-btn-primary"
            onClick={handleSaveAll}
            disabled={saving}
          >
            {saving ? '保存中...' : '保存更改'}
          </button>
        </div>
      </div>
    </>
  );
}
