import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import { Button, Card } from '../../design-system/components';
import { AcMindIcon } from '../../design-system/icons';
import { useToast } from '../../components/shared/ToastViewport';
import {
  CALENDAR_CATEGORIES,
  CALENDAR_CATEGORY_MAP,
  CalendarCategoryId,
  CalendarEvent,
  CalendarEventStatus,
  CalendarRepeatFrequency,
  CalendarState,
  CalendarViewMode,
  addDays,
  createCalendarReminderRule,
  createCalendarRepeatRule,
  createDefaultEvent,
  endOfDay,
  formatDayLabel,
  formatMonthTitle,
  formatTimeRange,
  fromDateKey,
  getCategoryLabel,
  getEventDisplayStatus,
  getEventOccurrences,
  getEventStatusForDate,
  getMonthGrid,
  getOccurrencesForDate,
  getOccurrencesInRange,
  getReminderInstances,
  incrementDateKey,
  loadCalendarState,
  resolveCompletionRate,
  resolveCurrentTask,
  saveCalendarState,
  setEventStatusForDate,
  startOfDay,
  startOfMonth,
  startOfWeek,
  toDateKey,
  upsertEvent,
  removeEvent,
  cloneEvent,
  withTime,
  type CalendarReminderRule,
  type CalendarRepeatRule,
  type CalendarReviewState,
  type CalendarDateCell,
  type CalendarOccurrence,
} from './calendar';
import { useLayoutMode, type LayoutMode } from '../../hooks/useLayoutMode';

interface EventEditorDraft {
  id: string | null;
  title: string;
  dateKey: string;
  endDateKey: string;
  startTime: string;
  endTime: string;
  allDay: boolean;
  categoryId: CalendarCategoryId;
  notes: string;
  location: string;
  status: CalendarEventStatus;
  important: boolean;
  repeatFrequency: CalendarRepeatFrequency;
  repeatInterval: number;
  repeatWeekdays: number[];
  repeatUntil: string;
  reminderEnabled: boolean;
  reminderLeadMinutes: number[];
}

interface ReviewDraft {
  completed: string;
  blocked: string;
  tomorrow: string;
  exportToWorkspace: boolean;
}

const VIEW_LABELS: Record<CalendarViewMode, string> = {
  day: '日',
  week: '周',
  month: '月',
  year: '年',
};

function CalendarMainFrame({ children }: { children: ReactNode }): JSX.Element {
  return (
    <section className="calendar-main flex h-full w-full min-h-0 min-w-0 flex-col overflow-hidden rounded-[28px] border border-[rgba(15,23,42,0.08)] bg-white/72 shadow-[0_18px_56px_rgba(15,23,42,0.045)] backdrop-blur-[18px]">
      <div className="calendar-main-body flex min-h-0 flex-1 flex-col overflow-hidden p-4">
        {children}
      </div>
    </section>
  );
}

const REMINDER_CHOICES = [0, 10, 30, 60, 120];
const TIMELINE_START_HOUR = 8;
const TIMELINE_END_HOUR = 22;
const TIMELINE_HOUR_HEIGHT = 52;
const TIMELINE_TIME_COLUMN_WIDTH = 56;
const TIMELINE_EVENT_MIN_HEIGHT = 54;
const DAY_START_HOUR = TIMELINE_START_HOUR;
const DAY_END_HOUR = TIMELINE_END_HOUR;
const CALENDAR_ASSIST_PANEL_WIDTH = 260;
const CALENDAR_ASSIST_PANEL_WIDTH_WIDE = 280;
const CALENDAR_ASSIST_PANEL_WIDTH_MEDIUM = 240;
const STORAGE_LAST_VIEW_KEY = 'acmind.calendar.v1.lastView';
const STORAGE_LAST_DATE_KEY = 'acmind.calendar.v1.lastDate';

