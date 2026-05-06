import { useCallback, useEffect, useRef, useState } from 'react';
import type { MediaInfo, CalendarEvent } from '../../../shared/types';

// ═══════════════════════════════════════════════════════════════════════
// Constants — Sizing.swift
// ═══════════════════════════════════════════════════════════════════════

const WINDOW_W = 640;
const WINDOW_H = 280;
const OPEN_W = 640;
const OPEN_H = 260;
const SHADOW_PAD = 20;

const CR = {
  opened: { top: 19, bottom: 24 },
  closed: { top: 6, bottom: 14 },
};

const ART = {
  opened: { w: 90, h: 90, r: 13 },
  closed: { w: 20, h: 20, r: 4 },
};

const CLOSED_H = 32;

// ═══════════════════════════════════════════════════════════════════════
// Animation curves — ContentView.swift / NotchViewModel.swift
// ═══════════════════════════════════════════════════════════════════════

// Open:  spring(response: 0.42, dampingFraction: 0.8)
const ANIM_OPEN = 'all 0.42s cubic-bezier(0.32, 0.72, 0, 1)';
// Close: spring(response: 0.45, dampingFraction: 1.0)
const ANIM_CLOSE = 'all 0.45s cubic-bezier(0, 1, 0, 1)';
// Hover: interactiveSpring(response: 0.38, dampingFraction: 0.8)
const ANIM_HOVER = 'all 0.38s cubic-bezier(0.32, 0.72, 0, 1)';
// Slider: spring(response: 0.35, dampingFraction: 0.7)
const ANIM_SLIDER = 'all 0.35s cubic-bezier(0.35, 0.7, 0, 1)';
// Content toggle: .easeInOut(duration: 0.2)
const ANIM_CONTENT = 'all 0.2s ease-in-out';
// Hover button: .smooth(duration: 0.3)
const ANIM_BTN = 'all 0.3s ease';

// ═══════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════

function formatTime(sec: number): string {
  if (sec < 0 || !isFinite(sec)) return '-0:00';
  const m = Math.floor(sec / 60);
  const s = Math.floor(sec % 60);
  return `${m}:${s.toString().padStart(2, '0')}`;
}

function getWeekDates(): Date[] {
  const today = new Date();
  const dow = today.getDay();
  const dates: Date[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(today);
    d.setDate(today.getDate() - dow + i);
    dates.push(d);
  }
  return dates;
}

const WEEKDAYS = ['日', '一', '二', '三', '四', '五', '六'];

// ═══════════════════════════════════════════════════════════════════════
// SVG Icons — SF Symbols equivalents
// ═══════════════════════════════════════════════════════════════════════

function IcBackward({ size = 15 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" />
    </svg>
  );
}

function IcForward({ size = 15 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" />
    </svg>
  );
}

function IcPlay({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M8 5v14l11-7z" />
    </svg>
  );
}

function IcPause({ size = 20 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M6 4h4v16H6zM14 4h4v16h-4z" />
    </svg>
  );
}

function IcShuffle({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M16 3h5v5" /><path d="M4 20L21 3" /><path d="M21 16v5h-5" /><path d="M15 15l6 6" /><path d="M4 4l5 5" />
    </svg>
  );
}

function IcRepeat({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M17 1l4 4-4 4" /><path d="M3 11V9a4 4 0 014-4h14" /><path d="M7 23l-4-4 4-4" /><path d="M21 13v2a4 4 0 01-4 4H3" />
    </svg>
  );
}

function IcMusicNote({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
    </svg>
  );
}

function IcMusicNoteSlash({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M9 18V5l12-2v13" /><circle cx="6" cy="18" r="3" /><circle cx="18" cy="16" r="3" />
      <line x1="2" y1="2" x2="22" y2="22" stroke="currentColor" strokeWidth="2" />
    </svg>
  );
}

function IcGear({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M12 15.5A3.5 3.5 0 018.5 12 3.5 3.5 0 0112 8.5a3.5 3.5 0 013.5 3.5 3.5 3.5 0 01-3.5 3.5m7.43-2.53c.04-.32.07-.64.07-.97s-.03-.66-.07-1l2.11-1.63c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65C14.46 2.18 14.25 2 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64L4.57 11c-.04.34-.07.67-.07 1s.03.65.07.97l-2.11 1.66c-.19.15-.25.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1.01c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.58 1.69-.98l2.49 1.01c.22.08.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.66z" />
    </svg>
  );
}

