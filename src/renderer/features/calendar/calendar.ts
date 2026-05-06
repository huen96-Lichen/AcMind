export type CalendarViewMode = 'day' | 'week' | 'month' | 'year';
export type CalendarCategoryId = 'work' | 'personal' | 'project' | 'study' | 'life' | 'automation' | 'birthday' | 'holiday';
export type CalendarEventStatus = 'pending' | 'inProgress' | 'done' | 'skipped' | 'delayed';
export type CalendarRepeatFrequency = 'none' | 'daily' | 'weekly' | 'monthly' | 'yearly';

export interface CalendarRepeatRule {
  frequency: CalendarRepeatFrequency;
  interval: number;
  byWeekday: number[];
  until?: string | null;
}

export interface CalendarReminderRule {
  enabled: boolean;
  leadMinutes: number[];
}

export interface CalendarEvent {
  id: string;
  title: string;
  startAt: number;
  endAt: number;
  allDay: boolean;
  categoryId: CalendarCategoryId;
  notes: string;
  location: string;
  status: CalendarEventStatus;
  statusByDateKey: Record<string, CalendarEventStatus>;
  important: boolean;
  repeat: CalendarRepeatRule;
  reminders: CalendarReminderRule;
  createdAt: number;
  updatedAt: number;
}

export interface CalendarHighlightState {
  items: string[];
  updatedAt: number;
}

export interface CalendarReviewState {
  completed: string;
  blocked: string;
  tomorrow: string;
  exportToWorkspace: boolean;
  updatedAt: number;
}

export interface CalendarState {
  viewMode: CalendarViewMode;
  activeDateKey: string;
  events: CalendarEvent[];
  categoryVisibility: Record<CalendarCategoryId, boolean>;
  highlightsByDate: Record<string, CalendarHighlightState>;
  notesByDate: Record<string, string>;
  reviewsByDate: Record<string, CalendarReviewState>;
  firedReminderKeys: Record<string, number>;
}

export interface CalendarCategory {
  id: CalendarCategoryId;
  label: string;
  color: string;
  softColor: string;
  icon: string;
  isSystem?: boolean;
}

export interface CalendarOccurrence {
  event: CalendarEvent;
  dateKey: string;
  startAt: number;
  endAt: number;
}

export interface CalendarDateCell {
  date: Date;
  dateKey: string;
  inCurrentMonth: boolean;
  isToday: boolean;
}

export const CALENDAR_STORAGE_KEY = 'acmind.calendar.v1';

export const CALENDAR_CATEGORIES: CalendarCategory[] = [
  { id: 'work', label: '工作', color: '#3b82f6', softColor: 'rgba(59,130,246,0.12)', icon: 'filled-home' },
  { id: 'personal', label: '个人', color: '#22c55e', softColor: 'rgba(34,197,94,0.12)', icon: 'heart' },
  { id: 'project', label: '项目', color: '#8b5cf6', softColor: 'rgba(139,92,246,0.12)', icon: 'projects' },
  { id: 'study', label: '学习', color: '#f59e0b', softColor: 'rgba(245,158,11,0.12)', icon: 'search' },
  { id: 'life', label: '生活', color: '#ec4899', softColor: 'rgba(236,72,153,0.12)', icon: 'user' },
  { id: 'automation', label: '自动提醒', color: '#14b8a6', softColor: 'rgba(20,184,166,0.12)', icon: 'clock', isSystem: true },
  { id: 'birthday', label: '生日', color: '#f97316', softColor: 'rgba(249,115,22,0.12)', icon: 'heart', isSystem: true },
  { id: 'holiday', label: '节假日', color: '#64748b', softColor: 'rgba(100,116,139,0.12)', icon: 'calendar', isSystem: true },
];

export const CALENDAR_CATEGORY_MAP = Object.fromEntries(CALENDAR_CATEGORIES.map((category) => [category.id, category])) as Record<CalendarCategoryId, CalendarCategory>;

