import { useEffect, useMemo, useState } from 'react';
import { Button, Card, EmptyState, PageHeader, PageShell, Section, StatusBadge } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';

const ZTOOLS_LOCAL_PATH = '/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main';
const ZTOOLS_REPO_URL = 'https://github.com/ZToolsCenter/ZTools';
const ZTOOLS_README_PATH = '/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main/README.md';
const ZTOOLS_START_COMMAND = 'cd "/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main" && pnpm dev';

type ToolStatus = 'available' | 'saved' | 'missing_path' | 'not_configured' | 'unknown';

interface ProjectStatus {
  found: boolean;
  status: ToolStatus;
}

const HIGHLIGHTS = [
  {
    title: '快速启动器',
    description: '把常用应用、命令和工作流统一到一个入口，减少来回切换。',
    icon: 'launcher',
  },
  {
    title: '插件平台',
    description: '不仅能搜，还能通过插件扩展能力，适合作为桌面工具参考。',
    icon: 'filled-cloud',
  },
  {
    title: '本地搜索',
    description: '强调本地可用性和响应速度，和 AcMind 的本地优先理念很接近。',
    icon: 'filled-search',
  },
  {
    title: '剪贴板能力',
    description: '内置剪贴板管理，和 AcMind 的收集、Pin 住内容的路径互补。',
    icon: 'filled-clipboard',
  },
];

const INTEGRATION_STEPS = [
  '从顶部按钮直接打开 ZTools 介绍页',
  '在自动工具里查看本地仓库、仓库地址和启动命令',
  '用本地目录和 README 快速回到它的源码与文档',
  '把它当成搜索能力与插件能力的参考实现',
];

const COLLABORATION_ITEMS = [
  {
    title: 'AcMind 负责沉淀',
    description: '把网页、文件、截图、语音和剪贴板内容整理成知识卡片、暂存内容和可检索的资料。',
    icon: 'sb-obsidian',
  },
  {
    title: 'ZTools 负责搜索',
    description: '提供启动器、插件平台和本地搜索入口，适合快速唤起、查找和扩展桌面能力。',
    icon: 'filled-search',
  },
  {
    title: '两者一起工作',
    description: '在 AcMind 里管理信息，在 ZTools 里做快速检索与工具分发，形成“沉淀 + 唤起”的闭环。',
    icon: 'filled-output',
  },
];

