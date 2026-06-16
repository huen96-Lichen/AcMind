# Codex 第一阶段执行任务

## 目标

实现 AcWork 的统一应用外壳、工作台和合并后的收集箱。

## 实施顺序

1. 建立统一 Design Tokens
2. 实现 AcWorkShell
3. 实现 Sidebar 和 Toolbar
4. 实现通用基础组件
5. 实现工作台静态结构
6. 接入工作台 ViewModel
7. 合并收集箱与剪贴板数据模型
8. 实现收集箱三栏布局
9. 实现列表和网格视图
10. 实现 Inspector 与批量操作
11. 完成 1500×920 和 1180×720 截图验收

## 禁止事项

- 不使用 WebView
- 不使用 HTML
- 不创建第二套 Token
- 不把所有区块都做成卡片
- 不使用风景图、强渐变和大面积毛玻璃
- 不保留剪贴板一级页面
- 不在 View 中写死业务数据
- 不重复页面标题

## 数据层

统一使用：

```swift
CollectedItem
CollectionSource
CollectedContentType
ProcessingStatus
```

剪贴板、手机同步、说入法、截图、Agent、手动添加都进入同一 Repository。

## 验收截图

必须输出：

- 1500×920 工作台
- 1500×920 收集箱列表视图
- 1500×920 收集箱网格视图
- 1180×720 工作台
- 1180×720 收集箱
- Loading / Empty / Error 状态截图