export function createCalendarRepeatRule(frequency: CalendarRepeatFrequency = 'none', interval = 1, byWeekday: number[] = []): CalendarRepeatRule {
  return { frequency, interval: Math.max(1, interval), byWeekday };
}

export function createCalendarReminderRule(enabled = false, leadMinutes: number[] = []): CalendarReminderRule {
  return { enabled, leadMinutes };
}

export function createDefaultCalendarState(now = new Date()): CalendarState {
  const todayKey = toDateKey(now);
  const categoryVisibility = Object.fromEntries(CALENDAR_CATEGORIES.map((category) => [category.id, true])) as Record<CalendarCategoryId, boolean>;

  const sampleEvents = createSeedEvents(now);

  return {
    viewMode: 'month',
    activeDateKey: todayKey,
    events: sampleEvents,
    categoryVisibility,
    highlightsByDate: {
      [todayKey]: {
        items: ['推进 AcMind 客户可用版', 'Codex 核验与反馈', '整理 PRD 文档'],
        updatedAt: Date.now(),
      },
    },
    notesByDate: {
      [todayKey]: '先把今天最重要的任务收敛，再推进执行。',
    },
    reviewsByDate: {},
    firedReminderKeys: {},
  };
}

export function loadCalendarState(): CalendarState {
  if (typeof window === 'undefined') {
    return createDefaultCalendarState();
  }

  try {
    const raw = window.localStorage.getItem(CALENDAR_STORAGE_KEY);
    if (!raw) {
      return createDefaultCalendarState();
    }
    const parsed = JSON.parse(raw) as Partial<CalendarState>;
    return normalizeCalendarState(parsed);
  } catch {
    return createDefaultCalendarState();
  }
}

export function saveCalendarState(state: CalendarState): void {
  if (typeof window === 'undefined') {
    return;
  }

  window.localStorage.setItem(CALENDAR_STORAGE_KEY, JSON.stringify(state));
}

export function normalizeCalendarState(state: Partial<CalendarState>): CalendarState {
  const fallback = createDefaultCalendarState();
  const eventList = Array.isArray(state.events) ? state.events.map(normalizeEvent).filter(Boolean) as CalendarEvent[] : fallback.events;
  const categoryVisibility = { ...fallback.categoryVisibility, ...(state.categoryVisibility ?? {}) } as Record<CalendarCategoryId, boolean>;

  return {
    viewMode: isCalendarViewMode(state.viewMode) ? state.viewMode : fallback.viewMode,
    activeDateKey: isDateKey(state.activeDateKey) ? state.activeDateKey : fallback.activeDateKey,
    events: eventList.length > 0 ? eventList : fallback.events,
    categoryVisibility,
    highlightsByDate: normalizeHighlightsMap(state.highlightsByDate, fallback.highlightsByDate),
    notesByDate: normalizeStringMap(state.notesByDate, fallback.notesByDate),
    reviewsByDate: normalizeReviewsMap(state.reviewsByDate),
    firedReminderKeys: normalizeNumberMap(state.firedReminderKeys),
  };
}

export function normalizeEvent(event: Partial<CalendarEvent> & { id?: string }): CalendarEvent | null {
  if (!event || typeof event.id !== 'string') {
    return null;
  }

  const now = Date.now();
  const startAt = isFiniteNumber(event.startAt) ? Number(event.startAt) : now;
  const endAt = isFiniteNumber(event.endAt) ? Number(event.endAt) : startAt + 60 * 60 * 1000;
  const categoryId = isCalendarCategoryId(event.categoryId) ? event.categoryId : 'work';
  const repeat = normalizeRepeat(event.repeat);
  const reminders = normalizeReminder(event.reminders);

  return {
    id: event.id,
    title: String(event.title ?? '未命名日程').trim() || '未命名日程',
    startAt,
    endAt: Math.max(endAt, startAt + 15 * 60 * 1000),
    allDay: Boolean(event.allDay),
    categoryId,
    notes: String(event.notes ?? ''),
    location: String(event.location ?? ''),
    status: isCalendarEventStatus(event.status) ? event.status : 'pending',
    statusByDateKey: normalizeStatusMap(event.statusByDateKey),
    important: Boolean(event.important),
    repeat,
    reminders,
    createdAt: isFiniteNumber(event.createdAt) ? Number(event.createdAt) : now,
    updatedAt: isFiniteNumber(event.updatedAt) ? Number(event.updatedAt) : now,
  };
}

