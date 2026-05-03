import type { InboxFilter } from '../../hooks/useSourceItems';

// ─── Types ───────────────────────────────────────────────────────────────────

interface SourceItemFilterProps {
  activeFilter: InboxFilter;
  onFilterChange: (filter: InboxFilter) => void;
  searchQuery: string;
  onSearchChange: (query: string) => void;
}

const FILTER_OPTIONS: { key: InboxFilter; label: string }[] = [
  { key: 'all', label: '\u5168\u90E8' },
  { key: 'text', label: '\u6587\u672C' },
  { key: 'image', label: '\u56FE\u7247' },
  { key: 'screenshot', label: '\u622A\u56FE' },
];

// ─── SourceItemFilter ────────────────────────────────────────────────────────

/**
 * Filter bar for the Inbox page.
 * Contains type filter buttons and a search input with debounce.
 */
export function SourceItemFilter({
  activeFilter,
  onFilterChange,
  searchQuery,
  onSearchChange,
}: SourceItemFilterProps): JSX.Element {
  return (
    <div className="pinmind-filter-bar">
      {/* Filter buttons */}
      <div className="flex items-center gap-1">
        {FILTER_OPTIONS.map((option) => {
          const isActive = activeFilter === option.key;
          return (
            <button
              key={option.key}
              type="button"
              onClick={() => onFilterChange(option.key)}
              className={`pinmind-filter-btn motion-button ${isActive ? 'is-active' : ''}`}
            >
              {option.label}
            </button>
          );
        })}
      </div>

      {/* Search input */}
      <div className="pinmind-search-wrapper">
        <svg
          className="pinmind-search-icon"
          width="14"
          height="14"
          viewBox="0 0 14 14"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
        >
          <path
            d="M6.25 10.5C8.59721 10.5 10.5 8.59721 10.5 6.25C10.5 3.90279 8.59721 2 6.25 2C3.90279 2 2 3.90279 2 6.25C2 8.59721 3.90279 10.5 6.25 10.5Z"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
          <path
            d="M9.375 9.375L12 12"
            stroke="currentColor"
            strokeWidth="1.5"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
        <input
          type="text"
          className="pinmind-search-input"
          placeholder="搜索内容..."
          value={searchQuery}
          onChange={(e) => onSearchChange(e.target.value)}
        />
      </div>
    </div>
  );
}