export function ZToolsPage(): JSX.Element {
  const [projectStatus, setProjectStatus] = useState<ProjectStatus>({ found: false, status: 'unknown' });

  useEffect(() => {
    let cancelled = false;

    async function loadStatus(): Promise<void> {
      try {
        const res = await window.acmind.toolBench.listGithubProjects();
        if (cancelled || !res.success) return;

        const project = res.projects.find(
          (item) => item.localPath === ZTOOLS_LOCAL_PATH || item.repoUrl === ZTOOLS_REPO_URL || item.name === 'ZTools',
        );

        if (!project) {
          setProjectStatus({ found: false, status: 'not_configured' });
          return;
        }

        setProjectStatus({ found: true, status: (project.status as ToolStatus) || 'saved' });
      } catch {
        if (!cancelled) {
          setProjectStatus({ found: false, status: 'unknown' });
        }
      }
    }

    void loadStatus();
    return () => {
      cancelled = true;
    };
  }, []);

  const statusLabel = useMemo(() => {
    if (!projectStatus.found) return '尚未收纳';
    switch (projectStatus.status) {
      case 'available':
        return '本地可用';
      case 'saved':
        return '已收纳';
      case 'missing_path':
        return '路径失效';
      case 'not_configured':
        return '未配置';
      default:
        return '已识别';
    }
  }, [projectStatus]);

  const openGithub = async () => {
    await window.acmind.toolBench.openUrl(ZTOOLS_REPO_URL);
  };

  const openLocalDir = async () => {
    await window.acmind.toolBench.openPath(ZTOOLS_LOCAL_PATH);
  };

  const openReadme = async () => {
    await window.acmind.toolBench.openPath(ZTOOLS_README_PATH);
  };

  const copyStartCommand = async () => {
    await window.acmind.toolBench.copyCommand(ZTOOLS_START_COMMAND);
  };

  const goToAutoTools = () => {
    window.dispatchEvent(new CustomEvent('acmind:navigate', { detail: { view: 'auto-tools', tab: 'ztools' } }));
  };

  return (
    <PageShell>
      <div className="px-6 pt-5">
        <PageHeader
          eyebrow="工具接入"
          title="ZTools"
          description="一个高性能、可扩展的桌面搜索工具和插件平台。AcMind 把它当成搜索与插件能力的参考实现，并保留了本地目录入口。"
          actions={
            <div className="flex flex-wrap items-center gap-2">
              <Button variant="primary" size="sm" leadingIcon={<AcMindIcon name="filled-search" size={14} />} onClick={goToAutoTools}>
                打开自动工具
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="act-link" size={14} />} onClick={() => void openGithub()}>
                GitHub
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="filled-file-import" size={14} />} onClick={() => void openLocalDir()}>
                本地目录
              </Button>
            </div>
          }
          meta={<StatusBadge tone={projectStatus.status === 'missing_path' ? 'warning' : projectStatus.found ? 'success' : 'neutral'} label={statusLabel} />}
        />
      </div>

      <div className="px-6 pb-2">
        <Card
          variant="elevated"
          className="relative overflow-hidden p-5"
          style={{
            background:
              'radial-gradient(circle at top right, rgba(249, 115, 22, 0.16), transparent 32%), radial-gradient(circle at left bottom, rgba(251, 191, 36, 0.12), transparent 26%), var(--pm-bg-surface)',
          }}
        >
          <div className="absolute inset-x-0 bottom-0 h-px bg-gradient-to-r from-transparent via-[color:var(--pm-brand)] to-transparent opacity-25" />
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <StatusBadge tone={projectStatus.status === 'missing_path' ? 'warning' : 'success'} label="搜索工具" />
                <span className="rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">
                  已集成到 AcMind
                </span>
                <span className="rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-bg-subtle)] text-[color:var(--text-muted)]">
                  本地优先
                </span>
              </div>
              <h2 className="mt-3 text-[24px] font-semibold tracking-[-0.03em]" style={{ color: 'var(--text-title)' }}>
                搜索、启动、扩展，三件事放在一个入口里
              </h2>
              <p className="mt-2 max-w-3xl text-[13px] leading-6" style={{ color: 'var(--text-muted)' }}>
                这个页面把 ZTools 作为 AcMind 的外部搜索工具来管理。你可以快速回到源码、复制启动命令、打开仓库，或者直接跳回自动工具继续管理项目。
              </p>
            </div>

            <div className="grid min-w-[240px] gap-2 sm:grid-cols-3 lg:grid-cols-1">
              <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-subtle)] px-4 py-3">
                <p className="text-[11px] uppercase tracking-[0.14em]" style={{ color: 'var(--text-muted)' }}>状态</p>
                <p className="mt-1 text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>{statusLabel}</p>
              </div>
              <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-subtle)] px-4 py-3">
                <p className="text-[11px] uppercase tracking-[0.14em]" style={{ color: 'var(--text-muted)' }}>仓库</p>
                <p className="mt-1 truncate text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>ZToolsCenter / ZTools</p>
              </div>
              <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-subtle)] px-4 py-3">
                <p className="text-[11px] uppercase tracking-[0.14em]" style={{ color: 'var(--text-muted)' }}>本地路径</p>
                <p className="mt-1 truncate text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>{projectStatus.found ? '已收纳' : '待识别'}</p>
              </div>
            </div>
          </div>
        </Card>
      </div>

      <div className="grid min-h-0 flex-1 gap-4 px-6 pb-6 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
        <div className="min-h-0 flex flex-col gap-4">
          <Card variant="elevated" className="p-5">
            <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <StatusBadge tone={projectStatus.status === 'missing_path' ? 'warning' : 'success'} label="搜索工具" />
                  <span className="rounded-full px-2 py-0.5 text-[11px] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">
                    已集成到 AcMind
                  </span>
                </div>
                <h2 className="mt-3 text-[22px] font-semibold tracking-[-0.02em]" style={{ color: 'var(--text-title)' }}>
                  把 ZTools 当作你的搜索与插件参考工具
                </h2>
                <p className="mt-2 max-w-2xl text-[13px]" style={{ color: 'var(--text-muted)' }}>
                  它不是 AcMind 的重复实现，而是一个补充入口: AcMind 负责信息蒸馏、知识沉淀和内容管理，ZTools 负责搜索、启动和插件扩展。
                </p>
              </div>

              <div className="grid min-w-[220px] gap-2 rounded-[14px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-subtle)] p-4">
                <div>
                  <p className="text-[11px] uppercase tracking-[0.16em]" style={{ color: 'var(--text-muted)' }}>本地路径</p>
                  <p className="mt-1 truncate text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>{ZTOOLS_LOCAL_PATH}</p>
                </div>
                <div>
                  <p className="text-[11px] uppercase tracking-[0.16em]" style={{ color: 'var(--text-muted)' }}>启动命令</p>
                  <p className="mt-1 truncate font-mono text-[12px]" style={{ color: 'var(--text-title)' }}>{ZTOOLS_START_COMMAND}</p>
                </div>
              </div>
            </div>

            <div className="mt-5 flex flex-wrap gap-2">
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="copy" size={14} />} onClick={() => void copyStartCommand()}>
                复制启动命令
              </Button>
              <Button variant="secondary" size="sm" leadingIcon={<AcMindIcon name="line-search" size={14} />} onClick={() => void openReadme()}>
                打开 README
              </Button>
              <Button variant="ghost" size="sm" leadingIcon={<AcMindIcon name="filled-output" size={14} />} onClick={goToAutoTools}>
                回到自动工具
              </Button>
            </div>
          </Card>

          <Section title="AcMind × ZTools" description="这两个工具不是同一层的竞争关系，而是信息沉淀和快速唤起的组合。">
            <div className="grid gap-3 lg:grid-cols-[minmax(0,1fr)_220px_minmax(0,1fr)] lg:items-stretch">
              <Card variant="base" className="p-4">
                <div className="flex items-center gap-2">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-brand-soft)]">
                    <AcMindIcon name={COLLABORATION_ITEMS[0].icon as any} size={20} />
                  </div>
                  <div>
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                      {COLLABORATION_ITEMS[0].title}
                    </p>
                    <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                      {COLLABORATION_ITEMS[0].description}
                    </p>
                  </div>
                </div>
                <div className="mt-4 grid gap-2">
                  <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] px-3 py-2 text-[12px]" style={{ color: 'var(--text-body)' }}>
                    采集来源: 网页、文件、截图、语音、剪贴板
                  </div>
                  <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] px-3 py-2 text-[12px]" style={{ color: 'var(--text-body)' }}>
                    输出结果: 知识卡片、暂存池、导出内容
                  </div>
                </div>
              </Card>

              <div className="flex items-center justify-center">
                <div className="flex h-full w-full flex-col items-center justify-center rounded-[18px] border border-[color:var(--border-light)] bg-[color:var(--pm-bg-subtle)] px-4 py-5 text-center">
                  <div className="flex h-11 w-11 items-center justify-center rounded-full bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]">
                    <AcMindIcon name="filled-output" size={20} />
                  </div>
                  <p className="mt-3 text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                    中间桥接
                  </p>
                  <p className="mt-1 text-[12px] leading-5" style={{ color: 'var(--text-muted)' }}>
                    在 AcMind 里沉淀内容，在 ZTools 里快速唤起和检索工具。
                  </p>
                </div>
              </div>

              <Card variant="base" className="p-4">
                <div className="flex items-center gap-2">
                  <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                    <AcMindIcon name={COLLABORATION_ITEMS[1].icon as any} size={20} />
                  </div>
                  <div>
                    <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                      {COLLABORATION_ITEMS[1].title}
                    </p>
                    <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                      {COLLABORATION_ITEMS[1].description}
                    </p>
                  </div>
                </div>
                <div className="mt-4 grid gap-2">
                  <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] px-3 py-2 text-[12px]" style={{ color: 'var(--text-body)' }}>
                    能力重点: 启动器、搜索、插件系统
                  </div>
                  <div className="rounded-[10px] bg-[color:var(--pm-bg-subtle)] px-3 py-2 text-[12px]" style={{ color: 'var(--text-body)' }}>
                    入口方式: 顶部按钮、侧边栏、自动工具详情页
                  </div>
                </div>
              </Card>
            </div>

            <Card variant="elevated" className="mt-3 p-4">
              <div className="flex items-start gap-3">
                <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-brand-soft)]">
                  <AcMindIcon name={COLLABORATION_ITEMS[2].icon as any} size={20} />
                </div>
                <div className="min-w-0">
                  <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                    {COLLABORATION_ITEMS[2].title}
                  </p>
                  <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                    {COLLABORATION_ITEMS[2].description}
                  </p>
                </div>
              </div>
            </Card>
          </Section>

          <Section title="怎么接入" description="我们把它放在一个很轻的入口里，随时可回到源码、文档和自动工具。">
            <div className="grid gap-3 md:grid-cols-2">
              {INTEGRATION_STEPS.map((step, index) => (
                <Card key={step} variant="base" className="p-4">
                  <div className="flex items-start gap-3">
                    <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-[color:var(--pm-brand-soft)] text-[13px] font-semibold text-[color:var(--pm-brand)]">
                      {index + 1}
                    </div>
                    <p className="text-[13px]" style={{ color: 'var(--text-body)' }}>
                      {step}
                    </p>
                  </div>
                </Card>
              ))}
            </div>
          </Section>
        </div>

        <div className="min-h-0 flex flex-col gap-4">
          <Section title="核心价值" description="为什么它适合作为 AcMind 的搜索工具参考。">
            <div className="grid gap-3">
              {HIGHLIGHTS.map((item) => (
                <Card key={item.title} variant="base" className="p-4">
                  <div className="flex items-start gap-3">
                    <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-[10px] bg-[color:var(--pm-bg-surface-soft)]">
                      <AcMindIcon name={item.icon as any} size={20} />
                    </div>
                    <div className="min-w-0">
                      <p className="text-[14px] font-semibold" style={{ color: 'var(--text-title)' }}>
                        {item.title}
                      </p>
                      <p className="mt-1 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                        {item.description}
                      </p>
                    </div>
                  </div>
                </Card>
              ))}
            </div>
          </Section>

          <Section title="本地操作" description="你可以直接从这里返回源码、打开仓库或复制运行命令。">
            <div className="grid gap-3">
              <Card variant="base" className="p-4">
                <p className="text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>仓库信息</p>
                <p className="mt-1 truncate text-[12px]" style={{ color: 'var(--text-muted)' }}>{ZTOOLS_REPO_URL}</p>
                <div className="mt-3 flex flex-wrap gap-2">
                  <Button variant="ghost" size="sm" onClick={() => void openGithub()}>
                    打开仓库
                  </Button>
                  <Button variant="ghost" size="sm" onClick={() => void openLocalDir()}>
                    打开目录
                  </Button>
                </div>
              </Card>

              <Card variant="base" className="p-4">
                <p className="text-[13px] font-medium" style={{ color: 'var(--text-title)' }}>启动方式</p>
                <pre className="mt-2 overflow-auto rounded-[10px] bg-[color:var(--pm-bg-subtle)] p-3 text-[12px] leading-5" style={{ color: 'var(--text-body)' }}>
{`cd "/Volumes/White Atlas/03_Projects/AcMind/GitHub/ZTools-main"
pnpm install
pnpm dev`}
                </pre>
                <p className="mt-2 text-[12px]" style={{ color: 'var(--text-muted)' }}>
                  它本身是一个独立 Electron 项目，所以在 AcMind 里我们做的是“入口和上下文整合”，不是重新嵌入整个界面。
                </p>
              </Card>
            </div>
          </Section>

          {!projectStatus.found ? (
            <EmptyState
              icon={<AcMindIcon name="help" size={28} style={{ color: 'var(--pm-text-tertiary)' }} />}
              title="还没有识别到 ZTools 条目"
              description="如果本地路径存在，重新打开自动工具后会自动收纳。"
              action={{ label: '去自动工具', onClick: goToAutoTools }}
            />
          ) : null}
        </div>
      </div>
    </PageShell>
  );
}