export function normalizeRepeat(repeat: Partial<CalendarRepeatRule> | undefined): CalendarRepeatRule {
  const frequency = repeat && isCalendarRepeatFrequency(repeat.frequency) ? repeat.frequency : 'none';
  const interval = repeat && isFiniteNumber(repeat.interval) ? Math.max(1, Number(repeat.interval)) : 1;
  const byWeekday = Array.isArray(repeat?.byWeekday)
    ? repeat!.byWeekday.filter((value): value is number => Number.isInteger(value) && value >= 0 && value <= 6)
    : [];

  return {
    frequency,
    interval,
    byWeekday,
    until: typeof repeat?.until === 'string' && repeat.until ? repeat.until : null,
  };
}

export function normalizeReminder(reminder: Partial<CalendarReminderRule> | undefined): CalendarReminderRule {
  const leadMinutes = Array.isArray(reminder?.leadMinutes)
    ? reminder!.leadMinutes.filter((value): value is number => Number.isInteger(value) && value >= 0).slice(0, 5)
    : [];
  return {
    enabled: Boolean(reminder?.enabled),
    leadMinutes,
  };
}

export function normalizeStatusMap(value: Partial<Record<string, CalendarEventStatus>> | undefined): Record<string, CalendarEventStatus> {
  const result: Record<string, CalendarEventStatus> = {};
  for (const [key, item] of Object.entries(value ?? {})) {
    if (isCalendarEventStatus(item)) {
      result[key] = item;
    }
  }
  return result;
}

export function normalizeHighlightsMap(
  value: Partial<Record<string, CalendarHighlightState | string[]>> | undefined,
  fallback: Record<string, CalendarHighlightState>,
): Record<string, CalendarHighlightState> {
  const result: Record<string, CalendarHighlightState> = { ...fallback };
  for (const [key, item] of Object.entries(value ?? {})) {
    if (Array.isArray(item)) {
      result[key] = { items: item.map(String).slice(0, 3), updatedAt: Date.now() };
    } else if (item && typeof item === 'object') {
      result[key] = {
        items: Array.isArray(item.items) ? item.items.map(String).slice(0, 3) : [],
        updatedAt: isFiniteNumber(item.updatedAt) ? Number(item.updatedAt) : Date.now(),
      };
    }
  }
  return result;
}

export function normalizeReviewsMap(value: Partial<Record<string, CalendarReviewState>> | undefined): Record<string, CalendarReviewState> {
  const result: Record<string, CalendarReviewState> = {};
  for (const [key, item] of Object.entries(value ?? {})) {
    result[key] = {
      completed: String(item?.completed ?? ''),
      blocked: String(item?.blocked ?? ''),
      tomorrow: String(item?.tomorrow ?? ''),
      exportToWorkspace: Boolean(item?.exportToWorkspace),
      updatedAt: isFiniteNumber(item?.updatedAt) ? Number(item!.updatedAt) : Date.now(),
    };
  }
  return result;
}

export function normalizeStringMap(value: Partial<Record<string, string>> | undefined, fallback: Record<string, string>): Record<string, string> {
  const result: Record<string, string> = { ...fallback };
  for (const [key, item] of Object.entries(value ?? {})) {
    if (typeof item === 'string') {
      result[key] = item;
    }
  }
  return result;
}

export function normalizeNumberMap(value: Partial<Record<string, number>> | undefined): Record<string, number> {
  const result: Record<string, number> = {};
  for (const [key, item] of Object.entries(value ?? {})) {
    if (isFiniteNumber(item)) {
      result[key] = Number(item);
    }
  }
  return result;
}

