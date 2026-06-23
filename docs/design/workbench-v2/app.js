const body = document.body;
const prototypeRoot = document.querySelector('[data-prototype-root]');
const searchShell = document.querySelector('[data-search-shell]');
const searchInput = document.getElementById('global-search');
const debugOverlay = document.querySelector('[data-debug-overlay]');
const chart = document.querySelector('[data-chart]');
const chartTooltip = document.querySelector('[data-chart-tooltip]');
const chartHoverGroup = chart?.querySelector('[data-chart-hover]');
const chartHoverDot = chart?.querySelector('.chart-hover-dot');
const chartHoverLine = chart?.querySelector('.chart-hover-line');
const chartGrid = chart?.querySelector('[data-chart-grid]');
const chartBaseline = chart?.querySelector('[data-chart-baseline]');
const chartSecondary = chart?.querySelector('[data-chart-secondary]');
const chartArea = chart?.querySelector('[data-chart-area]');
const chartLine = chart?.querySelector('[data-chart-line]');
const chartPoints = chart?.querySelector('[data-chart-points]');
const currentTrendValue = document.querySelector('[data-current-trend-value]');

const chartData = {
  primary: [
    { time: '09:00', value: 46.2 },
    { time: '10:00', value: 52.4 },
    { time: '11:00', value: 61.1 },
    { time: '12:00', value: 58.3 },
    { time: '13:00', value: 66.8 },
    { time: '14:00', value: 73.6 },
    { time: '15:00', value: 71.8 },
    { time: '16:00', value: 76.4 },
    { time: '17:00', value: 78.4 }
  ],
  secondary: [
    { time: '09:00', value: 39.7 },
    { time: '10:00', value: 41.2 },
    { time: '11:00', value: 43.5 },
    { time: '12:00', value: 45.6 },
    { time: '13:00', value: 47.1 },
    { time: '14:00', value: 48.8 },
    { time: '15:00', value: 49.2 },
    { time: '16:00', value: 49.9 },
    { time: '17:00', value: 50.4 }
  ]
};

const debugTargets = [
  { selector: '[data-debug-id="PrimarySidebarPanel"]', name: 'PrimarySidebarPanel' },
  { selector: '[data-debug-id="WorkbenchPage"]', name: 'WorkbenchPage' },
  { selector: '[data-debug-id="WorkbenchHeader"]', name: 'WorkbenchHeader' },
  { selector: '[data-debug-id="MainDashboardGrid"]', name: 'MainDashboardGrid' },
  { selector: '[data-debug-id="MainColumn"]', name: 'MainColumn' },
  { selector: '[data-debug-id="CurrentFocusCard"]', name: 'CurrentFocusCard' },
  { selector: '[data-debug-id="PendingItemsCard"]', name: 'PendingItemsCard' },
  { selector: '[data-debug-id="RecentCollectionCard"]', name: 'RecentCollectionCard' },
  { selector: '[data-debug-id="ActivityTrendCard"]', name: 'ActivityTrendCard' },
  { selector: '[data-debug-id="ContextColumn"]', name: 'ContextColumn' },
  { selector: '[data-debug-id="TodayStatusPanel"]', name: 'TodayStatusPanel' },
  { selector: '[data-debug-id="QuickActionsCard"]', name: 'QuickActionsCard' },
  { selector: '[data-debug-id="DeviceStatusBar"]', name: 'DeviceStatusBar' }
];

let activeMode = 'standard';
let debugEnabled = false;
let hoverIndex = chartData.primary.length - 1;
let isSearchOpen = false;
let measurementRaf = 0;
const launchParams = new URLSearchParams(window.location.search);
const initialModeParam = launchParams.get('mode');
const initialDebugParam = launchParams.get('debug');

function setMode(mode) {
  activeMode = mode;
  body.classList.toggle('is-compact', mode === 'compact');
  document.documentElement.dataset.mode = mode;
  scheduleDebugUpdate();
  renderChart();
}

function setDebug(enabled) {
  debugEnabled = enabled;
  body.classList.toggle('is-debug', enabled);
  scheduleDebugUpdate();
}

