// PinMind TierRouter Unit Tests
// Tests for the tier routing logic with mocked storage

import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { ProviderConfig } from '../../../shared/types';

// ---------------------------------------------------------------------------
// Mock the storage module before importing TierRouter
// ---------------------------------------------------------------------------

const mockProviders: ProviderConfig[] = [];

vi.mock('../../storage', () => ({
  storage: {
    getProviderConfigs: vi.fn(() => [...mockProviders]),
  },
}));

// Mock the logger to avoid file I/O
vi.mock('../../logger', () => ({
  logger: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    debug: vi.fn(),
  },
}));

// Import after mocks are set up
import { tierRouter } from './tierRouter';
import { storage } from '../../storage';

describe('TierRouter', () => {
  beforeEach(() => {
    // Clear mock providers
    mockProviders.length = 0;
    // Reset the mock implementation in case it was overridden
    vi.mocked(storage.getProviderConfigs).mockImplementation(() => [...mockProviders]);
  });

  // -- route() --------------------------------------------------------------

  describe('route()', () => {
    it('should return useMock=true when no providers are configured', () => {
      const result = tierRouter.route('summarize');

      expect(result.useMock).toBe(true);
      expect(result.provider).toBeNull();
      expect(result.tier).toBe('local_light');
      expect(result.reason).toContain('No available provider');
    });

    it('should route to a local_light provider when available', () => {
      mockProviders.push({
        id: 'p1',
        name: 'Ollama Local',
        type: 'ollama',
        tier: 'local_light',
        baseUrl: 'http://localhost:11434',
        modelId: 'llama3',
        enabled: true,
        capabilities: ['summarize'],
      });

      const result = tierRouter.route('summarize');

      expect(result.useMock).toBe(false);
      expect(result.provider).not.toBeNull();
      expect(result.provider!.name).toBe('Ollama Local');
      expect(result.tier).toBe('local_light');
    });

    it('should fall back to cloud_standard when local_light is unavailable', () => {
      mockProviders.push({
        id: 'p2',
        name: 'OpenAI',
        type: 'openai_compatible',
        tier: 'cloud_standard',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        modelId: 'gpt-4',
        enabled: true,
        capabilities: ['summarize'],
      });

      const result = tierRouter.route('rename');

      expect(result.useMock).toBe(false);
      expect(result.provider).not.toBeNull();
      expect(result.tier).toBe('cloud_standard');
    });

    it('should fall back to cloud_advanced when lower tiers are unavailable', () => {
      mockProviders.push({
        id: 'p3',
        name: 'Claude',
        type: 'openai_compatible',
        tier: 'cloud_advanced',
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'sk-test',
        modelId: 'claude-3',
        enabled: true,
        capabilities: ['classify'],
      });

      const result = tierRouter.route('classify');

      expect(result.useMock).toBe(false);
      expect(result.provider).not.toBeNull();
      expect(result.tier).toBe('cloud_advanced');
    });

    it('should skip disabled providers', () => {
      mockProviders.push({
        id: 'p4',
        name: 'Disabled Provider',
        type: 'ollama',
        tier: 'local_light',
        baseUrl: 'http://localhost:11434',
        modelId: 'llama3',
        enabled: false,
        capabilities: ['summarize'],
      });

      const result = tierRouter.route('tag');

      expect(result.useMock).toBe(true);
      expect(result.provider).toBeNull();
    });

    it('should prefer local_light over cloud tiers', () => {
      mockProviders.push(
        {
          id: 'cloud',
          name: 'Cloud Provider',
          type: 'openai_compatible',
          tier: 'cloud_standard',
          baseUrl: 'https://api.openai.com',
          apiKey: 'sk-test',
          modelId: 'gpt-4',
          enabled: true,
          capabilities: ['summarize'],
        },
        {
          id: 'local',
          name: 'Local Provider',
          type: 'ollama',
          tier: 'local_light',
          baseUrl: 'http://localhost:11434',
          modelId: 'llama3',
          enabled: true,
          capabilities: ['summarize'],
        },
      );

      const result = tierRouter.route('valueScore');

      expect(result.useMock).toBe(false);
      expect(result.tier).toBe('local_light');
      expect(result.provider!.name).toBe('Local Provider');
    });
  });

  // -- routeToTier() --------------------------------------------------------

  describe('routeToTier()', () => {
    it('should route to the preferred tier when provider is available', () => {
      mockProviders.push({
        id: 'p1',
        name: 'Ollama',
        type: 'ollama',
        tier: 'local_light',
        baseUrl: 'http://localhost:11434',
        modelId: 'llama3',
        enabled: true,
        capabilities: ['summarize'],
      });

      const result = tierRouter.routeToTier('summarize', 'local_light');

      expect(result.useMock).toBe(false);
      expect(result.tier).toBe('local_light');
      expect(result.reason).toContain('requested tier');
    });

    it('should fall back to higher tier when preferred tier has no provider', () => {
      mockProviders.push({
        id: 'p2',
        name: 'Cloud Provider',
        type: 'openai_compatible',
        tier: 'cloud_standard',
        baseUrl: 'https://api.openai.com',
        apiKey: 'sk-test',
        modelId: 'gpt-4',
        enabled: true,
        capabilities: ['summarize'],
      });

      const result = tierRouter.routeToTier('summarize', 'local_light');

      expect(result.useMock).toBe(false);
      expect(result.tier).toBe('cloud_standard');
      expect(result.reason).toContain('escalated');
    });

    it('should return useMock=true when no provider in fallback chain', () => {
      const result = tierRouter.routeToTier('summarize', 'cloud_advanced');

      expect(result.useMock).toBe(true);
      expect(result.provider).toBeNull();
      expect(result.tier).toBe('cloud_advanced');
    });

    it('should only try fallback chain from preferred tier (not lower)', () => {
      // Only configure a local_light provider
      mockProviders.push({
        id: 'p-local',
        name: 'Local',
        type: 'ollama',
        tier: 'local_light',
        baseUrl: 'http://localhost:11434',
        modelId: 'llama3',
        enabled: true,
        capabilities: ['summarize'],
      });

      // Request cloud_advanced - should NOT fall back to local_light
      const result = tierRouter.routeToTier('summarize', 'cloud_advanced');

      expect(result.useMock).toBe(true);
      expect(result.provider).toBeNull();
    });
  });

  // -- findProviderForTier (tested indirectly through route) ----------------

  describe('findProviderForTier (via route)', () => {
    it('should find the first enabled provider matching the tier', () => {
      mockProviders.push(
        {
          id: 'p-first',
          name: 'First Provider',
          type: 'ollama',
          tier: 'cloud_standard',
          baseUrl: 'http://localhost:11434',
          modelId: 'model-a',
          enabled: true,
          capabilities: ['summarize'],
        },
        {
          id: 'p-second',
          name: 'Second Provider',
          type: 'openai_compatible',
          tier: 'cloud_standard',
          baseUrl: 'https://api.openai.com',
          apiKey: 'sk-test',
          modelId: 'model-b',
          enabled: true,
          capabilities: ['summarize'],
        },
      );

      const result = tierRouter.route('rename');

      expect(result.useMock).toBe(false);
      expect(result.provider!.name).toBe('First Provider');
    });

    it('should not match providers with wrong tier', () => {
      mockProviders.push({
        id: 'p-wrong-tier',
        name: 'Wrong Tier Provider',
        type: 'ollama',
        tier: 'cloud_advanced',
        baseUrl: 'http://localhost:11434',
        modelId: 'llama3',
        enabled: true,
        capabilities: ['summarize'],
      });

      // route() starts with local_light fallback chain
      // cloud_advanced is in the chain, so it should match
      const result = tierRouter.route('rename');
      expect(result.useMock).toBe(false);
      expect(result.tier).toBe('cloud_advanced');
    });

    it('should handle storage errors gracefully', () => {
      vi.mocked(storage.getProviderConfigs).mockImplementationOnce(() => {
        throw new Error('Database error');
      });

      const result = tierRouter.route('summarize');

      expect(result.useMock).toBe(true);
      expect(result.provider).toBeNull();
    });
  });
});