export function isCalendarViewMode(value: unknown): value is CalendarViewMode {
  return value === 'day' || value === 'week' || value === 'month' || value === 'year';
}

export function isCalendarCategoryId(value: unknown): value is CalendarCategoryId {
  return value === 'work' || value === 'personal' || value === 'project' || value === 'study' || value === 'life' || value === 'automation' || value === 'birthday' || value === 'holiday';
}

export function isCalendarRepeatFrequency(value: unknown): value is CalendarRepeatFrequency {
  return value === 'none' || value === 'daily' || value === 'weekly' || value === 'monthly' || value === 'yearly';
}

export function isCalendarEventStatus(value: unknown): value is CalendarEventStatus {
  return value === 'pending' || value === 'inProgress' || value === 'done' || value === 'skipped' || value === 'delayed';
}

export function isDateKey(value: unknown): value is string {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

export function isFiniteNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

export function toDateKey(date: Date | number | string): string {
  const d = date instanceof Date ? date : new Date(date);
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function fromDateKey(dateKey: string): Date {
  const [year, month, day] = dateKey.split('-').map(Number);
  return new Date(year, (month ?? 1) - 1, day ?? 1, 0, 0, 0, 0);
}

export function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 0, 0, 0, 0);
}

export function endOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 999);
}

export function addDays(date: Date, days: number): Date {
  const next = new Date(date);
  next.setDate(next.getDate() + days);
  return next;
}

export function addWeeks(date: Date, weeks: number): Date {
  return addDays(date, weeks * 7);
}

export function addMonths(date: Date, months: number): Date {
  const next = new Date(date);
  next.setMonth(next.getMonth() + months);
  return next;
}

export function addYears(date: Date, years: number): Date {
  const next = new Date(date);
  next.setFullYear(next.getFullYear() + years);
  return next;
}

export function startOfWeek(date: Date): Date {
  const next = startOfDay(date);
  const delta = next.getDay();
  return addDays(next, -delta);
}

export function endOfWeek(date: Date): Date {
  return endOfDay(addDays(startOfWeek(date), 6));
}

export function startOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), 1, 0, 0, 0, 0);
}

export function endOfMonth(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth() + 1, 0, 23, 59, 59, 999);
}

export function startOfYear(date: Date): Date {
  return new Date(date.getFullYear(), 0, 1, 0, 0, 0, 0);
}

export function endOfYear(date: Date): Date {
  return new Date(date.getFullYear(), 11, 31, 23, 59, 59, 999);
}

export function formatMonthTitle(date: Date): string {
  return `${date.getFullYear()}年${date.getMonth() + 1}月`;
}

export function formatDateTitle(date: Date): string {
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
}

export function formatShortDate(date: Date): string {
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

export function formatWeekday(date: Date): string {
  return ['周日', '周一', '周二', '周三', '周四', '周五', '周六'][date.getDay()];
}

export function formatDayLabel(date: Date): string {
  return `${formatDateTitle(date)} ${formatWeekday(date)}`;
}

export function formatClock(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

export function formatTimeRange(startAt: number, endAt: number): string {
  const start = new Date(startAt);
  const end = new Date(endAt);
  return `${formatClock(start)} - ${formatClock(end)}`;
}

export function formatMonthYear(date: Date): string {
  return `${date.getFullYear()}年${date.getMonth() + 1}月`;
}

export function getMonthGrid(date: Date): CalendarDateCell[] {
  const monthStart = startOfMonth(date);
  const firstGridDate = startOfWeek(monthStart);
  const todayKey = toDateKey(new Date());
  const cells: CalendarDateCell[] = [];
  for (let index = 0; index < 42; index += 1) {
    const cellDate = addDays(firstGridDate, index);
    cells.push({
      date: cellDate,
      dateKey: toDateKey(cellDate),
      inCurrentMonth: cellDate.getMonth() === date.getMonth(),
      isToday: toDateKey(cellDate) === todayKey,
    });
  }
  return cells;
}

export function getWeekDates(date: Date): Date[] {
  const start = startOfWeek(date);
  return Array.from({ length: 7 }, (_, index) => addDays(start, index));
}

export function getMonthDates(date: Date): Date[] {
  const start = startOfMonth(date);
  const end = endOfMonth(date);
  const items: Date[] = [];
  let cursor = new Date(start);
  while (cursor <= end) {
    items.push(new Date(cursor));
    cursor = addDays(cursor, 1);
  }
  return items;
}

export function withTime(date: Date, hours: number, minutes = 0): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate(), hours, minutes, 0, 0);
}

