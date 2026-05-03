import { createContext, useContext } from 'react';
import type { CaptureItem } from '../../shared/types';

export interface SelectedItemContextValue {
  selectedItem: CaptureItem | null;
  setSelectedItem: (item: CaptureItem | null) => void;
}

export const SelectedItemContext = createContext<SelectedItemContextValue>({
  selectedItem: null,
  setSelectedItem: () => {},
});

export function useSelectedItem(): SelectedItemContextValue {
  return useContext(SelectedItemContext);
}
