import { Component, type ErrorInfo, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error('[ErrorBoundary] Caught error:', error, info.componentStack);
  }

  handleRetry = (): void => {
    this.setState({ hasError: false, error: null });
  };

  render(): ReactNode {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback;
      }

      return (
        <div className="flex flex-col items-center justify-center h-full min-h-[400px] p-8 text-center">
          <div className="w-16 h-16 mb-4 rounded-full bg-pinmind-dangerBg flex items-center justify-center">
            <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="text-pinmind-danger">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
          </div>
          <h2 className="text-xl font-semibold text-pinmind-primaryText mb-2">页面出现错误</h2>
          <p className="text-sm text-pinmind-secondaryText mb-6 max-w-md">
            {this.state.error?.message ?? '发生了未知错误，请尝试刷新页面。'}
          </p>
          <button
            onClick={this.handleRetry}
            className="px-4 py-2 rounded-lg bg-pinmind-brand text-white text-sm font-medium hover:bg-pinmind-brandHover transition-colors"
          >
            重试
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