function setSearchOpen(open) {
  isSearchOpen = open;
  searchShell.classList.toggle('is-open', open);
  if (open) {
    searchInput.focus();
  } else {
    searchInput.blur();
  }
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function pointToScreen(point, index, points, width, height, padding) {
  const xSpan = width - padding.left - padding.right;
  const ySpan = height - padding.top - padding.bottom;
  const min = Math.min(...points.map(item => item.value));
  const max = Math.max(...points.map(item => item.value));
  const step = points.length === 1 ? 0 : xSpan / (points.length - 1);
  const ratio = max === min ? 0.5 : (point.value - min) / (max - min);
  return {
    x: padding.left + step * index,
    y: padding.top + (1 - ratio) * ySpan
  };
}

function catmullRomPath(points, width, height, padding) {
  const screenPoints = points.map((point, index) => pointToScreen(point, index, points, width, height, padding));
  if (!screenPoints.length) return '';

  const path = [`M ${screenPoints[0].x.toFixed(2)} ${screenPoints[0].y.toFixed(2)}`];
  for (let i = 0; i < screenPoints.length - 1; i += 1) {
    const p0 = screenPoints[i - 1] || screenPoints[i];
    const p1 = screenPoints[i];
    const p2 = screenPoints[i + 1];
    const p3 = screenPoints[i + 2] || p2;
    const c1x = p1.x + (p2.x - p0.x) / 6;
    const c1y = p1.y + (p2.y - p0.y) / 6;
    const c2x = p2.x - (p3.x - p1.x) / 6;
    const c2y = p2.y - (p3.y - p1.y) / 6;
    path.push(`C ${c1x.toFixed(2)} ${c1y.toFixed(2)}, ${c2x.toFixed(2)} ${c2y.toFixed(2)}, ${p2.x.toFixed(2)} ${p2.y.toFixed(2)}`);
  }
  return path.join(' ');
}

function areaPath(linePath, points, width, height, padding) {
  if (!points.length) return '';
  const last = pointToScreen(points[points.length - 1], points.length - 1, points, width, height, padding);
  const first = pointToScreen(points[0], 0, points, width, height, padding);
  return `${linePath} L ${last.x.toFixed(2)} ${height - padding.bottom} L ${first.x.toFixed(2)} ${height - padding.bottom} Z`;
}

function renderChart() {
  if (!chart) return;

  const width = chart.viewBox.baseVal.width || 860;
  const height = chart.viewBox.baseVal.height || 220;
  const padding = { top: 22, right: 20, bottom: 28, left: 24 };
  const primary = chartData.primary;
  const secondary = chartData.secondary;
  const primaryLine = catmullRomPath(primary, width, height, padding);
  const secondaryLine = catmullRomPath(secondary, width, height, padding);
  chartLine.setAttribute('d', primaryLine);
  chartArea.setAttribute('d', areaPath(primaryLine, primary, width, height, padding));
  chartSecondary.setAttribute('d', secondaryLine);

  const baselineValue = primary.reduce((sum, item) => sum + item.value, 0) / primary.length;
  const baselinePoints = primary.map((point, index) => ({
    time: point.time,
    value: baselineValue
  }));
  chartBaseline.setAttribute('d', catmullRomPath(baselinePoints, width, height, padding));

  chartPoints.innerHTML = '';

  const screenPoints = primary.map((point, index) => pointToScreen(point, index, primary, width, height, padding));
  screenPoints.forEach((point, index) => {
    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circle.setAttribute('cx', point.x.toFixed(2));
    circle.setAttribute('cy', point.y.toFixed(2));
    circle.setAttribute('r', index === hoverIndex ? '5.5' : '3.5');
    circle.classList.toggle('is-highlighted', index === hoverIndex);
    chartPoints.appendChild(circle);
  });

  const hovered = screenPoints[hoverIndex];
  const hoveredPoint = primary[hoverIndex];
  if (hovered && hoveredPoint) {
    chartHoverGroup.hidden = false;
    chartHoverLine.setAttribute('x1', hovered.x.toFixed(2));
    chartHoverLine.setAttribute('x2', hovered.x.toFixed(2));
    chartHoverDot.setAttribute('cx', hovered.x.toFixed(2));
    chartHoverDot.setAttribute('cy', hovered.y.toFixed(2));

    chartTooltip.hidden = false;
    chartTooltip.querySelector('.tooltip-label').textContent = hoveredPoint.time;
    chartTooltip.querySelector('strong').textContent = hoveredPoint.value.toFixed(1);
    chartTooltip.querySelector('small').textContent = '活动水平 · 峰值稳定';
    chartTooltip.style.left = `${hovered.x}px`;
    chartTooltip.style.top = `${hovered.y - 8}px`;

    currentTrendValue.textContent = hoveredPoint.value.toFixed(1);
  }
}

function updateHoverFromClientX(clientX) {
  const rect = chart.getBoundingClientRect();
  const width = chart.viewBox.baseVal.width || 860;
  const x = clamp(clientX - rect.left, 24, rect.width - 20);
  const step = (width - 24 - 20) / (chartData.primary.length - 1);
  const index = clamp(Math.round((x - 24) / step), 0, chartData.primary.length - 1);
  hoverIndex = index;
  renderChart();
}

function setupChartInteractions() {
  if (!chart) return;
  chart.addEventListener('pointermove', event => updateHoverFromClientX(event.clientX));
  chart.addEventListener('pointerleave', () => {
    hoverIndex = chartData.primary.length - 1;
    renderChart();
  });
}

function scheduleDebugUpdate() {
  if (!debugEnabled) {
    debugOverlay.replaceChildren();
    return;
  }
  cancelAnimationFrame(measurementRaf);
  measurementRaf = requestAnimationFrame(updateDebugOverlay);
}

function updateDebugOverlay() {
  if (!debugEnabled) return;
  debugOverlay.replaceChildren();

  debugTargets.forEach((entry, index) => {
    const element = document.querySelector(entry.selector);
    if (!element) return;

    const rect = element.getBoundingClientRect();
    if (rect.width <= 0 || rect.height <= 0) return;

    const frame = document.createElement('div');
    frame.className = 'debug-frame';
    frame.style.left = `${rect.left}px`;
    frame.style.top = `${rect.top}px`;
    frame.style.width = `${rect.width}px`;
    frame.style.height = `${rect.height}px`;
    frame.style.borderColor = `hsla(${210 + index * 12}, 85%, 55%, 0.72)`;

    const label = document.createElement('div');
    label.className = 'debug-label';
    label.innerHTML = `<strong>${entry.name}</strong><span>x:${Math.round(rect.left)} y:${Math.round(rect.top)} w:${Math.round(rect.width)} h:${Math.round(rect.height)}</span>`;
    frame.appendChild(label);
    debugOverlay.appendChild(frame);
  });
}

function bindControls() {
  document.querySelectorAll('[data-nav]').forEach(button => {
    button.addEventListener('click', () => {
      document.querySelectorAll('.nav-item').forEach(item => item.classList.remove('is-active'));
      button.classList.add('is-active');
    });
  });

  document.querySelector('[data-action="toggle-search"]').addEventListener('click', () => {
    setSearchOpen(!isSearchOpen);
  });

  document.querySelector('[data-action="mode-standard"]').addEventListener('click', () => setMode('standard'));
  document.querySelector('[data-action="mode-compact"]').addEventListener('click', () => setMode('compact'));
  document.querySelector('[data-action="toggle-debug"]').addEventListener('click', () => setDebug(!debugEnabled));

  document.querySelector('[data-action="quick-note"]').addEventListener('click', () => {
    setMode(activeMode);
  });

  document.querySelector('[data-action="enter-agent"]').addEventListener('click', () => {
    document.querySelector('[data-nav="Agent"]').classList.add('is-active');
    document.querySelectorAll('.nav-item').forEach(item => {
      if (item.dataset.nav !== 'Agent') item.classList.remove('is-active');
    });
  });

  searchInput.addEventListener('keydown', event => {
    if (event.key === 'Escape') {
      setSearchOpen(false);
    }
  });
}

function syncModeFromViewport() {
  const width = window.innerWidth;
  setMode(width < 1380 ? 'compact' : 'standard');
}

function init() {
  bindControls();
  setupChartInteractions();
  if (initialModeParam === 'compact' || initialModeParam === 'standard') {
    setMode(initialModeParam);
  } else {
    syncModeFromViewport();
  }
  setDebug(initialDebugParam === '1' || initialDebugParam === 'true');
  renderChart();
  scheduleDebugUpdate();

  window.addEventListener('resize', () => {
    syncModeFromViewport();
    scheduleDebugUpdate();
  });
}

init();

window.WorkbenchV2Prototype = {
  setMode,
  setDebug,
  setSearchOpen,
  renderChart,
  syncModeFromViewport
};
