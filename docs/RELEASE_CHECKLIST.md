# AcMind 发布检查清单

## 发布前必检

### 1. 版本号对齐

- [ ] `package.json` → `version`
- [ ] `CHANGELOG.md` → 最新版本段落
- [ ] About 页面显示版本号一致

### 2. 构建验证

- [ ] `npm run typecheck` 通过
- [ ] `npm run lint` 通过（无新增 warning）
- [ ] `npm run build` 通过
- [ ] `npm run test` 通过

### 3. 品牌检查

- [ ] 用户可见文本无旧品牌名（PinMind / PinStack / VaultKeeper）
- [ ] LICENSE 版权信息正确
- [ ] 应用名称显示为 "AcMind"

### 4. 身份一致性

- [ ] `package.json` `build.appId` = `com.acore.acmind`
- [ ] 主进程 `bundleId` = `com.acore.acmind`
- [ ] Keychain 前缀 = `com.acore.acmind`

### 5. 安全检查

- [ ] 无硬编码路径或凭据
- [ ] 诊断包导出有脱敏
- [ ] API Key 存储在 Keychain
- [ ] CSP 策略正确（生产环境无 `unsafe-eval`）

### 6. 功能验证

- [ ] 剪贴板监控正常
- [ ] 截图功能正常
- [ ] AI Provider 连接正常
- [ ] 导出功能正常
- [ ] Capsule 浮窗正常

### 7. 打包验证

- [ ] `npm run package:mac:arm64` 成功
- [ ] DMG 可正常安装
- [ ] 应用可正常启动
- [ ] 自动更新配置正确

### 8. CHANGELOG

- [ ] 新版本段落完整
- [ ] 包含 Added / Changed / Fixed 分类
- [ ] 日期正确
