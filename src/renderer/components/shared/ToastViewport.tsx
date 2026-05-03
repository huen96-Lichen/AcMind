import { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';

// ─── Types ───────────────────────────────────────────────────────────────────

interface Toast {
  id: string;
  message: string;
  type: 'info' | 'success' | 'warning' | 'error';
}

interface ToastContextValue {
  addToast: (message: string, type?: Toast['type']) => void;
}

const ToastContext = createContext<ToastContextValue | null>(null);

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext);
  if (!ctx) {
    throw new Error('useToast must be used within <ToastProvider>');
  }
  return ctx;
}

// ─── Constants ───────────────────────────────────────────────────────────────

const TOAST_DURATION_MS = 3000;

const TYPE_STYLES: Record<Toast['type'], string> = {
  info: 'border-[color:var(--pm-brand-primary)] bg-[color:var(--pm-brand-soft)]',
  success: 'border-[color:var(--pm-status-success)] bg-[rgba(47,143,99,0.1)]',
  warning: 'border-[color:var(--pm-status-warning)] bg-[rgba(201,133,18,0.1)]',
  error: 'border-[color:var(--pm-status-danger)] bg-[rgba(201,75,75,0.1)]',
};

const TYPE_ICONS: Record<Toast['type'], string> = {
  info: 'i',
  success: '\u2713',
  warning: '!',
  error: '\u2717',
};

// ─── ToastProvider ───────────────────────────────────────────────────────────

/**
 * Provides toast context to children and renders the toast notification list.
 * Fixed position bottom-right, auto-dismiss after 3 seconds.
 */
export function ToastProvider({ children }: { children: React.ReactNode }): JSX.Element {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const timersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map());

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
    const timer = timersRef.current.get(id);
    if (timer) {
      clearTimeout(timer);
      timersRef.current.delete(id);
    }
  }, []);

  const addToast = useCallback(
    (message: string, type: Toast['type'] = 'info') => {
      const id = `toast-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`;
      const toast: Toast = { id, message, type };
      setToasts((prev) => [...prev, toast]);

      const timer = setTimeout(() => {
        removeToast(id);
      }, TOAST_DURATION_MS);
      timersRef.current.set(id, timer);
    },
    [removeToast],
  );

  useEffect(() => {
    const timers = timersRef.current;
    return () => {
      timers.forEach((t) => clearTimeout(t));
      timers.clear();
    };
  }, []);

  return (
    <ToastContext.Provider value={{ addToast }}>
      {children}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2 pointer-events-none">
        {toasts.map((toast) => (
          <div
            key={toast.id}
            className={`pointer-events-auto motion-toast-enter acmind-subpanel-section px-4 py-3 border-l-4 ${TYPE_STYLES[toast.type]} flex items-center gap-3 min-w-[280px] max-w-[400px]`}
          >
            <span className="text-sm font-bold opacity-70 w-4 text-center flex-shrink-0">
              {TYPE_ICONS[toast.type]}
            </span>
            <span className="text-[13px] leading-snug" style={{ color: 'var(--pm-text-primary)' }}>
              {toast.message}
            </span>
            <button
              type="button"
              onClick={() => removeToast(toast.id)}
              className="ml-auto flex-shrink-0 text-[11px] opacity-40 hover:opacity-70 transition-opacity"
              style={{ color: 'var(--pm-text-secondary)' }}
            >
              &times;
            </button>
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  );
}