export function makeOccurrenceDateKey(event: CalendarEvent, date: Date): string {
  return `${event.id}:${toDateKey(date)}`;
}

export function getEventStatusForDate(event: CalendarEvent, dateKey: string): CalendarEventStatus {
  return event.statusByDateKey[dateKey] ?? event.status;
}

export function setEventStatusForDate(event: CalendarEvent, dateKey: string, status: CalendarEventStatus): CalendarEvent {
  return {
    ...event,
    statusByDateKey: {
      ...event.statusByDateKey,
      [dateKey]: status,
    },
    updatedAt: Date.now(),
  };
}

export function cloneEvent(event: CalendarEvent): CalendarEvent {
  return {
    ...event,
    id: crypto.randomUUID(),
    title: `${event.title} 副本`,
    createdAt: Date.now(),
    updatedAt: Date.now(),
    status: 'pending',
    statusByDateKey: {},
  };
}

export function createDefaultEvent(date = new Date(), partial?: Partial<CalendarEvent>): CalendarEvent {
  const startAt = partial?.startAt ?? withTime(date, Math.min(Math.max(date.getHours(), 9), 21), 0).getTime();
  const endAt = partial?.endAt ?? startAt + 60 * 60 * 1000;
  return normalizeEvent({
    id: partial?.id ?? crypto.randomUUID(),
    title: partial?.title ?? '新建日程',
    startAt,
    endAt,
    allDay: partial?.allDay ?? false,
    categoryId: partial?.categoryId ?? 'work',
    notes: partial?.notes ?? '',
    location: partial?.location ?? '',
    status: partial?.status ?? 'pending',
    statusByDateKey: partial?.statusByDateKey ?? {},
    important: partial?.important ?? false,
    repeat: partial?.repeat ?? createCalendarRepeatRule(),
    reminders: partial?.reminders ?? createCalendarReminderRule(),
    createdAt: partial?.createdAt ?? Date.now(),
    updatedAt: partial?.updatedAt ?? Date.now(),
  })!;
}

export function updateEvent(events: CalendarEvent[], nextEvent: CalendarEvent): CalendarEvent[] {
  return events.map((event) => (event.id === nextEvent.id ? nextEvent : event));
}

export function removeEvent(events: CalendarEvent[], id: string): CalendarEvent[] {
  return events.filter((event) => event.id !== id);
}

export function upsertEvent(events: CalendarEvent[], nextEvent: CalendarEvent): CalendarEvent[] {
  const exists = events.some((event) => event.id === nextEvent.id);
  return exists ? updateEvent(events, nextEvent) : [...events, nextEvent];
}

export function moveDateKey(dateKey: string, viewMode: CalendarViewMode, direction: -1 | 1): string {
  const date = fromDateKey(dateKey);
  if (viewMode === 'day') return toDateKey(addDays(date, direction));
  if (viewMode === 'week') return toDateKey(addWeeks(date, direction));
  if (viewMode === 'month') return toDateKey(addMonths(date, direction));
  return toDateKey(addYears(date, direction));
}

export function getVisibleRange(anchorDate: Date, viewMode: CalendarViewMode): { start: Date; end: Date } {
  if (viewMode === 'day') {
    const start = startOfDay(anchorDate);
    return { start, end: endOfDay(anchorDate) };
  }
  if (viewMode === 'week') {
    const start = startOfWeek(anchorDate);
    return { start, end: endOfWeek(anchorDate) };
  }
  if (viewMode === 'year') {
    const start = startOfYear(anchorDate);
    return { start, end: endOfYear(anchorDate) };
  }
  return { start: startOfMonth(anchorDate), end: endOfMonth(anchorDate) };
}