export function CalendarPage(): JSX.Element {
  const { addToast } = useToast();
  const layoutMode = useLayoutMode();
  const [state, setState] = useState<CalendarState>(() => {
    const base = loadCalendarState();
    const viewMode = loadPersistedViewMode() ?? base.viewMode;
    const activeDateKey = loadPersistedActiveDateKey() ?? base.activeDateKey;
    return { ...base, viewMode, activeDateKey };
  });
  const [editor, setEditor] = useState<{ mode: 'create' | 'edit'; occurrence?: CalendarOccurrence } | null>(null);
  const [detailTarget, setDetailTarget] = useState<CalendarOccurrence | null>(null);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [reviewOpen, setReviewOpen] = useState(false);
  const [todayPanelOpen, setTodayPanelOpen] = useState(false);
  const [reviewDraft, setReviewDraft] = useState<ReviewDraft>(() => buildReviewDraft(state.activeDateKey, state));

  useEffect(() => {
    saveCalendarState(state);
    persistViewMode(state.viewMode);
    persistActiveDateKey(state.activeDateKey);
  }, [state]);

  useEffect(() => {
    setReviewDraft(buildReviewDraft(state.activeDateKey, state));
  }, [state.activeDateKey, state.reviewsByDate]);

  useEffect(() => {
    const scheduleReminderCheck = () => {
      const now = Date.now();
      const windowEnd = addDays(new Date(now), 7);
      const reminders = getReminderInstances(state.events, new Date(now), windowEnd);
      const due = reminders.filter((reminder) => reminder.remindAt <= now && !state.firedReminderKeys[reminder.key]);
      if (due.length === 0) {
        return;
      }

      setState((current) => {
        let nextState = current;
        for (const reminder of due) {
          if (nextState.firedReminderKeys[reminder.key]) {
            continue;
          }
          nextState = {
            ...nextState,
            firedReminderKeys: {
              ...nextState.firedReminderKeys,
              [reminder.key]: Date.now(),
            },
          };
        }
        return nextState;
      });

      for (const reminder of due) {
        const leadText = reminder.leadMinutes === 0 ? '现在' : `${reminder.leadMinutes} 分钟后`;
        const message = `${reminder.event.title} 将在 ${leadText} 开始`;
        addToast(message, 'info');
        void window.acmind.calendar.showNotification('日程提醒', message).catch(() => undefined);
      }
    };

    scheduleReminderCheck();
    const timer = window.setInterval(scheduleReminderCheck, 30_000);
    return () => window.clearInterval(timer);
  }, [addToast, state.events, state.firedReminderKeys]);

  const activeDate = useMemo(() => fromDateKey(state.activeDateKey), [state.activeDateKey]);
  const monthGrid = useMemo(() => getMonthGrid(activeDate), [activeDate]);
  const weekDates = useMemo(() => getWeekDates(activeDate), [activeDate]);
  const selectedDateOccurrences = useMemo(() => getOccurrencesForDate(state.events, state.activeDateKey), [state.activeDateKey, state.events]);
  const completionRate = useMemo(() => resolveCompletionRate(selectedDateOccurrences), [selectedDateOccurrences]);
  const currentTask = useMemo(() => resolveCurrentTask(selectedDateOccurrences), [selectedDateOccurrences]);
  const highlights = state.highlightsByDate[state.activeDateKey]?.items ?? deriveHighlights(selectedDateOccurrences);
  const notes = state.notesByDate[state.activeDateKey] ?? '';
  const review = state.reviewsByDate[state.activeDateKey];
  const visibleYearMonths = useMemo(() => buildYearMonths(activeDate), [activeDate]);

  const filteredSearchResults = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    if (!q) return [];
    return state.events
      .flatMap((event) => getEventOccurrences(event, startOfMonth(new Date()), endOfDay(new Date(Date.now() + 365 * 24 * 60 * 60 * 1000))).map((occurrence) => ({ event, occurrence })))
      .filter(({ event }) => {
        const category = getCategoryLabel(event.categoryId);
        return [event.title, event.notes, event.location, category].some((value) => value.toLowerCase().includes(q));
      })
      .slice(0, 30);
  }, [searchQuery, state.events]);

  const setViewMode = useCallback((viewMode: CalendarViewMode) => {
    setState((current) => ({ ...current, viewMode }));
  }, []);

  const setActiveDateKey = useCallback((dateKey: string) => {
    setState((current) => ({ ...current, activeDateKey: dateKey }));
  }, []);

  const goToday = useCallback(() => {
    setActiveDateKey(toDateKey(new Date()));
  }, [setActiveDateKey]);

  const shiftDate = useCallback((direction: -1 | 1) => {
    setState((current) => ({
      ...current,
      activeDateKey: incrementDateKey(current.activeDateKey, current.viewMode, direction),
    }));
  }, []);

  const openCreate = useCallback((dateKey = state.activeDateKey, allDay = false, startAt?: number) => {
    setEditor({
      mode: 'create',
      occurrence: {
        event: createDefaultEvent(fromDateKey(dateKey), {
          allDay,
          startAt: startAt ?? (allDay ? startOfDay(fromDateKey(dateKey)).getTime() : withTime(fromDateKey(dateKey), 9, 0).getTime()),
          endAt: startAt ? startAt + 60 * 60 * 1000 : (allDay ? addDays(startOfDay(fromDateKey(dateKey)), 1).getTime() : withTime(fromDateKey(dateKey), 10, 0).getTime()),
        }),
        dateKey,
        startAt: startAt ?? (allDay ? startOfDay(fromDateKey(dateKey)).getTime() : withTime(fromDateKey(dateKey), 9, 0).getTime()),
        endAt: startAt ? startAt + 60 * 60 * 1000 : (allDay ? addDays(startOfDay(fromDateKey(dateKey)), 1).getTime() : withTime(fromDateKey(dateKey), 10, 0).getTime()),
      },
    });
  }, [state.activeDateKey]);

  const openEdit = useCallback((occurrence: CalendarOccurrence) => {
    setEditor({ mode: 'edit', occurrence });
  }, []);

  const openDetail = useCallback((occurrence: CalendarOccurrence) => {
    setDetailTarget(occurrence);
  }, []);

  const deleteEventById = useCallback((eventId: string) => {
    setState((current) => ({ ...current, events: removeEvent(current.events, eventId) }));
    setDetailTarget((current) => (current?.event.id === eventId ? null : current));
    addToast('已删除日程', 'success');
  }, [addToast]);

  const saveEvent = useCallback((draft: EventEditorDraft) => {
    const startDate = fromDateKey(draft.dateKey);
    const endDate = fromDateKey(draft.endDateKey);
    const startAt = draft.allDay
      ? startOfDay(startDate).getTime()
      : combineDateTime(draft.dateKey, draft.startTime);
    const endAt = draft.allDay
      ? addDays(startOfDay(endDate), 1).getTime()
      : combineDateTime(draft.endDateKey, draft.endTime);
    const repeat = createCalendarRepeatRule(draft.repeatFrequency, draft.repeatInterval, draft.repeatWeekdays);
    const reminders = createCalendarReminderRule(draft.reminderEnabled, draft.reminderLeadMinutes);

    const nextEvent = createDefaultEvent(startDate, {
      id: draft.id ?? undefined,
      title: draft.title,
      startAt,
      endAt: Math.max(endAt, startAt + 15 * 60 * 1000),
      allDay: draft.allDay,
      categoryId: draft.categoryId,
      notes: draft.notes,
      location: draft.location,
      status: draft.status,
      important: draft.important,
      repeat,
      reminders,
      createdAt: draft.id ? state.events.find((event) => event.id === draft.id)?.createdAt : Date.now(),
      updatedAt: Date.now(),
      statusByDateKey: draft.id ? state.events.find((event) => event.id === draft.id)?.statusByDateKey ?? {} : {},
    });

    setState((current) => ({ ...current, events: upsertEvent(current.events, nextEvent), activeDateKey: draft.dateKey }));
    setEditor(null);
    addToast(draft.id ? '已更新日程' : '已新建日程', 'success');
  }, [addToast, state.events]);

  const duplicateEvent = useCallback((occurrence: CalendarOccurrence) => {
    const nextEvent = cloneEvent(occurrence.event);
    nextEvent.startAt = occurrence.startAt + 24 * 60 * 60 * 1000;
    nextEvent.endAt = occurrence.endAt + 24 * 60 * 60 * 1000;
    setState((current) => ({ ...current, events: [...current.events, nextEvent], activeDateKey: toDateKey(new Date(nextEvent.startAt)) }));
    addToast('已复制日程', 'success');
  }, [addToast]);

  const updateOccurrenceStatus = useCallback((eventId: string, dateKey: string, status: CalendarEventStatus) => {
    setState((current) => ({
      ...current,
      events: current.events.map((event) => (event.id === eventId ? setEventStatusForDate(event, dateKey, status) : event)),
    }));
    addToast(`已标记为${statusLabel(status)}`, 'info');
  }, [addToast]);

  const updateHighlightItems = useCallback((items: string[]) => {
    setState((current) => ({
      ...current,
      highlightsByDate: {
        ...current.highlightsByDate,
        [current.activeDateKey]: {
          items: items.map((item) => item.trim()).filter(Boolean).slice(0, 3),
          updatedAt: Date.now(),
        },
      },
    }));
  }, []);

  const updateNote = useCallback((value: string) => {
    setState((current) => ({
      ...current,
      notesByDate: {
        ...current.notesByDate,
        [current.activeDateKey]: value,
      },
    }));
  }, []);

  const updateReview = useCallback(() => {
    setState((current) => ({
      ...current,
      reviewsByDate: {
        ...current.reviewsByDate,
        [current.activeDateKey]: {
          ...reviewDraft,
          updatedAt: Date.now(),
        },
      },
    }));
    setReviewOpen(false);
    addToast('已保存今日复盘', 'success');
  }, [addToast, reviewDraft]);

  const toggleCategoryVisibility = useCallback((categoryId: CalendarCategoryId) => {
    setState((current) => ({
      ...current,
      categoryVisibility: {
        ...current.categoryVisibility,
        [categoryId]: !current.categoryVisibility[categoryId],
      },
    }));
  }, []);

  const navigateFromSearch = useCallback((occurrence: CalendarOccurrence) => {
    setActiveDateKey(occurrence.dateKey);
    setSearchOpen(false);
    setDetailTarget(occurrence);
  }, [setActiveDateKey]);

  const activeMonthTitle = formatMonthTitle(activeDate);
  const activeDateTitle = formatDayLabel(activeDate);
  const currentTaskStatus = currentTask
    ? (currentTask.startAt <= Date.now() && currentTask.endAt >= Date.now() ? 'inProgress' : getEventStatusForDate(currentTask.event, currentTask.dateKey))
    : 'pending';
  const assistPanelWidth = layoutMode === 'large' ? CALENDAR_ASSIST_PANEL_WIDTH_WIDE : CALENDAR_ASSIST_PANEL_WIDTH;

  return (
    <div className="calendar-page flex h-full min-h-0 flex-col overflow-hidden bg-[#f7f8fa] text-[color:var(--pm-text-primary)]">
      <div className="calendar-header border-b border-[color:var(--border-light)] bg-white/78 backdrop-blur-[18px]">
        <div className="flex h-[96px] min-h-[96px] flex-col justify-end gap-3 px-6 pb-4 pt-5 lg:flex-row lg:items-end lg:justify-between">
          <div className="min-w-0">
            <div className="flex items-center gap-2 text-[12px] text-[color:var(--pm-text-tertiary)]">
              <AcMindIcon name="clock" size={14} />
              <span>AcMind 日程表</span>
            </div>
            <div className="mt-1 flex items-center gap-2 sm:gap-3">
              <h1 className="truncate text-[24px] font-[700] sm:text-[28px]">{activeMonthTitle}</h1>
              <div className="rounded-full border border-[color:var(--border-light)] bg-white/75 px-3 py-1 text-[12px] text-[color:var(--pm-text-tertiary)] shadow-[0_8px_18px_rgba(17,24,39,0.04)]">
                {activeDateTitle}
              </div>
            </div>
          </div>

          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            <SegmentedControl value={state.viewMode} onChange={setViewMode} />
            <div className="flex flex-wrap items-center gap-2">
              <Button variant="secondary" size="sm" onClick={goToday}>
                今天
              </Button>
              <Button variant="icon" size="sm" onClick={() => shiftDate(-1)} title="上一页">
                <AcMindIcon name="arrow-left" size={16} />
              </Button>
              <Button variant="icon" size="sm" onClick={() => shiftDate(1)} title="下一页">
                <AcMindIcon name="arrow-right" size={16} />
              </Button>
              <Button
                variant="primary"
                size="sm"
                leadingIcon={<AcMindIcon name="save" size={14} />}
                onClick={() => openCreate(state.activeDateKey)}
              >
                新建
              </Button>
              <Button variant="icon" size="sm" onClick={() => setSearchOpen(true)} title="搜索">
                <AcMindIcon name="search" size={16} />
              </Button>
              <Button variant="secondary" size="sm" onClick={() => setTodayPanelOpen(true)}>
                今日
              </Button>
            </div>
          </div>
        </div>
      </div>

      <div
        className="calendar-workspace grid min-h-0 flex-1 gap-[18px] overflow-hidden px-6 pb-6 pt-[18px]"
        style={{
          gridTemplateColumns: `${assistPanelWidth}px minmax(0, 1fr)`,
        }}
      >
        <aside
          className="calendar-assist-panel flex min-h-0 min-w-0 flex-col gap-3.5 overflow-auto rounded-[22px] border border-[color:var(--border-light)] bg-white/78 p-4 shadow-[0_12px_28px_rgba(17,24,39,0.04)] backdrop-blur-[16px]"
          style={{
            width: assistPanelWidth,
            minWidth: assistPanelWidth,
            maxWidth: assistPanelWidth,
          }}
        >
          <MiniMonthCalendar
            activeDateKey={state.activeDateKey}
            viewMode={state.viewMode}
            onSelectDate={setActiveDateKey}
            onNavigateMonth={(direction) => setState((current) => ({ ...current, activeDateKey: incrementDateKey(current.activeDateKey, 'month', direction) }))}
          />
          <CategoryFilterList
            categories={CALENDAR_CATEGORIES}
            visibility={state.categoryVisibility}
            onToggle={toggleCategoryVisibility}
          />
        </aside>

        <main className="calendar-main-column flex h-full min-h-0 w-full min-w-0 flex-col overflow-hidden">
          <CalendarMainFrame>
            {state.viewMode === 'month' && (
              <MonthView
                cells={monthGrid}
                events={state.events}
                visibility={state.categoryVisibility}
                activeDateKey={state.activeDateKey}
                onSelectDate={setActiveDateKey}
                onCreate={openCreate}
                onOpenDetail={openDetail}
              />
            )}
            {state.viewMode === 'week' && (
              <WeekView
                weekDates={weekDates}
                activeDateKey={state.activeDateKey}
                events={state.events}
                visibility={state.categoryVisibility}
                onSelectDate={setActiveDateKey}
                onCreate={openCreate}
                onOpenDetail={openDetail}
              />
            )}
            {state.viewMode === 'day' && (
              <DayView
                date={activeDate}
                activeDateKey={state.activeDateKey}
                events={state.events}
                visibility={state.categoryVisibility}
                onCreate={openCreate}
                onOpenDetail={openDetail}
                onSelectDate={setActiveDateKey}
              />
            )}
            {state.viewMode === 'year' && (
              <YearView
                year={activeDate.getFullYear()}
                months={visibleYearMonths}
                activeMonth={activeDate.getMonth()}
                events={state.events}
                visibility={state.categoryVisibility}
                onSelectMonth={(dateKey) => setActiveDateKey(dateKey)}
                onOpenDetail={openDetail}
                onCreate={openCreate}
              />
            )}
          </CalendarMainFrame>
        </main>

        {todayPanelOpen ? (
          <div className="acmind-dialog-overlay z-[70]" onClick={() => setTodayPanelOpen(false)}>
            <div
              className="today-panel-drawer motion-popover absolute right-0 top-0 bottom-0 flex w-[400px] max-w-[90vw] flex-col overflow-hidden rounded-l-[28px] border border-[color:var(--border-light)] bg-white/95 shadow-[-16px_0_40px_rgba(17,24,39,0.10)] backdrop-blur-[20px]"
              onClick={(e) => e.stopPropagation()}
            >
              <div className="flex items-center justify-between border-b border-[color:var(--border-light)] px-5 py-4">
                <div>
                  <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">今日执行面板</div>
                  <div className="mt-0.5 text-[18px] font-semibold">{formatDayLabel(activeDate)}</div>
                </div>
                <button type="button" className="acmind-topbar-icon-btn" onClick={() => setTodayPanelOpen(false)}>
                  <AcMindIcon name="close" size={16} />
                </button>
              </div>
              <div className="flex min-h-0 flex-1 flex-col gap-3 overflow-auto p-4">
                <TodayPanel
                  date={activeDate}
                  dateKey={state.activeDateKey}
                  currentTask={currentTask}
                  currentTaskStatus={currentTaskStatus}
                  occurrences={selectedDateOccurrences}
                  highlights={highlights}
                  notes={notes}
                  completionRate={completionRate}
                  review={review}
                  layoutMode={layoutMode}
                  onUpdateHighlights={updateHighlightItems}
                  onUpdateNote={updateNote}
                  onOpenReview={() => { setTodayPanelOpen(false); setReviewOpen(true); }}
                  onCreate={() => { setTodayPanelOpen(false); openCreate(state.activeDateKey); }}
                  onOpenDetail={(occurrence) => { setTodayPanelOpen(false); setDetailTarget(occurrence); }}
                  onMarkStatus={updateOccurrenceStatus}
                />
              </div>
            </div>
          </div>
        ) : null}
      </div>

      {editor ? (
        <EventEditorDialog
          occurrence={editor.occurrence ?? null}
          mode={editor.mode}
          onClose={() => setEditor(null)}
          onSave={saveEvent}
        />
      ) : null}

      {detailTarget ? (
        <EventDetailDialog
          occurrence={detailTarget}
          onClose={() => setDetailTarget(null)}
          onEdit={() => {
            if (detailTarget) {
              openEdit(detailTarget);
              setDetailTarget(null);
            }
          }}
          onDuplicate={() => duplicateEvent(detailTarget)}
          onDelete={() => deleteEventById(detailTarget.event.id)}
          onMarkStatus={(status) => updateOccurrenceStatus(detailTarget.event.id, detailTarget.dateKey, status)}
        />
      ) : null}

      {searchOpen ? (
        <SearchDialog
          query={searchQuery}
          onQueryChange={setSearchQuery}
          results={filteredSearchResults}
          onClose={() => setSearchOpen(false)}
          onPick={navigateFromSearch}
        />
      ) : null}

      {reviewOpen ? (
        <ReviewDialog
          date={activeDate}
          draft={reviewDraft}
          onClose={() => setReviewOpen(false)}
          onChange={setReviewDraft}
          onSave={updateReview}
        />
      ) : null}
    </div>
  );
}

