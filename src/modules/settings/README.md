# Settings 模块

## 职责

- 应用权限管理
- 快捷键配置
- 外观设置（主题、密度）
- 存储路径配置
- AI Provider 配置
- Vault 配置
- 用户配置文件

## 不负责

- 具体业务逻辑
- 数据采集

## 现有代码映射

- `src/main/settings.ts` — 设置管理
- `src/main/permissions.ts` — 权限管理
- `src/main/permissionCoordinator.ts` — 权限协调
- `src/main/shortcutManager.ts` — 快捷键管理
- `src/shared/defaultSettings.ts` — 默认设置
- `src/renderer/pages/settings/` — 设置 UI