export function getOccurrencesInRange(events: CalendarEvent[], start: Date, end: Date): CalendarOccurrence[] {
  const rangeStart = start.getTime();
  const rangeEnd = end.getTime();
  const occurrences: CalendarOccurrence[] = [];

  for (const event of events) {
    for (const occurrence of getEventOccurrences(event, start, end)) {
      const occurrenceStart = occurrence.startAt;
      const occurrenceEnd = occurrence.endAt;
      if (occurrenceEnd < rangeStart || occurrenceStart > rangeEnd) {
        continue;
      }
      occurrences.push(occurrence);
    }
  }

  return occurrences.sort((a, b) => a.startAt - b.startAt || a.endAt - b.endAt || a.event.title.localeCompare(b.event.title));
}

export function getEventOccurrences(event: CalendarEvent, rangeStart: Date, rangeEnd: Date): CalendarOccurrence[] {
  const occurrences: CalendarOccurrence[] = [];
  const startTime = event.startAt;
  const endTime = event.endAt;
  const duration = Math.max(15 * 60 * 1000, endTime - startTime);
  const untilTime = event.repeat.until ? startOfDay(fromDateKey(event.repeat.until)).getTime() + 23 * 60 * 60 * 1000 + 59 * 60 * 1000 : Number.POSITIVE_INFINITY;
  const from = rangeStart.getTime();
  const to = rangeEnd.getTime();

  if (event.repeat.frequency === 'none') {
    if (endTime >= from && startTime <= to) {
      occurrences.push({
        event,
        dateKey: toDateKey(startTime),
        startAt: startTime,
        endAt: endTime,
      });
    }
    return occurrences;
  }

  const baseDate = new Date(startTime);
  const baseDateKey = toDateKey(baseDate);
  const baseWeekday = baseDate.getDay();
  const interval = Math.max(1, event.repeat.interval);

  const pushOccurrence = (date: Date) => {
    const dayStart = event.allDay ? startOfDay(date) : withTime(date, baseDate.getHours(), baseDate.getMinutes());
    const occurrenceStart = dayStart.getTime();
    const occurrenceEnd = event.allDay ? addDays(startOfDay(date), 1).getTime() - 1 : occurrenceStart + duration;
    if (occurrenceEnd < from || occurrenceStart > to || occurrenceStart < startTime || occurrenceStart > untilTime) {
      return;
    }
    occurrences.push({
      event,
      dateKey: toDateKey(date),
      startAt: occurrenceStart,
      endAt: occurrenceEnd,
    });
  };

  if (event.repeat.frequency === 'daily') {
    let cursor = startOfDay(new Date(Math.max(startTime, from)));
    if (cursor.getTime() < startTime) {
      cursor = startOfDay(fromDateKey(baseDateKey));
    }
    while (cursor.getTime() <= to && cursor.getTime() <= untilTime) {
      const daysDiff = Math.floor((cursor.getTime() - startOfDay(baseDate).getTime()) / (24 * 60 * 60 * 1000));
      if (daysDiff >= 0 && daysDiff % interval === 0) {
        pushOccurrence(cursor);
      }
      cursor = addDays(cursor, 1);
    }
    return occurrences;
  }

  if (event.repeat.frequency === 'weekly') {
    const weekdays = event.repeat.byWeekday.length > 0 ? event.repeat.byWeekday : [baseWeekday];
    let weekCursor = startOfWeek(new Date(Math.max(startTime, from)));
    if (weekCursor.getTime() < startOfWeek(baseDate).getTime()) {
      weekCursor = startOfWeek(baseDate);
    }
    while (weekCursor.getTime() <= to && weekCursor.getTime() <= untilTime) {
      const weeksDiff = Math.floor((weekCursor.getTime() - startOfWeek(baseDate).getTime()) / (7 * 24 * 60 * 60 * 1000));
      const validWeek = weeksDiff >= 0 && weeksDiff % interval === 0;
      if (validWeek) {
        for (const weekday of weekdays) {
          const candidate = addDays(weekCursor, weekday);
          pushOccurrence(candidate);
        }
      }
      weekCursor = addWeeks(weekCursor, 1);
    }
    return occurrences;
  }

  if (event.repeat.frequency === 'monthly') {
    let monthCursor = startOfMonth(baseDate);
    while (monthCursor.getTime() <= to && monthCursor.getTime() <= untilTime) {
      const monthsDiff = (monthCursor.getFullYear() - baseDate.getFullYear()) * 12 + (monthCursor.getMonth() - baseDate.getMonth());
      if (monthsDiff >= 0 && monthsDiff % interval === 0) {
        const candidate = new Date(
          monthCursor.getFullYear(),
          monthCursor.getMonth(),
          baseDate.getDate(),
          baseDate.getHours(),
          baseDate.getMinutes(),
          0,
          0,
        );
        if (candidate.getMonth() === monthCursor.getMonth()) {
          pushOccurrence(candidate);
        }
      }
      monthCursor = addMonths(monthCursor, 1);
    }
    return occurrences;
  }

  let yearCursor = startOfYear(baseDate);
  while (yearCursor.getTime() <= to && yearCursor.getTime() <= untilTime) {
    const yearsDiff = yearCursor.getFullYear() - baseDate.getFullYear();
    if (yearsDiff >= 0 && yearsDiff % interval === 0) {
      const candidate = new Date(
        yearCursor.getFullYear(),
        baseDate.getMonth(),
        baseDate.getDate(),
        baseDate.getHours(),
        baseDate.getMinutes(),
        0,
        0,
      );
      if (candidate.getFullYear() === yearCursor.getFullYear()) {
        pushOccurrence(candidate);
      }
    }
    yearCursor = addYears(yearCursor, 1);
  }

  return occurrences;
}