function SegmentedControl({
  value,
  onChange,
}: {
  value: CalendarViewMode;
  onChange: (value: CalendarViewMode) => void;
}): JSX.Element {
  return (
    <div className="flex items-center rounded-full border border-[color:var(--border-light)] bg-white/82 p-1 shadow-[0_8px_18px_rgba(17,24,39,0.04)]">
      {(Object.keys(VIEW_LABELS) as CalendarViewMode[]).map((mode) => (
        <button
          key={mode}
          type="button"
          className={`rounded-full px-3 py-1.5 text-[12px] font-medium transition-all sm:px-4 sm:text-[13px] ${
            value === mode
              ? 'bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)] shadow-[0_8px_18px_rgba(255,107,43,0.10)]'
              : 'text-[color:var(--pm-text-tertiary)] hover:bg-[color:var(--pm-bg-subtle)] hover:text-[color:var(--pm-text-primary)]'
          }`}
          onClick={() => onChange(mode)}
        >
          {VIEW_LABELS[mode]}
        </button>
      ))}
    </div>
  );
}

function MiniMonthCalendar({
  activeDateKey,
  viewMode,
  onSelectDate,
  onNavigateMonth,
}: {
  activeDateKey: string;
  viewMode: CalendarViewMode;
  onSelectDate: (dateKey: string) => void;
  onNavigateMonth: (direction: -1 | 1) => void;
}): JSX.Element {
  const activeDate = fromDateKey(activeDateKey);
  const cells = getMonthGrid(activeDate);

  return (
    <section className="mini-calendar-card rounded-[18px] border border-[color:var(--border-light)] bg-white/84 p-4">
      <div className="mb-3 flex items-center justify-between gap-2">
        <div>
          <div className="text-[13px] font-semibold">{formatMonthTitle(activeDate)}</div>
          <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">{VIEW_LABELS[viewMode]}视图</div>
        </div>
        <div className="flex items-center gap-1">
          <button type="button" className="acmind-topbar-icon-btn" onClick={() => onNavigateMonth(-1)}>
            <AcMindIcon name="arrow-left" size={14} />
          </button>
          <button type="button" className="acmind-topbar-icon-btn" onClick={() => onNavigateMonth(1)}>
            <AcMindIcon name="arrow-right" size={14} />
          </button>
        </div>
      </div>
      <div className="mini-calendar-grid grid grid-cols-7 gap-1 text-center text-[10px] font-medium text-[color:var(--pm-text-tertiary)]">
        {['日', '一', '二', '三', '四', '五', '六'].map((label) => (
          <div key={label} className="py-1">
            {label}
          </div>
        ))}
      </div>
      <div className="mt-1 grid grid-cols-7 gap-1">
        {cells.map((cell) => {
          const selected = cell.dateKey === activeDateKey;
          return (
            <button
              key={cell.dateKey}
              type="button"
              className={`mini-calendar-day flex aspect-square items-center justify-center rounded-full border text-[11px] transition-all sm:text-[12px] ${
                selected
                  ? 'border-[color:var(--pm-brand)] bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]'
                  : cell.isToday
                    ? 'border-[color:var(--pm-brand-border)] bg-[rgba(255,107,43,0.06)] text-[color:var(--pm-text-primary)]'
                    : 'border-transparent text-[color:var(--pm-text-tertiary)] hover:bg-[color:var(--pm-bg-subtle)]'
              } ${cell.inCurrentMonth ? 'opacity-100' : 'opacity-45'}`}
              onClick={() => onSelectDate(cell.dateKey)}
            >
              {cell.date.getDate()}
            </button>
          );
        })}
      </div>
    </section>
  );
}

function CategoryFilterList({
  categories,
  visibility,
  onToggle,
}: {
  categories: typeof CALENDAR_CATEGORIES;
  visibility: Record<CalendarCategoryId, boolean>;
  onToggle: (categoryId: CalendarCategoryId) => void;
}): JSX.Element {
  return (
    <section className="calendar-category-card rounded-[18px] border border-[color:var(--border-light)] bg-white/84 p-4">
      <div className="mb-3 text-[13px] font-semibold">日历分类</div>
      <div className="space-y-1">
        {categories.map((category) => (
          <button
            key={category.id}
            type="button"
            className="calendar-category-row flex h-8 w-full items-center gap-2 rounded-[12px] px-2 text-left transition-colors hover:bg-[color:var(--pm-bg-subtle)]"
            onClick={() => onToggle(category.id)}
          >
            <span
              className="h-3 w-3 rounded-full border border-white/70 shadow-[0_4px_10px_rgba(17,24,39,0.10)]"
              style={{ background: category.color }}
            />
            <span className="flex-1 text-[13px] text-[color:var(--pm-text-primary)]">{category.label}</span>
            <span className={`rounded-full px-2 py-0.5 text-[10px] ${visibility[category.id] ? 'bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]' : 'bg-[color:var(--pm-bg-subtle)] text-[color:var(--pm-text-tertiary)]'}`}>
              {visibility[category.id] ? '显示' : '隐藏'}
            </span>
          </button>
        ))}
      </div>
    </section>
  );
}

