import { exec } from 'node:child_process';
import { promisify } from 'node:util';
import type { CalendarEvent } from '../../../shared/types';

const execAsync = promisify(exec);

const CALENDAR_SCRIPT = `
tell application "Calendar"
  set todayStart to current date
  set hours of todayStart to 0
  set minutes of todayStart to 0
  set seconds of todayStart to 0
  set todayEnd to todayStart + (1 * days)
  set eventList to {}
  repeat with cal in calendars
    try
      set calEvents to (every event of cal whose start date >= todayStart and start date < todayEnd)
      repeat with evt in calEvents
        set evtSummary to summary of evt
        set evtStart to start date of evt as string
        set evtEnd to end date of evt as string
        set evtLocation to ""
        try
          set evtLocation to location of evt
        end try
        set calName to name of cal
        set end of eventList to evtSummary & "|||" & evtStart & "|||" & evtEnd & "|||" & evtLocation & "|||" & calName
      end repeat
    end try
  end repeat
  set AppleScript's text item delimiters to "~~~"
  return eventList as text
end tell`;

export async function getTodayCalendarEvents(): Promise<CalendarEvent[]> {
  if (process.platform !== 'darwin') return [];

  try {
    const { stdout } = await execAsync(`osascript -e '${CALENDAR_SCRIPT.replace(/'/g, "'\\''")}'`, { timeout: 5000 });
    const trimmed = stdout.trim();
    if (!trimmed) return [];

    const events = trimmed.split('~~~').filter(Boolean);
    return events.map((event) => {
      const [title, startDate, endDate, location, calendarName] = event.split('|||');
      return {
        title: (title || '').trim(),
        startDate: (startDate || '').trim(),
        endDate: (endDate || '').trim(),
        location: location ? location.trim() : undefined,
        calendarName: (calendarName || '').trim(),
      };
    });
  } catch {
    return [];
  }
}