export function getOccurrencesForDate(events: CalendarEvent[], dateKey: string): CalendarOccurrence[] {
  const date = fromDateKey(dateKey);
  return getOccurrencesInRange(events, startOfDay(date), endOfDay(date));
}

export function getEventCategory(categoryId: CalendarCategoryId): CalendarCategory {
  return CALENDAR_CATEGORY_MAP[categoryId];
}

export function getCategoryLabel(categoryId: CalendarCategoryId): string {
  return CALENDAR_CATEGORY_MAP[categoryId]?.label ?? categoryId;
}

export function getEventDisplayStatus(event: CalendarEvent, dateKey: string): CalendarEventStatus {
  return event.statusByDateKey[dateKey] ?? event.status;
}

export function resolveCurrentTask(occurrences: CalendarOccurrence[], now = Date.now()): CalendarOccurrence | null {
  const active = occurrences.find((item) => item.startAt <= now && item.endAt >= now);
  if (active) {
    return active;
  }
  return occurrences.find((item) => item.startAt > now) ?? null;
}

export function resolveCompletionRate(occurrences: CalendarOccurrence[]): { completed: number; total: number; percentage: number } {
  const filtered = occurrences.filter((item) => !CALENDAR_CATEGORY_MAP[item.event.categoryId].isSystem);
  const total = filtered.length;
  const completed = filtered.filter((item) => getEventDisplayStatus(item.event, item.dateKey) === 'done').length;
  return {
    completed,
    total,
    percentage: total > 0 ? Math.round((completed / total) * 100) : 0,
  };
}