function IcGrid({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <rect x="3" y="3" width="8" height="8" rx="1.5" />
      <rect x="13" y="3" width="8" height="8" rx="1.5" />
      <rect x="3" y="13" width="8" height="8" rx="1.5" />
      <rect x="13" y="13" width="8" height="8" rx="1.5" />
    </svg>
  );
}

function IcCamera({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  );
}

function IcChat({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z" />
    </svg>
  );
}

function IcCalendar({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" />
    </svg>
  );
}

function IcPencil({ size = 12 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20h9" /><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z" />
    </svg>
  );
}

// ═══════════════════════════════════════════════════════════════════════
// DashboardWidgetPage — faithful port of NotchContentView.swift
// ═══════════════════════════════════════════════════════════════════════

export function DashboardWidgetPage(): JSX.Element {
  // ── State (mirrors @State / @ObservedObject) ──────────────────────
  const [expanded, setExpanded] = useState(false);
  const [isHovering, setIsHovering] = useState(false);
  const [media, setMedia] = useState<MediaInfo | null>(null);
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [showMusicContent, setShowMusicContent] = useState(true);
  const [isDragging, setIsDragging] = useState(false);
  const [sliderValue, setSliderValue] = useState(0);
  const [quickNoteText, setQuickNoteText] = useState(() => {
    try { return localStorage.getItem('acmind.quicknote') ?? ''; } catch { return ''; }
  });

  // ── Refs ───────────────────────────────────────────────────────────
  const hoverTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const closeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const pollRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const sliderTrackRef = useRef<HTMLDivElement>(null);
  const isDraggingRef = useRef(false);

  // ── Derived ────────────────────────────────────────────────────────
  const hasMusic = !!(media && media.state !== 'stopped' && media.trackName);
  const isPlaying = media?.state === 'playing';
  const duration = media?.duration ?? 0;
  const position = media?.position ?? 0;
  const displayPos = isDragging ? sliderValue : position;
  const progress = duration > 0 ? Math.min(Math.max(displayPos / duration, 0), 1) : 0;
  const showShadow = expanded || isHovering;

  // ── Calendar helpers ───────────────────────────────────────────────
  const weekDates = getWeekDates();
  const now = new Date();
  const todayDay = now.getDate();
  const todayMonth = now.getMonth();

  // ── IPC: widget:state-changed listener ─────────────────────────────
  useEffect(() => {
    const handler = (_e: Electron.IpcRendererEvent, data: { expanded: boolean }) => {
      setExpanded(data.expanded);
    };
    try {
      (window as any).electron?.ipcRenderer?.on('widget:state-changed', handler);
      return () => {
        (window as any).electron?.ipcRenderer?.removeListener('widget:state-changed', handler);
      };
    } catch {
      return;
    }
  }, []);

  // ── IPC: fetch media ───────────────────────────────────────────────
  const fetchMedia = useCallback(async () => {
    try {
      const res = await window.acmind.dashboardWidget.getMedia();
      if (res.success && res.media) setMedia(res.media);
    } catch { /* silent */ }
  }, []);

  // ── IPC: fetch calendar ────────────────────────────────────────────
  const fetchCalendar = useCallback(async () => {
    try {
      const res = await window.acmind.dashboardWidget.getCalendar();
      if (res.success && res.events) setEvents(res.events);
    } catch { /* silent */ }
  }, []);

  // ── Polling (every 1 s) ───────────────────────────────────────────
  useEffect(() => {
    fetchMedia();
    fetchCalendar();
    pollRef.current = setInterval(fetchMedia, 1000);
    return () => { if (pollRef.current) clearInterval(pollRef.current); };
  }, [fetchMedia, fetchCalendar]);

  // ── Media control ──────────────────────────────────────────────────
  const mediaControl = useCallback(async (action: 'playpause' | 'next' | 'previous') => {
    try {
      await window.acmind.dashboardWidget.mediaControl(action);
      setTimeout(fetchMedia, 300);
    } catch { /* silent */ }
  }, [fetchMedia]);

  // ── Toggle expanded (onTapGesture) ────────────────────────────────
  const handleToggle = useCallback(() => {
    const next = !expanded;
    setExpanded(next);
    try {
      (window as any).electron?.ipcRenderer?.send(next ? 'widget:expand' : 'widget:collapse');
    } catch { /* silent */ }
  }, [expanded]);

  // ── Hover management (handleHover lines 1081-1112) ────────────────
  const handleMouseEnter = useCallback(() => {
    // Cancel pending close
    if (closeTimerRef.current) { clearTimeout(closeTimerRef.current); closeTimerRef.current = null; }
    // Cancel pending hover
    if (hoverTimerRef.current) { clearTimeout(hoverTimerRef.current); hoverTimerRef.current = null; }

    setIsHovering(true);

    // Start 300 ms hover task -> open
    hoverTimerRef.current = setTimeout(() => {
      hoverTimerRef.current = null;
      setExpanded(prev => {
        if (!prev) {
          try { (window as any).electron?.ipcRenderer?.send('widget:expand'); } catch { /* */ }
          return true;
        }
        return prev;
      });
    }, 300);
  }, []);

  const handleMouseLeave = useCallback(() => {
    // Cancel pending hover task
    if (hoverTimerRef.current) { clearTimeout(hoverTimerRef.current); hoverTimerRef.current = null; }

    setIsHovering(false);

    // Start 2 s close task
    closeTimerRef.current = setTimeout(() => {
      closeTimerRef.current = null;
      setExpanded(prev => {
        if (prev) {
          try { (window as any).electron?.ipcRenderer?.send('widget:collapse'); } catch { /* */ }
          return false;
        }
        return prev;
      });
    }, 2000);
  }, []);

  // ── Reset isHovering when notch closes ────────────────────────────
  useEffect(() => {
    if (!expanded) setIsHovering(false);
  }, [expanded]);

  // ── Slider drag (musicSlider lines 908-965) ───────────────────────
  const handleSliderDown = useCallback((e: React.MouseEvent<HTMLDivElement>) => {
    e.stopPropagation();
    const track = sliderTrackRef.current;
    if (!track) return;
    const rect = track.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const pct = Math.min(Math.max(x / rect.width, 0), 1);
    isDraggingRef.current = true;
    setIsDragging(true);
    setSliderValue(pct * duration);

    const onMove = (ev: MouseEvent) => {
      const mx = ev.clientX - rect.left;
      const mp = Math.min(Math.max(mx / rect.width, 0), 1);
      setSliderValue(mp * duration);
    };
    const onUp = () => {
      isDraggingRef.current = false;
      setIsDragging(false);
      document.removeEventListener('mousemove', onMove);
      document.removeEventListener('mouseup', onUp);
      // Seek — np.seek(to:)
      // No seek IPC available; just let the next poll update position
    };
    document.addEventListener('mousemove', onMove);
    document.addEventListener('mouseup', onUp);
  }, [duration]);

  // ── Quick note persist ─────────────────────────────────────────────
  useEffect(() => {
    try { localStorage.setItem('acmind.quicknote', quickNoteText); } catch { /* */ }
  }, [quickNoteText]);

  // ── Closed lyrics line (closedLyricsView lines 243-266) ───────────
  const closedLyricLine = hasMusic
    ? (media!.trackName || '未知歌曲')
    : '';

  // ── Render ─────────────────────────────────────────────────────────
  return (
    <div
      className="notch-root"
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
    >
      {/* ═══ ZStack(alignment: .top) ═══ */}
      <div className="notch-zstack">
        {/* ═══ VStack(spacing: 0) ═══ */}
        <div className="notch-vstack">
          {/* notchLayout() — .padding(.horizontal, cornerRadiusInsets) */}
          <div
            className={`notch-layout ${expanded ? 'notch-open' : 'notch-closed'}`}
            style={{
              paddingLeft: expanded ? CR.opened.top : CR.closed.bottom,
              paddingRight: expanded ? CR.opened.top : CR.closed.bottom,
              paddingBottom: expanded ? 12 : 0,
              borderRadius: expanded
                ? `${CR.opened.top}px ${CR.opened.top}px ${CR.opened.bottom}px ${CR.opened.bottom}px`
                : `${CR.closed.top}px ${CR.closed.top}px ${CR.closed.bottom}px ${CR.closed.bottom}px`,
              boxShadow: showShadow ? '0 0 6px rgba(0,0,0,0.7)' : 'none',
              height: expanded ? OPEN_H : undefined,
              transition: expanded ? ANIM_OPEN : ANIM_CLOSE,
            }}
            onClick={handleToggle}
          >
            {/* ═══ VStack(alignment: .leading, spacing: 0) ═══ */}
            <div className="notch-inner-vstack">

              {/* ── Top bar: zIndex 2 ── */}
              <div className="notch-topbar">
                {expanded ? (
                  /* ═══ openHeader() lines 271-525 ═══ */
                  <div className="open-header" style={{ height: Math.max(24, CLOSED_H), paddingTop: 2 }}>
                    <div className="header-left" style={{ width: 120 }}>
                      {/* Dashboard button */}
                      <button className="header-tab" style={{ color: '#fff' }} onClick={(e) => { e.stopPropagation(); setShowMusicContent(false); }}>
                        <IcGrid size={16} />
                      </button>
                      {/* Module icons: screenshot, ai */}
                      <button className="header-tab" style={{ color: '#999' }} onClick={(e) => e.stopPropagation()}>
                        <IcCamera size={16} />
                      </button>
                      <button className="header-tab" style={{ color: '#999' }} onClick={(e) => e.stopPropagation()}>
                        <IcChat size={16} />
                      </button>
                    </div>

                    {/* Divider left | center */}
                    <div className="header-divider" />

                    {/* Center — quick app icons placeholder */}
                    <div className="header-center" />

                    {/* Divider center | right */}
                    <div className="header-divider" />

                    {/* Right — music toggle + settings */}
                    <div className="header-right" style={{ width: 68 }}>
                      <button
                        className="header-capsule"
                        onClick={(e) => { e.stopPropagation(); setShowMusicContent(v => !v); }}
                        title={showMusicContent ? '隐藏音乐内容' : '显示音乐内容'}
                      >
                        {showMusicContent ? <IcMusicNote size={16} /> : <IcMusicNoteSlash size={16} />}
                      </button>
                      <button className="header-capsule" onClick={(e) => e.stopPropagation()} title="设置">
                        <IcGear size={16} />
                      </button>
                    </div>
                  </div>
                ) : (
                  /* ═══ closedPill() lines 191-239 ═══ */
                  <div className="closed-pill" style={{ height: CLOSED_H }}>
                    {hasMusic && showMusicContent ? (
                      <>
                        {/* Mini album art: 20×20, radius 4 */}
                        {media!.artworkDataUrl ? (
                          <img
                            src={media!.artworkDataUrl}
                            alt=""
                            className="closed-art"
                            style={{ width: ART.closed.w, height: ART.closed.h, borderRadius: ART.closed.r }}
                          />
                        ) : (
                          <div
                            className="closed-art-placeholder"
                            style={{
                              width: ART.closed.w,
                              height: ART.closed.h,
                              borderRadius: ART.closed.r,
                              background: 'rgba(255,255,255,0.15)',
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              flexShrink: 0,
                            }}
                          >
                            <IcMusicNote size={11} />
                          </div>
                        )}

                        {/* Current lyrics — centered, font 11, white 0.8 */}
                        <span
                          className="closed-lyrics"
                          style={{
                            flex: 1,
                            textAlign: 'center',
                            fontSize: 11,
                            color: 'rgba(255,255,255,0.8)',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                          }}
                        >
                          {closedLyricLine}
                        </span>

                        {/* Mini playback controls: prev(8) play/pause(9) next(8), spacing 6 */}
                        <div className="closed-controls" style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                          <button
                            className="closed-ctrl-btn"
                            onClick={(e) => { e.stopPropagation(); mediaControl('previous'); }}
                            style={{ color: '#fff', fontSize: 8, lineHeight: 1 }}
                          >
                            <IcBackward size={8} />
                          </button>
                          <button
                            className="closed-ctrl-btn"
                            onClick={(e) => { e.stopPropagation(); mediaControl('playpause'); }}
                            style={{ color: '#fff', fontSize: 9, lineHeight: 1 }}
                          >
                            {isPlaying ? <IcPause size={9} /> : <IcPlay size={9} />}
                          </button>
                          <button
                            className="closed-ctrl-btn"
                            onClick={(e) => { e.stopPropagation(); mediaControl('next'); }}
                            style={{ color: '#fff', fontSize: 8, lineHeight: 1 }}
                          >
                            <IcForward size={8} />
                          </button>
                        </div>
                      </>
                    ) : (
                      /* No music: show displayTitle */
                      <span
                        className="closed-title"
                        style={{
                          fontSize: 12,
                          fontWeight: 500,
                          color: '#fff',
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                        }}
                      >
                        AcMind
                      </span>
                    )}
                  </div>
                )}
              </div>

              {/* ── Open content: zIndex 1 ── */}
              {expanded && (
                <div
                  className="notch-open-content"
                  style={{
                    opacity: 1,
                    transform: 'scale(1)',
                    transformOrigin: 'top center',
                    transition: ANIM_CONTENT,
                  }}
                >
                  {showMusicContent ? (
                    /* ═══ musicPlayerSection() lines 752-998 ═══ */
                    <div className="music-player-section" style={{ padding: '8px 12px 10px' }}>
                      <div className="music-player-hstack" style={{ display: 'flex', alignItems: 'flex-start' }}>
                        {/* albumArtView() — lines 772-830 */}
                        <div className="album-art-wrapper" style={{ padding: 5, flexShrink: 0 }}>
                          <div className="album-art-zstack" style={{ position: 'relative', width: ART.opened.w, height: ART.opened.h }}>
                            {/* Lighting effect — blurred rotated album art */}
                            {hasMusic && media!.artworkDataUrl && (
                              <div
                                className="album-art-glow"
                                style={{
                                  position: 'absolute',
                                  inset: 0,
                                  borderRadius: ART.opened.r,
                                  overflow: 'hidden',
                                  opacity: isPlaying ? 0.5 : 0,
                                  transition: 'opacity 0.3s ease',
                                  filter: 'blur(40px)',
                                  transform: 'scale(1.3, 1.4) rotate(92deg)',
                                  pointerEvents: 'none',
                                }}
                              >
                                <img src={media!.artworkDataUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                              </div>
                            )}

                            {/* Album art button */}
                            <div
                              className="album-art-btn"
                              style={{
                                position: 'relative',
                                width: ART.opened.w,
                                height: ART.opened.h,
                                borderRadius: ART.opened.r,
                                overflow: 'hidden',
                                transform: isPlaying ? 'scale(1)' : 'scale(0.85)',
                                transition: 'transform 0.3s ease',
                                cursor: 'pointer',
                              }}
                            >
                              {hasMusic && media!.artworkDataUrl ? (
                                <img
                                  src={media!.artworkDataUrl}
                                  alt=""
                                  style={{ width: '100%', height: '100%', objectFit: 'cover', display: 'block' }}
                                />
                              ) : (
                                <div
                                  style={{
                                    width: '100%',
                                    height: '100%',
                                    background: 'rgba(255,255,255,0.1)',
                                    display: 'flex',
                                    alignItems: 'center',
                                    justifyContent: 'center',
                                  }}
                                >
                                  <IcMusicNote size={24} />
                                </div>
                              )}
                            </div>

                            {/* Dark overlay when paused */}
                            <div
                              className="album-art-overlay"
                              style={{
                                position: 'absolute',
                                inset: 0,
                                borderRadius: ART.opened.r,
                                background: '#000',
                                opacity: isPlaying ? 0 : 0.8,
                                transition: 'opacity 0.3s ease',
                                filter: 'blur(50px)',
                                pointerEvents: 'none',
                              }}
                            />
                          </div>
                        </div>

                        {/* songInfoAndSlider() + playbackControls() */}
                        <div className="music-info-controls" style={{ flex: 1, minWidth: 0, paddingTop: 10, paddingLeft: 5 }}>
                          {/* songInfo — lines 855-870 */}
                          <div className="song-info" style={{ display: 'flex', flexDirection: 'column', gap: 0 }}>
                            <span
                              className="song-title"
                              style={{
                                fontSize: 17,
                                fontWeight: 700,
                                color: '#fff',
                                lineHeight: 1.3,
                                whiteSpace: 'nowrap',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                              }}
                            >
                              {hasMusic ? media!.trackName : '未知歌曲'}
                            </span>
                            <span
                              className="song-artist"
                              style={{
                                fontSize: 12,
                                fontWeight: 500,
                                color: '#999',
                                lineHeight: 1.3,
                                whiteSpace: 'nowrap',
                                overflow: 'hidden',
                                textOverflow: 'ellipsis',
                              }}
                            >
                              {hasMusic ? media!.artist : '未知歌手'}
                            </span>
                          </div>

                          {/* lyricsView — lines 875-903 */}
                          <div
                            className="lyrics-line"
                            style={{
                              height: 16,
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              fontSize: 15,
                              color: 'rgba(255,255,255,0.7)',
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis',
                              opacity: isPlaying ? 1 : 0,
                              transition: 'opacity 0.3s ease',
                            }}
                          >
                            {hasMusic ? media!.trackName : ''}
                          </div>

                          {/* musicSlider — lines 908-965 */}
                          <div className="music-slider" style={{ width: '100%' }}>
                            <div
                              ref={sliderTrackRef}
                              className="slider-track"
                              style={{
                                width: '100%',
                                height: isDragging ? 9 : 5,
                                background: 'rgba(255,255,255,0.3)',
                                borderRadius: (isDragging ? 9 : 5) / 2,
                                cursor: 'pointer',
                                position: 'relative',
                                transition: `height ${ANIM_SLIDER}`,
                              }}
                              onMouseDown={handleSliderDown}
                            >
                              <div
                                className="slider-fill"
                                style={{
                                  position: 'absolute',
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: `${progress * 100}%`,
                                  background: '#fff',
                                  borderRadius: (isDragging ? 9 : 5) / 2,
                                }}
                              />
                            </div>
                            <div
                              className="slider-times"
                              style={{
                                display: 'flex',
                                justifyContent: 'space-between',
                                fontSize: 12,
                                fontWeight: 500,
                                color: '#999',
                                marginTop: 1,
                                fontVariantNumeric: 'tabular-nums',
                              }}
                            >
                              <span>{formatTime(displayPos)}</span>
                              <span>{formatTime(duration)}</span>
                            </div>
                          </div>

                          {/* playbackControls — lines 970-998 */}
                          <div
                            className="playback-controls"
                            style={{
                              display: 'flex',
                              alignItems: 'center',
                              justifyContent: 'center',
                              gap: 6,
                            }}
                          >
                            {/* Shuffle — 30px */}
                            <HoverButton size={30} onClick={(e) => { e.stopPropagation(); }}>
                              <IcShuffle size={16} />
                            </HoverButton>
                            {/* Previous — 30px */}
                            <HoverButton size={30} onClick={(e) => { e.stopPropagation(); mediaControl('previous'); }}>
                              <IcBackward size={15} />
                            </HoverButton>
                            {/* Play/Pause — 40px */}
                            <HoverButton size={40} onClick={(e) => { e.stopPropagation(); mediaControl('playpause'); }}>
                              {isPlaying ? <IcPause size={20} /> : <IcPlay size={20} />}
                            </HoverButton>
                            {/* Next — 30px */}
                            <HoverButton size={30} onClick={(e) => { e.stopPropagation(); mediaControl('next'); }}>
                              <IcForward size={15} />
                            </HoverButton>
                            {/* Repeat — 30px */}
                            <HoverButton size={30} onClick={(e) => { e.stopPropagation(); }}>
                              <IcRepeat size={16} />
                            </HoverButton>
                          </div>
                        </div>
                      </div>
                    </div>
                  ) : (
                    /* ═══ dashboardContent() lines 549-727 ═══ */
                    <div className="dashboard-content" style={{ padding: '8px 12px 10px' }}>
                      <div className="dashboard-hstack" style={{ display: 'flex', alignItems: 'flex-start', gap: 10, height: 180 }}>
                        {/* miniMusicWidget — lines 567-631 */}
                        <div className="mini-music-widget" style={{ flex: 1, background: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 10, display: 'flex', flexDirection: 'column', maxWidth: '100%' }}>
                          {/* Album art */}
                          {hasMusic && media!.artworkDataUrl ? (
                            <img
                              src={media!.artworkDataUrl}
                              alt=""
                              style={{ width: '100%', aspectRatio: '1', objectFit: 'cover', borderRadius: 10 }}
                            />
                          ) : (
                            <div
                              style={{
                                width: '100%',
                                aspectRatio: '1',
                                background: 'rgba(255,255,255,0.08)',
                                borderRadius: 10,
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                              }}
                            >
                              <IcMusicNote size={22} />
                            </div>
                          )}
                          <div style={{ flex: '0 0 8px' }} />
                          {/* Song info */}
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                            <span style={{ fontSize: 11, fontWeight: 600, color: '#fff', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                              {hasMusic ? media!.trackName : '未知歌曲'}
                            </span>
                            <span style={{ fontSize: 9, color: '#999', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                              {hasMusic ? media!.artist : '未知歌手'}
                            </span>
                          </div>
                          <div style={{ flex: '0 0 6px' }} />
                          {/* Playback controls */}
                          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 14, width: '100%' }}>
                            <button className="mini-ctrl" onClick={(e) => { e.stopPropagation(); mediaControl('previous'); }} style={{ color: '#999', background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
                              <IcBackward size={10} />
                            </button>
                            <button className="mini-ctrl" onClick={(e) => { e.stopPropagation(); mediaControl('playpause'); }} style={{ color: '#fff', background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
                              {isPlaying ? <IcPause size={13} /> : <IcPlay size={13} />}
                            </button>
                            <button className="mini-ctrl" onClick={(e) => { e.stopPropagation(); mediaControl('next'); }} style={{ color: '#999', background: 'none', border: 'none', cursor: 'pointer', padding: 4 }}>
                              <IcForward size={10} />
                            </button>
                          </div>
                        </div>

                        {/* calendarWidget — lines 636-689 */}
                        <div className="calendar-widget" style={{ flex: 1, background: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 10, display: 'flex', flexDirection: 'column' }}>
                          {/* Month header */}
                          <span style={{ fontSize: 14, fontWeight: 700, color: '#fff' }}>
                            {now.getMonth() + 1}月
                          </span>
                          {/* Weekday headers */}
                          <div style={{ display: 'flex', gap: 0 }}>
                            {WEEKDAYS.map(d => (
                              <span key={d} style={{ flex: 1, textAlign: 'center', fontSize: 8, fontWeight: 500, color: 'rgba(255,255,255,0.5)' }}>
                                {d}
                              </span>
                            ))}
                          </div>
                          {/* Date strip */}
                          <div style={{ display: 'flex', gap: 0 }}>
                            {weekDates.map((date, i) => {
                              const isToday = date.getDate() === todayDay && date.getMonth() === todayMonth;
                              return (
                                <div
                                  key={i}
                                  style={{
                                    flex: 1,
                                    display: 'flex',
                                    flexDirection: 'column',
                                    alignItems: 'center',
                                    gap: 1,
                                    padding: '3px 0',
                                    borderRadius: 6,
                                    background: isToday ? 'rgba(255,255,255,0.1)' : 'transparent',
                                  }}
                                >
                                  <span style={{
                                    fontSize: 12,
                                    fontWeight: isToday ? 700 : 400,
                                    color: isToday ? '#fff' : '#999',
                                  }}>
                                    {date.getDate()}
                                  </span>
                                  <div style={{
                                    width: 4,
                                    height: 4,
                                    borderRadius: 1.5,
                                    background: isToday ? 'rgb(255, 89, 89)' : 'transparent',
                                  }} />
                                </div>
                              );
                            })}
                          </div>
                          <div style={{ flex: 1 }} />
                          {/* Today's events */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <IcCalendar size={9} />
                            <span style={{ fontSize: 9, color: 'rgba(255,255,255,0.4)' }}>
                              今天没有任何事项
                            </span>
                            <span style={{ flex: 1 }} />
                          </div>
                        </div>

                        {/* quickNotesWidget — lines 694-727 */}
                        <div className="quick-notes-widget" style={{ flex: 1, background: 'rgba(255,255,255,0.06)', borderRadius: 14, padding: 10, display: 'flex', flexDirection: 'column' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                            <IcPencil size={10} />
                            <span style={{ fontSize: 10, fontWeight: 500, color: 'rgba(255,255,255,0.5)' }}>便签</span>
                            <span style={{ flex: 1 }} />
                          </div>
                          <textarea
                            className="quick-note-input"
                            value={quickNoteText}
                            onChange={(e) => { e.stopPropagation(); setQuickNoteText(e.target.value); }}
                            onClick={(e) => e.stopPropagation()}
                            onMouseDown={(e) => e.stopPropagation()}
                            style={{
                              flex: 1,
                              background: 'transparent',
                              border: 'none',
                              outline: 'none',
                              resize: 'none',
                              color: 'rgba(255,255,255,0.8)',
                              fontSize: 11,
                              lineHeight: 1.4,
                              fontFamily: 'inherit',
                              width: '100%',
                              minHeight: 0,
                            }}
                            placeholder=""
                          />
                          <div style={{ flex: 1 }} />
                          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
                            <span style={{ fontSize: 8, color: 'rgba(255,255,255,0.3)' }}>
                              {quickNoteText.length} 字
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* ═══ Inline Styles ═══ */}
      <style>{`
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', sans-serif;
          overflow: hidden;
          user-select: none;
          -webkit-user-select: none;
          background: transparent;
        }

        /* ═══ Root: windowSize 640×280 ═══ */
        .notch-root {
          width: ${WINDOW_W}px;
          height: ${WINDOW_H}px;
          max-width: ${WINDOW_W}px;
          max-height: ${WINDOW_H}px;
          display: flex;
          flex-direction: column;
          align-items: center;
          justify-content: flex-start;
          background: transparent;
          cursor: pointer;
        }

        /* ═══ ZStack(alignment: .top) ═══ */
        .notch-zstack {
          position: relative;
          display: flex;
          flex-direction: column;
          align-items: center;
          width: 100%;
        }

        /* ═══ VStack(spacing: 0) — padding(.bottom, 8) ═══ */
        .notch-vstack {
          display: flex;
          flex-direction: column;
          align-items: center;
          width: 100%;
          padding-bottom: 8px;
        }

        /* ═══ notchLayout — background .black, clipShape ═══ */
        .notch-layout {
          display: flex;
          flex-direction: column;
          background: #000;
          width: 100%;
          overflow: hidden;
        }

        /* ═══ Inner VStack ═══ */
        .notch-inner-vstack {
          display: flex;
          flex-direction: column;
          width: 100%;
        }

        /* ═══ Top bar — zIndex 2 ═══ */
        .notch-topbar {
          position: relative;
          z-index: 2;
        }

        /* ═══ Open content — zIndex 1, transition .scale(0.8, anchor: .top).combined(with: .opacity) ═══ */
        .notch-open-content {
          position: relative;
          z-index: 1;
        }

        /* ═══ Closed pill — lines 191-239 ═══ */
        .closed-pill {
          display: flex;
          align-items: center;
          padding: 0 8px;
          gap: 10px;
        }
        .closed-ctrl-btn {
          background: none;
          border: none;
          cursor: pointer;
          padding: 2px;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
        }
        .closed-ctrl-btn:hover {
          background: rgba(255,255,255,0.1);
          border-radius: 4px;
        }

        /* ═══ Open header — lines 271-525 ═══ */
        .open-header {
          display: flex;
          align-items: center;
          color: #999;
        }
        .header-left {
          display: flex;
          align-items: center;
          flex-shrink: 0;
        }
        .header-tab {
          background: none;
          border: none;
          cursor: pointer;
          padding: 0 15px;
          height: 26px;
          display: flex;
          align-items: center;
          justify-content: center;
          border-radius: 13px;
          transition: background ${ANIM_BTN};
        }
        .header-tab:hover {
          background: rgba(255,255,255,0.1);
        }
        .header-divider {
          width: 1px;
          height: 16px;
          background: rgba(255,255,255,0.2);
          flex-shrink: 0;
          margin: 0 6px;
        }
        .header-center {
          flex: 1;
          display: flex;
          align-items: center;
          justify-content: center;
          overflow: hidden;
        }
        .header-right {
          display: flex;
          align-items: center;
          justify-content: flex-end;
          gap: 4px;
          flex-shrink: 0;
        }
        .header-capsule {
          width: 30px;
          height: 30px;
          border-radius: 15px;
          background: #000;
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
          transition: background ${ANIM_BTN};
        }
        .header-capsule:hover {
          background: rgba(255,255,255,0.1);
        }

        /* ═══ HoverButton — lines 1003-1029 ═══ */
        .hover-btn {
          background: none;
          border: none;
          cursor: pointer;
          display: flex;
          align-items: center;
          justify-content: center;
          color: #fff;
          border-radius: 50%;
          position: relative;
          padding: 0;
        }
        .hover-btn-bg {
          position: absolute;
          inset: 0;
          border-radius: 50%;
          background: transparent;
          transition: background ${ANIM_BTN};
        }
        .hover-btn:hover .hover-btn-bg {
          background: rgba(255,255,255,0.2);
        }
        .hover-btn-icon {
          position: relative;
          z-index: 1;
          display: flex;
          align-items: center;
          justify-content: center;
        }

        /* ═══ Mini music widget controls ═══ */
        .mini-ctrl {
          transition: opacity ${ANIM_BTN};
        }
        .mini-ctrl:hover {
          opacity: 0.7;
        }

        /* ═══ Quick note textarea ═══ */
        .quick-note-input::placeholder {
          color: rgba(255,255,255,0.3);
        }
        .quick-note-input::-webkit-scrollbar {
          display: none;
        }
      `}</style>
    </div>
  );
}

// ═══════════════════════════════════════════════════════════════════════
// HoverButton — hoverButton() lines 1003-1029
// ═══════════════════════════════════════════════════════════════════════

function HoverButton({
  size,
  onClick,
  children,
}: {
  size: number;
  onClick: (e: React.MouseEvent<HTMLButtonElement>) => void;
  children: React.ReactNode;
}) {
  return (
    <button
      className="hover-btn"
      style={{ width: size, height: size }}
      onClick={onClick}
      onMouseDown={(e) => e.stopPropagation()}
    >
      <div className="hover-btn-bg" />
      <span className="hover-btn-icon" style={{ fontSize: size >= 40 ? 22 : 16 }}>
        {children}
      </span>
    </button>
  );
}