function MonthView({
  cells,
  events,
  visibility,
  activeDateKey,
  onSelectDate,
  onCreate,
  onOpenDetail,
}: {
  cells: CalendarDateCell[];
  events: CalendarEvent[];
  visibility: Record<CalendarCategoryId, boolean>;
  activeDateKey: string;
  onSelectDate: (dateKey: string) => void;
  onCreate: (dateKey: string, allDay?: boolean, startAt?: number) => void;
  onOpenDetail: (occurrence: CalendarOccurrence) => void;
}): JSX.Element {
  return (
    <div className="month-view-content flex h-full min-h-0 flex-1 flex-col gap-2 overflow-hidden">
      <div className="grid grid-cols-7 gap-2 text-center text-[12px] font-medium leading-none text-[color:var(--pm-text-tertiary)]">
        {['日', '一', '二', '三', '四', '五', '六'].map((label) => (
          <div key={label} className="py-1">{label}</div>
        ))}
      </div>
      <div className="month-grid grid min-h-0 flex-1 min-w-0 grid-cols-7 gap-2 overflow-hidden" style={{ gridTemplateRows: 'repeat(6, minmax(76px, 1fr))' }}>
        {cells.map((cell) => {
          const occurrences = getOccurrencesForDate(events, cell.dateKey).filter((item) => visibility[item.event.categoryId]);
          const visibleOccurrences = occurrences.slice(0, 3);
          const moreCount = Math.max(0, occurrences.length - visibleOccurrences.length);
          const selected = cell.dateKey === activeDateKey;
          return (
            <div
              key={cell.dateKey}
              role="button"
              tabIndex={0}
              className={`month-cell group flex min-h-0 flex-col overflow-hidden rounded-[14px] border p-2 text-left transition-all ${
                selected
                  ? 'border-[color:var(--pm-brand)] bg-[rgba(255,107,43,0.05)] shadow-[0_14px_30px_rgba(255,107,43,0.08)]'
                  : cell.isToday
                    ? 'border-[color:var(--pm-brand-border)] bg-[rgba(255,107,43,0.03)]'
                    : 'border-[color:var(--border-light)] bg-white/75 hover:border-[color:var(--pm-border-strong)] hover:bg-white'
              }`}
              onClick={() => onSelectDate(cell.dateKey)}
              onDoubleClick={() => onCreate(cell.dateKey)}
            >
              <div className="flex items-center justify-between">
                <span className={`text-[12px] font-semibold ${cell.inCurrentMonth ? 'text-[color:var(--pm-text-primary)]' : 'text-[color:var(--pm-text-muted)]'}`}>
                  {cell.date.getDate()}
                </span>
                {cell.isToday ? <span className="rounded-full bg-[color:var(--pm-brand-soft)] px-2 py-0.5 text-[10px] font-medium text-[color:var(--pm-brand)]">今天</span> : null}
              </div>
              <div className="mt-2 flex min-h-0 flex-1 flex-col gap-1 overflow-hidden">
                {visibleOccurrences.map((occurrence) => (
                  <EventPill
                    key={`${occurrence.event.id}:${occurrence.dateKey}`}
                    occurrence={occurrence}
                    onClick={(event) => {
                      event.stopPropagation();
                      onOpenDetail(occurrence);
                    }}
                  />
                ))}
                {moreCount > 0 ? <div className="pt-1 text-[11px] text-[color:var(--pm-text-tertiary)]">+{moreCount} 更多</div> : null}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function WeekView({
  weekDates,
  activeDateKey,
  events,
  visibility,
  onSelectDate,
  onCreate,
  onOpenDetail,
}: {
  weekDates: Date[];
  activeDateKey: string;
  events: CalendarEvent[];
  visibility: Record<CalendarCategoryId, boolean>;
  onSelectDate: (dateKey: string) => void;
  onCreate: (dateKey: string, allDay?: boolean, startAt?: number) => void;
  onOpenDetail: (occurrence: CalendarOccurrence) => void;
}): JSX.Element {
  const weekRangeStart = startOfDay(weekDates[0]);
  const weekRangeEnd = endOfDay(weekDates[6]);
  const occurrences = getOccurrencesInRange(events, weekRangeStart, weekRangeEnd).filter((item) => visibility[item.event.categoryId]);
  const timelineRange = resolveTimelineRange(occurrences);
  const hours = buildTimelineHours(timelineRange.startHour, timelineRange.endHour);

  return (
    <div className="week-timeline-scroll min-h-0 flex-1 overflow-auto">
      <div
        className="week-timeline-grid relative grid w-full min-w-[760px] px-3 sm:px-4"
        style={{
          gridTemplateColumns: `${TIMELINE_TIME_COLUMN_WIDTH}px repeat(7, minmax(96px, 1fr))`,
          minHeight: `${hours.length * TIMELINE_HOUR_HEIGHT}px`,
        }}
      >
        <div className="week-time-column border-r border-[color:var(--border-light)]">
          {hours.map((hour) => (
            <div key={hour} className="week-hour-row flex h-[52px] items-start justify-end pr-2 pt-1 text-[10px] text-[color:var(--pm-text-tertiary)] sm:pr-3 sm:text-[11px]">
              {String(hour).padStart(2, '0')}:00
            </div>
          ))}
        </div>
        {weekDates.map((date) => {
          const dayKey = toDateKey(date);
          const dayOccurrences = occurrences.filter((item) => item.dateKey === dayKey);
          const selected = dayKey === activeDateKey;
          return (
            <div
              key={dayKey}
              className={`week-day-column relative w-full min-w-[96px] border-r border-[color:var(--border-light)] ${selected ? 'bg-[rgba(255,107,43,0.025)]' : ''}`}
              onClick={() => onSelectDate(dayKey)}
              onDoubleClick={() => onCreate(dayKey)}
            >
              {hours.map((hour) => (
                <div key={hour} className="week-hour-row h-[52px] border-b border-[color:var(--border-soft)]" />
              ))}
              {dayOccurrences.map((occurrence) => renderTimeBlock(occurrence, onOpenDetail, dayKey, timelineRange, 'week'))}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function DayView({
  date,
  activeDateKey,
  events,
  visibility,
  onCreate,
  onOpenDetail,
  onSelectDate,
}: {
  date: Date;
  activeDateKey: string;
  events: CalendarEvent[];
  visibility: Record<CalendarCategoryId, boolean>;
  onCreate: (dateKey: string, allDay?: boolean, startAt?: number) => void;
  onOpenDetail: (occurrence: CalendarOccurrence) => void;
  onSelectDate: (dateKey: string) => void;
}): JSX.Element {
  const dayKey = toDateKey(date);
  const occurrences = getOccurrencesForDate(events, dayKey).filter((item) => visibility[item.event.categoryId]);
  const timelineRange = resolveTimelineRange(occurrences);
  const hours = buildTimelineHours(timelineRange.startHour, timelineRange.endHour);

  return (
    <div className="day-timeline-scroll min-h-0 flex-1 overflow-auto">
      <div
        className="day-timeline-grid relative grid w-full min-w-0 px-3 sm:px-4"
        style={{
          gridTemplateColumns: `${TIMELINE_TIME_COLUMN_WIDTH}px minmax(0, 1fr)`,
          minHeight: `${hours.length * TIMELINE_HOUR_HEIGHT}px`,
        }}
      >
        <div className="day-time-column border-r border-[color:var(--border-light)]">
          {hours.map((hour) => (
            <div key={hour} className="day-hour-row flex h-[52px] items-start justify-end pr-2 pt-1 text-[11px] text-[color:var(--pm-text-tertiary)] sm:pr-3">
              {String(hour).padStart(2, '0')}:00
            </div>
          ))}
        </div>
        <div
          className={`day-event-lane relative w-full min-w-0 ${dayKey === activeDateKey ? 'bg-[rgba(255,107,43,0.03)]' : ''}`}
          onClick={() => onSelectDate(dayKey)}
          onDoubleClick={() => onCreate(dayKey)}
        >
          {hours.map((hour) => (
            <div key={hour} className="day-hour-row h-[52px] border-b border-[color:var(--border-soft)]" />
          ))}
          {occurrences.map((occurrence) => renderTimeBlock(occurrence, onOpenDetail, dayKey, timelineRange, 'day'))}
        </div>
      </div>
    </div>
  );
}

function YearView({
  year,
  months,
  activeMonth,
  events,
  visibility,
  onSelectMonth,
  onOpenDetail,
  onCreate,
}: {
  year: number;
  months: Date[];
  activeMonth: number;
  events: CalendarEvent[];
  visibility: Record<CalendarCategoryId, boolean>;
  onSelectMonth: (dateKey: string) => void;
  onOpenDetail: (occurrence: CalendarOccurrence) => void;
  onCreate: (dateKey: string, allDay?: boolean, startAt?: number) => void;
}): JSX.Element {
  return (
    <div className="year-view-content grid min-h-0 flex-1 grid-cols-3 gap-4 overflow-auto p-1 pr-2 pb-2">
      {months.map((month) => {
        const monthKey = toDateKey(month);
        const monthOccurrences = getOccurrencesInRange(events, startOfMonth(month), new Date(month.getFullYear(), month.getMonth() + 1, 0, 23, 59, 59, 999)).filter((item) => visibility[item.event.categoryId]);
        return (
          <button
            key={monthKey}
            type="button"
            className={`year-month-card flex h-[176px] flex-col overflow-hidden rounded-[18px] border p-4 text-left transition-all ${
              month.getMonth() === activeMonth
                ? 'border-[color:var(--pm-brand)] bg-[rgba(255,107,43,0.05)] shadow-[0_12px_28px_rgba(255,107,43,0.08)]'
                : 'border-[color:var(--border-light)] bg-white/75 hover:bg-white'
            }`}
            onClick={() => onSelectMonth(monthKey)}
            onDoubleClick={() => onCreate(monthKey)}
          >
            <div className="flex items-center justify-between">
              <div className="text-[15px] font-semibold leading-none">{month.getMonth() + 1} 月</div>
              <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">{monthOccurrences.length} 项</div>
            </div>
            <div className="year-month-mini-grid mt-3 grid flex-1 min-h-0 grid-cols-7 gap-1 text-[10px] leading-none text-[color:var(--pm-text-muted)]">
              {getMonthGrid(month).slice(0, 35).map((cell) => (
                <div key={cell.dateKey} className={`flex h-6 items-center justify-center rounded-md ${cell.isToday ? 'bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]' : ''}`}>
                  {cell.date.getDate()}
                </div>
              ))}
            </div>
            {monthOccurrences.length > 0 ? (
              <div className="year-month-event-summary mt-3 flex flex-nowrap gap-1 overflow-hidden">
                {monthOccurrences.slice(0, 3).map((occurrence) => (
                  <span
                    key={`${occurrence.event.id}:${occurrence.dateKey}`}
                    className="min-w-0 flex-1 truncate rounded-full px-2 py-1 text-[10px] font-medium"
                    style={{ background: CALENDAR_CATEGORY_MAP[occurrence.event.categoryId].softColor, color: CALENDAR_CATEGORY_MAP[occurrence.event.categoryId].color }}
                  >
                    {occurrence.event.title}
                  </span>
                ))}
                {monthOccurrences.length > 3 ? (
                  <span className="rounded-full bg-[color:var(--pm-bg-subtle)] px-2 py-1 text-[10px] font-medium text-[color:var(--pm-text-tertiary)]">
                    +{monthOccurrences.length - 3}
                  </span>
                ) : null}
              </div>
            ) : null}
          </button>
        );
      })}
    </div>
  );
}

function TodayPanel({
  date,
  dateKey,
  currentTask,
  currentTaskStatus,
  occurrences,
  highlights,
  notes,
  completionRate,
  review,
  onUpdateHighlights,
  onUpdateNote,
  onOpenReview,
  onCreate,
  onOpenDetail,
  onMarkStatus,
  layoutMode,
}: {
  date: Date;
  dateKey: string;
  currentTask: CalendarOccurrence | null;
  currentTaskStatus: CalendarEventStatus;
  occurrences: CalendarOccurrence[];
  highlights: string[];
  notes: string;
  completionRate: { completed: number; total: number; percentage: number };
  review: CalendarReviewState | undefined;
  onUpdateHighlights: (items: string[]) => void;
  onUpdateNote: (value: string) => void;
  onOpenReview: () => void;
  onCreate: () => void;
  onOpenDetail: (occurrence: CalendarOccurrence) => void;
  onMarkStatus: (eventId: string, dateKey: string, status: CalendarEventStatus) => void;
  layoutMode: LayoutMode;
}): JSX.Element {
  const [highlightDraft, setHighlightDraft] = useState<string[]>(() => buildHighlightDraft(highlights));

  useEffect(() => {
    setHighlightDraft(buildHighlightDraft(highlights));
  }, [highlights, dateKey]);

  const saveHighlights = useCallback(() => {
    onUpdateHighlights(highlightDraft.map((item) => item.trim()).filter(Boolean).slice(0, 3));
  }, [highlightDraft, onUpdateHighlights]);

  return (
    <div className="today-panel-scroll flex min-h-0 flex-1 flex-col gap-3 overflow-auto pr-1">
      <PanelCard
        title="今日重点"
        action={(
          <button type="button" className="text-[12px] font-medium text-[color:var(--pm-brand)]" onClick={saveHighlights}>
            保存
          </button>
        )}
      >
          <div className="grid gap-2">
            {highlightDraft.map((item, index) => (
              <input
                key={index}
              className="acmind-input h-8 w-full text-[12px]"
              value={item}
              placeholder={`重点 ${index + 1}`}
              onChange={(event) => {
                const next = [...highlightDraft];
                next[index] = event.target.value;
                setHighlightDraft(next);
              }}
            />
          ))}
        </div>
      </PanelCard>

      <PanelCard title="当前任务">
        {currentTask ? (
              <div className="rounded-[14px] border border-[color:var(--border-light)] bg-white/80 p-3">
                <div className="flex items-center justify-between gap-2 text-[12px] text-[color:var(--pm-text-tertiary)]">
              <span>{currentTask.event.allDay ? '全天' : formatTimeRange(currentTask.startAt, currentTask.endAt)}</span>
              <span className="rounded-full px-2 py-0.5 text-[11px]" style={{ background: CALENDAR_CATEGORY_MAP[currentTask.event.categoryId].softColor, color: CALENDAR_CATEGORY_MAP[currentTask.event.categoryId].color }}>
                {statusLabel(currentTaskStatus)}
              </span>
            </div>
            <div className="mt-2 text-[16px] font-semibold">{currentTask.event.title}</div>
            <div className="mt-2 text-[12px] text-[color:var(--pm-text-tertiary)]">
              {currentTask.event.location || '可点击事件查看详情'}
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <Button variant="secondary" size="sm" onClick={() => onMarkStatus(currentTask.event.id, currentTask.dateKey, 'done')}>完成</Button>
              <Button variant="secondary" size="sm" onClick={() => onMarkStatus(currentTask.event.id, currentTask.dateKey, 'delayed')}>延后</Button>
              <Button variant="secondary" size="sm" onClick={() => onMarkStatus(currentTask.event.id, currentTask.dateKey, 'skipped')}>跳过</Button>
            </div>
          </div>
        ) : (
          <EmptyCard title="现在没有正在进行的日程" description="可以休息一下，或快速安排下一件事。" />
        )}
      </PanelCard>

      <PanelCard title="今日事件">
        <div className="space-y-2">
          {occurrences.length > 0 ? occurrences.map((occurrence) => {
            const status = getEventStatusForDate(occurrence.event, occurrence.dateKey);
            return (
              <button
                key={`${occurrence.event.id}:${occurrence.dateKey}`}
                type="button"
                className="flex w-full items-center justify-between gap-2 rounded-[12px] border border-[color:var(--border-light)] bg-white/72 px-3 py-2 text-left transition-colors hover:bg-white"
                onClick={() => onOpenDetail(occurrence)}
              >
                <div className="min-w-0">
                  <div className="truncate text-[13px] font-medium">{occurrence.event.title}</div>
                  <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">{occurrence.event.allDay ? '全天' : formatTimeRange(occurrence.startAt, occurrence.endAt)}</div>
                </div>
                <span className="rounded-full px-2 py-0.5 text-[11px]" style={{ background: CALENDAR_CATEGORY_MAP[occurrence.event.categoryId].softColor, color: CALENDAR_CATEGORY_MAP[occurrence.event.categoryId].color }}>
                  {statusLabel(status)}
                </span>
              </button>
            );
          }) : (
            <div className="rounded-[18px] border border-dashed border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-4 text-[12px] text-[color:var(--pm-text-tertiary)]">
              今天还没有安排
            </div>
          )}
        </div>
      </PanelCard>

      <PanelCard title="快速记录" action={<button type="button" className="text-[12px] font-medium text-[color:var(--pm-brand)]" onClick={onCreate}>新建</button>}>
        <textarea
          value={notes}
          onChange={(event) => onUpdateNote(event.target.value)}
          placeholder="随手记录想法、任务变化、复盘素材……"
          className="acmind-textarea min-h-[72px] w-full text-[12px]"
        />
      </PanelCard>

      <PanelCard title="今日进度">
        <div className="flex items-center gap-4">
          <ProgressRing percentage={completionRate.percentage} />
          <div>
            <div className="text-[28px] font-semibold">{completionRate.percentage}%</div>
            <div className="text-[13px] text-[color:var(--pm-text-tertiary)]">{completionRate.completed} / {completionRate.total} 已完成</div>
            <div className="mt-1 text-[12px] text-[color:var(--pm-text-tertiary)]">继续加油 ✌</div>
          </div>
        </div>
      </PanelCard>

      <PanelCard title="今日复盘">
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-[13px] font-medium">{review ? '已保存今日复盘' : '晚上 21:30 提醒'}</div>
            <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">{review ? '可再次编辑或导出 Markdown' : '记录今天的完成、偏航与明日重点'}</div>
          </div>
          <Button variant="secondary" size="sm" onClick={onOpenReview}>
            {review ? '编辑复盘' : '开始复盘'}
          </Button>
        </div>
      </PanelCard>

      <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">本地存储 · 系统通知</div>
    </div>
  );
}

function EventPill({
  occurrence,
  onClick,
}: {
  occurrence: CalendarOccurrence;
  onClick: (event: React.MouseEvent<HTMLButtonElement>) => void;
}): JSX.Element {
  const category = CALENDAR_CATEGORY_MAP[occurrence.event.categoryId];
  const status = getEventStatusForDate(occurrence.event, occurrence.dateKey);
  return (
    <button
      type="button"
      onClick={onClick}
      className="flex min-w-0 items-center gap-1.5 rounded-full px-2 py-1 text-left text-[11px] font-medium transition-colors hover:brightness-[0.98]"
      style={{
        background: category.softColor,
        color: category.color,
        opacity: status === 'done' ? 0.82 : status === 'skipped' ? 0.76 : 1,
        textDecoration: status === 'done' ? 'line-through' : 'none',
      }}
    >
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: category.color }} />
      <span className="min-w-0 truncate">{occurrence.event.title}</span>
    </button>
  );
}

function renderTimeBlock(
  occurrence: CalendarOccurrence,
  onOpenDetail: (occurrence: CalendarOccurrence) => void,
  dateKey: string,
  timelineRange: { startHour: number; endHour: number },
  mode: 'day' | 'week',
): JSX.Element {
  const category = CALENDAR_CATEGORY_MAP[occurrence.event.categoryId];
  const status = getEventStatusForDate(occurrence.event, dateKey);
  const startHour = timelineRange.startHour;
  const rowHeight = TIMELINE_HOUR_HEIGHT;
  const startMinutes = Math.max(0, minutesFromMidnight(new Date(occurrence.startAt)) - startHour * 60);
  const durationMinutes = Math.max(30, Math.round((occurrence.endAt - occurrence.startAt) / 60000));
  const top = (startMinutes / 60) * rowHeight;
  const height = Math.max(TIMELINE_EVENT_MIN_HEIGHT, (durationMinutes / 60) * rowHeight - 8);
  const isDay = mode === 'day';

  return (
    <button
      key={`${occurrence.event.id}:${dateKey}`}
      type="button"
      onClick={(event) => {
        event.stopPropagation();
        onOpenDetail(occurrence);
      }}
      className={`absolute z-10 overflow-hidden border text-left shadow-[0_10px_22px_rgba(17,24,39,0.06)] transition-colors hover:brightness-[0.98] ${
        isDay ? 'left-[20px] right-[22px] rounded-[14px] px-4 py-3' : 'left-1.5 right-1.5 rounded-[12px] px-2.5 py-2'
      }`}
      style={{
        top: `${top}px`,
        height: `${height}px`,
        background: `linear-gradient(180deg, ${category.softColor}, rgba(255,255,255,0.96))`,
        borderColor: `${category.color}30`,
        color: category.color,
        opacity: status === 'done' ? 0.72 : status === 'skipped' ? 0.5 : 1,
      }}
    >
      <div className="truncate text-[11px] font-semibold leading-none whitespace-nowrap">{occurrence.event.title}</div>
      <div className="mt-1 truncate text-[10px] leading-none whitespace-nowrap text-[color:var(--pm-text-tertiary)]">
        {occurrence.event.allDay ? '全天' : formatTimeRange(occurrence.startAt, occurrence.endAt)}
      </div>
    </button>
  );
}

function PanelCard({
  title,
  action,
  children,
}: {
  title: string;
  action?: React.ReactNode;
  children: React.ReactNode;
}): JSX.Element {
  return (
    <Card variant="base" className="rounded-[14px] border border-[color:var(--border-light)] bg-white/82 p-3 shadow-none">
      <div className="mb-2 flex items-center justify-between gap-2">
        <div className="text-[13px] font-semibold">{title}</div>
        {action}
      </div>
      {children}
    </Card>
  );
}

function EmptyCard({ title, description }: { title: string; description: string }): JSX.Element {
  return (
    <div className="rounded-[18px] border border-dashed border-[color:var(--border-light)] bg-[rgba(255,255,255,0.72)] p-4">
      <div className="text-[14px] font-medium">{title}</div>
      <div className="mt-1 text-[12px] text-[color:var(--pm-text-tertiary)]">{description}</div>
    </div>
  );
}

function ProgressRing({ percentage }: { percentage: number }): JSX.Element {
  const radius = 34;
  const stroke = 6;
  const size = radius * 2 + stroke;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference - (percentage / 100) * circumference;

  return (
    <svg width={size} height={size} className="shrink-0">
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        stroke="rgba(17,24,39,0.08)"
        strokeWidth={stroke}
        fill="none"
      />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={radius}
        stroke="var(--pm-brand)"
        strokeWidth={stroke}
        fill="none"
        strokeDasharray={circumference}
        strokeDashoffset={dashOffset}
        strokeLinecap="round"
        transform={`rotate(-90 ${size / 2} ${size / 2})`}
      />
      <text x="50%" y="50%" dominantBaseline="middle" textAnchor="middle" className="fill-[color:var(--pm-text-primary)] text-[16px] font-semibold">
        {percentage}%
      </text>
    </svg>
  );
}

function EventEditorDialog({
  occurrence,
  mode,
  onClose,
  onSave,
}: {
  occurrence: CalendarOccurrence | null;
  mode: 'create' | 'edit';
  onClose: () => void;
  onSave: (draft: EventEditorDraft) => void;
}): JSX.Element {
  const event = occurrence?.event ?? createDefaultEvent(new Date());
  const date = occurrence ? fromDateKey(occurrence.dateKey) : new Date();
  const [draft, setDraft] = useState<EventEditorDraft>(() => buildEditorDraft(event, occurrence?.dateKey ?? toDateKey(date)));

  useEffect(() => {
    setDraft(buildEditorDraft(event, occurrence?.dateKey ?? toDateKey(date)));
  }, [event.id, occurrence?.dateKey]);

  return (
    <div className="acmind-dialog-overlay z-[80]" onClick={onClose}>
      <div className="acmind-dialog motion-popover max-w-[620px]" onClick={(e) => e.stopPropagation()}>
        <div className="mb-5 flex items-center justify-between">
          <div>
            <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">{mode === 'create' ? '新建日程' : '编辑日程'}</div>
            <div className="text-[20px] font-semibold">{draft.title || '未命名日程'}</div>
          </div>
          <button type="button" className="acmind-topbar-icon-btn" onClick={onClose}>
            <AcMindIcon name="close" size={16} />
          </button>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <Field label="标题 *">
            <input className="acmind-input w-full" value={draft.title} onChange={(e) => setDraft((current) => ({ ...current, title: e.target.value }))} />
          </Field>
          <Field label="分类 *">
            <select className="acmind-input w-full" value={draft.categoryId} onChange={(e) => setDraft((current) => ({ ...current, categoryId: e.target.value as CalendarCategoryId }))}>
              {CALENDAR_CATEGORIES.map((category) => (
                <option key={category.id} value={category.id}>{category.label}</option>
              ))}
            </select>
          </Field>
          <Field label="开始日期">
            <input className="acmind-input w-full" type="date" value={draft.dateKey} onChange={(e) => setDraft((current) => ({ ...current, dateKey: e.target.value }))} />
          </Field>
          <Field label="结束日期">
            <input className="acmind-input w-full" type="date" value={draft.endDateKey} onChange={(e) => setDraft((current) => ({ ...current, endDateKey: e.target.value }))} />
          </Field>
          {!draft.allDay ? (
            <>
              <Field label="开始时间">
                <input className="acmind-input w-full" type="time" value={draft.startTime} onChange={(e) => setDraft((current) => ({ ...current, startTime: e.target.value }))} />
              </Field>
              <Field label="结束时间">
                <input className="acmind-input w-full" type="time" value={draft.endTime} onChange={(e) => setDraft((current) => ({ ...current, endTime: e.target.value }))} />
              </Field>
            </>
          ) : null}
          <Field label="状态">
            <select className="acmind-input w-full" value={draft.status} onChange={(e) => setDraft((current) => ({ ...current, status: e.target.value as CalendarEventStatus }))}>
              <option value="pending">未开始</option>
              <option value="inProgress">进行中</option>
              <option value="done">已完成</option>
              <option value="skipped">已跳过</option>
              <option value="delayed">已延后</option>
            </select>
          </Field>
          <Field label="地点">
            <input className="acmind-input w-full" value={draft.location} onChange={(e) => setDraft((current) => ({ ...current, location: e.target.value }))} />
          </Field>
          <div className="col-span-2 flex items-center gap-3 rounded-[16px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.75)] px-4 py-3">
            <label className="flex items-center gap-2 text-[13px]">
              <input type="checkbox" checked={draft.allDay} onChange={(e) => setDraft((current) => ({ ...current, allDay: e.target.checked }))} />
              全天
            </label>
            <label className="flex items-center gap-2 text-[13px]">
              <input type="checkbox" checked={draft.important} onChange={(e) => setDraft((current) => ({ ...current, important: e.target.checked }))} />
              今日重点
            </label>
          </div>
          <Field label="备注" className="col-span-2">
            <textarea className="acmind-textarea w-full" rows={4} value={draft.notes} onChange={(e) => setDraft((current) => ({ ...current, notes: e.target.value }))} />
          </Field>
          <Field label="重复规则">
            <select className="acmind-input w-full" value={draft.repeatFrequency} onChange={(e) => setDraft((current) => ({ ...current, repeatFrequency: e.target.value as CalendarRepeatFrequency }))}>
              <option value="none">不重复</option>
              <option value="daily">每天</option>
              <option value="weekly">每周</option>
              <option value="monthly">每月</option>
              <option value="yearly">每年</option>
            </select>
          </Field>
          <Field label="重复间隔">
            <input className="acmind-input w-full" type="number" min={1} value={draft.repeatInterval} onChange={(e) => setDraft((current) => ({ ...current, repeatInterval: Number(e.target.value) || 1 }))} />
          </Field>
          {draft.repeatFrequency === 'weekly' ? (
            <Field label="每周重复日" className="col-span-2">
              <div className="flex flex-wrap gap-2">
                {['日', '一', '二', '三', '四', '五', '六'].map((label, index) => {
                  const active = draft.repeatWeekdays.includes(index);
                  return (
                    <button
                      key={label}
                      type="button"
                      className={`rounded-full px-3 py-1.5 text-[12px] ${active ? 'bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]' : 'bg-[color:var(--pm-bg-subtle)] text-[color:var(--pm-text-tertiary)]'}`}
                      onClick={() => setDraft((current) => ({
                        ...current,
                        repeatWeekdays: active ? current.repeatWeekdays.filter((day) => day !== index) : [...current.repeatWeekdays, index].sort(),
                      }))}
                    >
                      {label}
                    </button>
                  );
                })}
              </div>
            </Field>
          ) : null}
          <Field label="重复截止">
            <input className="acmind-input w-full" type="date" value={draft.repeatUntil} onChange={(e) => setDraft((current) => ({ ...current, repeatUntil: e.target.value }))} />
          </Field>
          <Field label="提醒">
            <div className="flex items-center gap-2">
              <input type="checkbox" checked={draft.reminderEnabled} onChange={(e) => setDraft((current) => ({ ...current, reminderEnabled: e.target.checked }))} />
              <span className="text-[13px]">启用提醒</span>
            </div>
          </Field>
          {draft.reminderEnabled ? (
            <Field label="提醒提前时间" className="col-span-2">
              <div className="flex flex-wrap gap-2">
                {REMINDER_CHOICES.map((minutes) => {
                  const active = draft.reminderLeadMinutes.includes(minutes);
                  return (
                    <button
                      key={minutes}
                      type="button"
                      className={`rounded-full px-3 py-1.5 text-[12px] ${active ? 'bg-[color:var(--pm-brand-soft)] text-[color:var(--pm-brand)]' : 'bg-[color:var(--pm-bg-subtle)] text-[color:var(--pm-text-tertiary)]'}`}
                      onClick={() => setDraft((current) => ({
                        ...current,
                        reminderLeadMinutes: active ? current.reminderLeadMinutes.filter((item) => item !== minutes) : [...current.reminderLeadMinutes, minutes].sort((a, b) => a - b),
                      }))}
                    >
                      {minutes === 0 ? '准点' : `${minutes} 分钟`}
                    </button>
                  );
                })}
              </div>
            </Field>
          ) : null}
        </div>
        <div className="mt-5 flex items-center justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={onClose}>取消</Button>
          <Button variant="primary" size="sm" onClick={() => onSave(draft)}>保存</Button>
        </div>
      </div>
    </div>
  );
}

function EventDetailDialog({
  occurrence,
  onClose,
  onEdit,
  onDuplicate,
  onDelete,
  onMarkStatus,
}: {
  occurrence: CalendarOccurrence;
  onClose: () => void;
  onEdit: () => void;
  onDuplicate: () => void;
  onDelete: () => void;
  onMarkStatus: (status: CalendarEventStatus) => void;
}): JSX.Element {
  const category = CALENDAR_CATEGORY_MAP[occurrence.event.categoryId];
  const status = getEventStatusForDate(occurrence.event, occurrence.dateKey);
  return (
    <div className="acmind-dialog-overlay z-[80]" onClick={onClose}>
      <div className="acmind-dialog motion-popover max-w-[540px]" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">事件详情</div>
            <div className="mt-1 text-[22px] font-semibold">{occurrence.event.title}</div>
            <div className="mt-2 flex flex-wrap gap-2 text-[12px]">
              <span className="rounded-full px-2 py-1" style={{ background: category.softColor, color: category.color }}>{category.label}</span>
              <span className="rounded-full bg-[color:var(--pm-bg-subtle)] px-2 py-1 text-[color:var(--pm-text-tertiary)]">{statusLabel(status)}</span>
              <span className="rounded-full bg-[color:var(--pm-bg-subtle)] px-2 py-1 text-[color:var(--pm-text-tertiary)]">{occurrence.event.allDay ? '全天' : formatTimeRange(occurrence.startAt, occurrence.endAt)}</span>
            </div>
          </div>
          <button type="button" className="acmind-topbar-icon-btn" onClick={onClose}>
            <AcMindIcon name="close" size={16} />
          </button>
        </div>

        <div className="mt-5 grid grid-cols-2 gap-3 text-[13px]">
          <DetailField label="日期" value={occurrence.dateKey} />
          <DetailField label="地点" value={occurrence.event.location || '—'} />
          <DetailField label="重复" value={formatRepeat(occurrence.event.repeat)} />
          <DetailField label="提醒" value={formatReminder(occurrence.event.reminders)} />
          <DetailField label="创建时间" value={new Date(occurrence.event.createdAt).toLocaleString('zh-CN')} />
          <DetailField label="更新时间" value={new Date(occurrence.event.updatedAt).toLocaleString('zh-CN')} />
        </div>

        <div className="mt-4 rounded-[18px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.75)] p-4">
          <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">备注</div>
          <div className="mt-1 whitespace-pre-wrap text-[13px] leading-[1.7] text-[color:var(--pm-text-secondary)]">
            {occurrence.event.notes || '暂无备注'}
          </div>
        </div>

        <div className="mt-5 flex flex-wrap gap-2">
          <Button variant="secondary" size="sm" onClick={onEdit}>编辑</Button>
          <Button variant="secondary" size="sm" onClick={onDuplicate}>复制</Button>
          <Button variant="secondary" size="sm" onClick={() => onMarkStatus('done')}>标记完成</Button>
          <Button variant="secondary" size="sm" onClick={() => onMarkStatus('delayed')}>延后</Button>
          <Button variant="secondary" size="sm" onClick={() => onMarkStatus('skipped')}>跳过</Button>
          <Button variant="danger" size="sm" onClick={() => {
            if (window.confirm('确认删除此日程？')) {
              onDelete();
            }
          }}>删除</Button>
        </div>
      </div>
    </div>
  );
}

function SearchDialog({
  query,
  onQueryChange,
  results,
  onClose,
  onPick,
}: {
  query: string;
  onQueryChange: (value: string) => void;
  results: Array<{ event: CalendarEvent; occurrence: CalendarOccurrence }>;
  onClose: () => void;
  onPick: (occurrence: CalendarOccurrence) => void;
}): JSX.Element {
  return (
    <div className="acmind-dialog-overlay z-[80]" onClick={onClose}>
      <div className="acmind-dialog motion-popover max-w-[620px]" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between gap-3">
          <div>
            <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">搜索日程</div>
            <div className="text-[20px] font-semibold">查找事件</div>
          </div>
          <button type="button" className="acmind-topbar-icon-btn" onClick={onClose}>
            <AcMindIcon name="close" size={16} />
          </button>
        </div>
        <div className="mt-4">
          <input
            autoFocus
            className="acmind-input w-full"
            placeholder="搜索标题、备注、地点或分类…"
            value={query}
            onChange={(e) => onQueryChange(e.target.value)}
          />
        </div>
        <div className="mt-4 max-h-[420px] space-y-2 overflow-auto">
          {results.length > 0 ? results.map(({ occurrence }) => (
            <button
              key={`${occurrence.event.id}:${occurrence.dateKey}`}
              type="button"
              className="flex w-full items-center justify-between rounded-[16px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.8)] px-4 py-3 text-left transition-colors hover:bg-white"
              onClick={() => onPick(occurrence)}
            >
              <div>
                <div className="text-[14px] font-semibold">{occurrence.event.title}</div>
                <div className="mt-1 text-[12px] text-[color:var(--pm-text-tertiary)]">{occurrence.dateKey} · {getCategoryLabel(occurrence.event.categoryId)}</div>
              </div>
              <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">{occurrence.event.allDay ? '全天' : formatTimeRange(occurrence.startAt, occurrence.endAt)}</div>
            </button>
          )) : (
            <EmptyCard title="没有找到相关日程" description="试试搜索标题、地点或备注关键词。" />
          )}
        </div>
      </div>
    </div>
  );
}

function ReviewDialog({
  date,
  draft,
  onClose,
  onChange,
  onSave,
}: {
  date: Date;
  draft: ReviewDraft;
  onClose: () => void;
  onChange: (draft: ReviewDraft) => void;
  onSave: () => void;
}): JSX.Element {
  const markdown = buildReviewMarkdown(date, draft);
  return (
    <div className="acmind-dialog-overlay z-[80]" onClick={onClose}>
      <div className="acmind-dialog motion-popover max-w-[680px]" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-[12px] text-[color:var(--pm-text-tertiary)]">今日复盘</div>
            <div className="text-[20px] font-semibold">{formatDayLabel(date)}</div>
          </div>
          <button type="button" className="acmind-topbar-icon-btn" onClick={onClose}>
            <AcMindIcon name="close" size={16} />
          </button>
        </div>

        <div className="mt-5 grid gap-3">
          <Field label="今天完成了什么？">
            <textarea className="acmind-textarea w-full" rows={3} value={draft.completed} onChange={(e) => onChange({ ...draft, completed: e.target.value })} />
          </Field>
          <Field label="今天哪里偏航了？">
            <textarea className="acmind-textarea w-full" rows={3} value={draft.blocked} onChange={(e) => onChange({ ...draft, blocked: e.target.value })} />
          </Field>
          <Field label="明天最重要的一件事是什么？">
            <textarea className="acmind-textarea w-full" rows={3} value={draft.tomorrow} onChange={(e) => onChange({ ...draft, tomorrow: e.target.value })} />
          </Field>
          <label className="flex items-center gap-2 text-[13px]">
            <input type="checkbox" checked={draft.exportToWorkspace} onChange={(e) => onChange({ ...draft, exportToWorkspace: e.target.checked })} />
            导出到工作台
          </label>
          <Field label="Markdown 预览">
            <textarea className="acmind-textarea w-full" rows={8} readOnly value={markdown} />
          </Field>
        </div>

        <div className="mt-5 flex items-center justify-end gap-2">
          <Button variant="secondary" size="sm" onClick={onClose}>取消</Button>
          <Button variant="primary" size="sm" onClick={onSave}>保存复盘</Button>
        </div>
      </div>
    </div>
  );
}

function Field({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}): JSX.Element {
  return (
    <label className={`block ${className ?? ''}`}>
      <div className="mb-1.5 text-[11px] font-medium uppercase tracking-[0.06em] text-[color:var(--pm-text-tertiary)]">{label}</div>
      {children}
    </label>
  );
}

function DetailField({ label, value }: { label: string; value: string }): JSX.Element {
  return (
    <div className="rounded-[14px] border border-[color:var(--border-light)] bg-[rgba(255,255,255,0.75)] px-3 py-2">
      <div className="text-[11px] text-[color:var(--pm-text-tertiary)]">{label}</div>
      <div className="mt-1 text-[13px] font-medium">{value}</div>
    </div>
  );
}

function buildEditorDraft(event: CalendarEvent, dateKey: string): EventEditorDraft {
  const start = new Date(event.startAt);
  const end = new Date(event.endAt);
  return {
    id: event.id,
    title: event.title,
    dateKey,
    endDateKey: toDateKey(new Date(event.endAt - 1)),
    startTime: formatClock(start),
    endTime: formatClock(end),
    allDay: event.allDay,
    categoryId: event.categoryId,
    notes: event.notes,
    location: event.location,
    status: event.status,
    important: event.important,
    repeatFrequency: event.repeat.frequency,
    repeatInterval: event.repeat.interval,
    repeatWeekdays: event.repeat.byWeekday.length > 0 ? event.repeat.byWeekday : [start.getDay()],
    repeatUntil: event.repeat.until ?? '',
    reminderEnabled: event.reminders.enabled,
    reminderLeadMinutes: event.reminders.leadMinutes.length > 0 ? event.reminders.leadMinutes : [30],
  };
}

function buildReviewDraft(dateKey: string, state: CalendarState): ReviewDraft {
  const review = state.reviewsByDate[dateKey];
  return {
    completed: review?.completed ?? '',
    blocked: review?.blocked ?? '',
    tomorrow: review?.tomorrow ?? '',
    exportToWorkspace: review?.exportToWorkspace ?? false,
  };
}

function buildHighlightDraft(highlights: string[]): string[] {
  return [0, 1, 2].map((index) => highlights[index] ?? '');
}

function resolveTimelineRange(occurrences: CalendarOccurrence[]): { startHour: number; endHour: number } {
  let startHour = TIMELINE_START_HOUR;
  let endHour = TIMELINE_END_HOUR;

  for (const occurrence of occurrences) {
    const start = new Date(occurrence.startAt);
    const end = new Date(occurrence.endAt);
    startHour = Math.min(startHour, start.getHours());
    endHour = Math.max(endHour, end.getMinutes() > 0 ? end.getHours() + 1 : end.getHours());
  }

  return {
    startHour: Math.max(0, startHour),
    endHour: Math.min(23, Math.max(startHour, endHour)),
  };
}

function buildTimelineHours(startHour: number, endHour: number): number[] {
  const clampedStart = Math.max(0, Math.min(23, startHour));
  const clampedEnd = Math.max(clampedStart, Math.min(23, endHour));
  return Array.from({ length: clampedEnd - clampedStart + 1 }, (_, index) => clampedStart + index);
}

function buildYearMonths(date: Date): Date[] {
  return Array.from({ length: 12 }, (_, index) => new Date(date.getFullYear(), index, 1));
}

function formatClock(date: Date): string {
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function combineDateTime(dateKey: string, time: string): number {
  const [hours, minutes] = time.split(':').map(Number);
  const base = fromDateKey(dateKey);
  return new Date(base.getFullYear(), base.getMonth(), base.getDate(), hours || 0, minutes || 0, 0, 0).getTime();
}

function minutesFromMidnight(date: Date): number {
  return date.getHours() * 60 + date.getMinutes();
}

function statusLabel(status: CalendarEventStatus): string {
  switch (status) {
    case 'done':
      return '已完成';
    case 'skipped':
      return '已跳过';
    case 'delayed':
      return '已延后';
    case 'inProgress':
      return '进行中';
    case 'pending':
    default:
      return '未开始';
  }
}

function formatRepeat(rule: CalendarRepeatRule): string {
  if (rule.frequency === 'none') {
    return '不重复';
  }
  const interval = rule.interval > 1 ? `${rule.interval} ` : '';
  switch (rule.frequency) {
    case 'daily':
      return `每${interval}天`;
    case 'weekly':
      return `每${interval}周`;
    case 'monthly':
      return `每${interval}月`;
    case 'yearly':
      return `每${interval}年`;
    default:
      return '不重复';
  }
}

function formatReminder(rule: CalendarReminderRule): string {
  if (!rule.enabled || rule.leadMinutes.length === 0) {
    return '不提醒';
  }
  return rule.leadMinutes.map((minutes) => (minutes === 0 ? '准点' : `${minutes} 分钟前`)).join('、');
}

function buildReviewMarkdown(date: Date, draft: ReviewDraft): string {
  return [
    `# ${formatDayLabel(date)} 复盘`,
    '',
    '## 今天完成了什么',
    draft.completed || '（空）',
    '',
    '## 今天哪里偏航了',
    draft.blocked || '（空）',
    '',
    '## 明天最重要的一件事',
    draft.tomorrow || '（空）',
    '',
    `## 导出到工作台`,
    draft.exportToWorkspace ? '是' : '否',
  ].join('\n');
}

function deriveHighlights(occurrences: CalendarOccurrence[]): string[] {
  return occurrences
    .filter((item) => item.event.important || item.event.categoryId === 'project' || item.event.categoryId === 'work')
    .slice(0, 3)
    .map((item) => item.event.title);
}

function getWeekDates(date: Date): Date[] {
  const start = startOfWeek(date);
  return Array.from({ length: 7 }, (_, index) => addDays(start, index));
}

function persistViewMode(viewMode: CalendarViewMode): void {
  try {
    window.localStorage.setItem(STORAGE_LAST_VIEW_KEY, viewMode);
  } catch {
    // noop
  }
}

function loadPersistedViewMode(): CalendarViewMode | null {
  try {
    const value = window.localStorage.getItem(STORAGE_LAST_VIEW_KEY);
    return value === 'day' || value === 'week' || value === 'month' || value === 'year' ? value : null;
  } catch {
    return null;
  }
}

function persistActiveDateKey(dateKey: string): void {
  try {
    window.localStorage.setItem(STORAGE_LAST_DATE_KEY, dateKey);
  } catch {
    // noop
  }
}

function loadPersistedActiveDateKey(): string | null {
  try {
    const value = window.localStorage.getItem(STORAGE_LAST_DATE_KEY);
    return value && /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
  } catch {
    return null;
  }
}