export function getReminderInstances(events: CalendarEvent[], rangeStart: Date, rangeEnd: Date): Array<{ key: string; event: CalendarEvent; occurrence: CalendarOccurrence; leadMinutes: number; remindAt: number }> {
  const reminders: Array<{ key: string; event: CalendarEvent; occurrence: CalendarOccurrence; leadMinutes: number; remindAt: number }> = [];
  for (const occurrence of getOccurrencesInRange(events, rangeStart, rangeEnd)) {
    if (!occurrence.event.reminders.enabled || occurrence.event.reminders.leadMinutes.length === 0) {
      continue;
    }
    for (const leadMinutes of occurrence.event.reminders.leadMinutes) {
      const anchor = occurrence.event.allDay
        ? withTime(fromDateKey(occurrence.dateKey), 9, 0).getTime()
        : occurrence.startAt;
      const remindAt = anchor - leadMinutes * 60 * 1000;
      reminders.push({
        key: `${occurrence.event.id}:${occurrence.dateKey}:${leadMinutes}`,
        event: occurrence.event,
        occurrence,
        leadMinutes,
        remindAt,
      });
    }
  }
  return reminders.sort((a, b) => a.remindAt - b.remindAt);
}

export function createSeedEvents(now = new Date()): CalendarEvent[] {
  const year = now.getFullYear();
  const month = now.getMonth();
  const today = startOfDay(now);
  const yesterday = addDays(today, -1);
  const tomorrow = addDays(today, 1);
  const twoDaysLater = addDays(today, 2);
  const fourDaysLater = addDays(today, 4);
  const sixDaysLater = addDays(today, 6);

  return [
    createDefaultEvent(yesterday, {
      id: 'seed-work-review',
      title: 'Codex 核验与反馈',
      startAt: withTime(yesterday, 14, 0).getTime(),
      endAt: withTime(yesterday, 15, 30).getTime(),
      categoryId: 'work',
      important: true,
    }),
    createDefaultEvent(today, {
      id: 'seed-acmind-planning',
      title: 'AcMind 规划',
      startAt: withTime(today, 9, 30).getTime(),
      endAt: withTime(today, 10, 30).getTime(),
      categoryId: 'project',
      important: true,
    }),
    createDefaultEvent(today, {
      id: 'seed-team-sync',
      title: '团队例会',
      startAt: withTime(today, 13, 30).getTime(),
      endAt: withTime(today, 14, 30).getTime(),
      categoryId: 'work',
      reminders: { enabled: true, leadMinutes: [30] },
    }),
    createDefaultEvent(tomorrow, {
      id: 'seed-study',
      title: '阅读会',
      startAt: withTime(tomorrow, 19, 0).getTime(),
      endAt: withTime(tomorrow, 20, 0).getTime(),
      categoryId: 'study',
      repeat: createCalendarRepeatRule('weekly', 1, [tomorrow.getDay()]),
    }),
    createDefaultEvent(twoDaysLater, {
      id: 'seed-health',
      title: '健身',
      startAt: withTime(twoDaysLater, 18, 0).getTime(),
      endAt: withTime(twoDaysLater, 19, 0).getTime(),
      categoryId: 'personal',
    }),
    createDefaultEvent(fourDaysLater, {
      id: 'seed-project',
      title: 'PRD 撰写',
      startAt: withTime(fourDaysLater, 10, 0).getTime(),
      endAt: withTime(fourDaysLater, 12, 0).getTime(),
      categoryId: 'project',
      important: true,
    }),
    createDefaultEvent(sixDaysLater, {
      id: 'seed-holiday',
      title: '节假日预留',
      startAt: startOfDay(sixDaysLater).getTime(),
      endAt: addDays(startOfDay(sixDaysLater), 1).getTime(),
      categoryId: 'holiday',
      allDay: true,
    }),
    createDefaultEvent(new Date(year, month, 28, 18, 30), {
      id: 'seed-birthday',
      title: '生日聚会',
      startAt: withTime(new Date(year, month, 28), 18, 30).getTime(),
      endAt: withTime(new Date(year, month, 28), 21, 0).getTime(),
      categoryId: 'birthday',
    }),
  ];
}

export function generateMonthLabel(dateKey: string): string {
  return formatMonthTitle(fromDateKey(dateKey));
}

export function incrementDateKey(dateKey: string, viewMode: CalendarViewMode, direction: -1 | 1): string {
  return moveDateKey(dateKey, viewMode, direction);
}
