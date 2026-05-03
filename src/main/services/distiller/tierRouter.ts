// PinMind Tier Router
// Routes distillation operations to appropriate AI provider tiers
// Falls back to mockDistiller when no real provider is available

import type { AiOperation, AiTier, ProviderConfig } from '../../../shared/types';
import { storage } from '../../storage';
import { settings } from '../../settings';
import { logger } from '../../logger';

// ---------------------------------------------------------------------------
// Default tier mapping for each operation
// ---------------------------------------------------------------------------

const OPERATION_TIER_MAP: Record<AiOperation, AiTier> = {
  rename: 'local_light',
  summarize: 'local_light',
  classify: 'local_light',
  tag: 'local_light',
  valueScore: 'local_light',
  cleanSuggest: 'local_light',
};

// ---------------------------------------------------------------------------
// Tier fallback chain
// ---------------------------------------------------------------------------

const TIER_FALLBACK: Record<AiTier, AiTier[]> = {
  local_light: ['local_light', 'cloud_standard', 'cloud_advanced'],
  cloud_standard: ['cloud_standard', 'cloud_advanced'],
  cloud_advanced: ['cloud_advanced'],
};

function listProvidersFromAllSources(): ProviderConfig[] {
  const merged = new Map<string, ProviderConfig>();
  for (const provider of settings.load().providers ?? []) {
    merged.set(provider.id, provider);
  }
  for (const provider of storage.getProviderConfigs()) {
    merged.set(provider.id, provider);
  }
  return Array.from(merged.values());
}

// ---------------------------------------------------------------------------
// RouteResult
// ---------------------------------------------------------------------------

export interface RouteResult {
  provider: ProviderConfig | null;
  useMock: boolean;
  tier: AiTier;
  reason: string;
}

// ---------------------------------------------------------------------------
// TierRouter
// ---------------------------------------------------------------------------

class TierRouter {
  /**
   * Route an operation to the best available provider.
   * Returns a RouteResult indicating which provider to use, or whether to fall back to mock.
   */
  route(operation: AiOperation): RouteResult {
    const targetTier = OPERATION_TIER_MAP[operation];
    const fallbackChain = TIER_FALLBACK[targetTier];

    for (const tier of fallbackChain) {
      const provider = this.findProviderForTier(tier);
      if (provider) {
        logger.info('ai', 'tierRouter', 'route', `Routed ${operation} to provider`, {
          operation,
          tier,
          provider: provider.name,
          model: provider.modelId,
        });
        return {
          provider,
          useMock: false,
          tier,
          reason: `Found available provider "${provider.name}" at tier "${tier}"`,
        };
      }
    }

    // No provider available - fall back to mock
    logger.warn('ai', 'tierRouter', 'route', `No provider available, falling back to mock`, {
      operation,
      targetTier,
    });

    return {
      provider: null,
      useMock: true,
      tier: targetTier,
      reason: `No available provider for operation "${operation}" (tried tiers: ${fallbackChain.join(', ')}). Falling back to mock distiller.`,
    };
  }

  /**
   * Route an operation to a specific tier, with fallback to higher tiers.
   */
  routeToTier(operation: AiOperation, preferredTier: AiTier): RouteResult {
    const fallbackChain = TIER_FALLBACK[preferredTier];

    for (const tier of fallbackChain) {
      const provider = this.findProviderForTier(tier);
      if (provider) {
        logger.info('ai', 'tierRouter', 'routeToTier', `Routed ${operation} to provider`, {
          operation,
          requestedTier: preferredTier,
          actualTier: tier,
          provider: provider.name,
        });
        return {
          provider,
          useMock: false,
          tier,
          reason: preferredTier !== tier
            ? `Requested tier "${preferredTier}" unavailable, escalated to "${tier}" with provider "${provider.name}"`
            : `Found available provider "${provider.name}" at requested tier "${tier}"`,
        };
      }
    }

    logger.warn('ai', 'tierRouter', 'routeToTier', `No provider available for preferred tier, falling back to mock`, {
      operation,
      preferredTier,
    });

    return {
      provider: null,
      useMock: true,
      tier: preferredTier,
      reason: `No available provider for operation "${operation}" at tier "${preferredTier}" (tried: ${fallbackChain.join(', ')}). Falling back to mock distiller.`,
    };
  }

  /**
   * Find an enabled provider for the given tier.
   * Returns the first matching provider, or null if none found.
   */
  private findProviderForTier(tier: AiTier): ProviderConfig | null {
    try {
      const providers = listProvidersFromAllSources();
      const match = providers.find((p) => p.enabled && p.tier === tier);
      return match ?? null;
    } catch (error) {
      logger.error('ai', 'tierRouter', 'findProvider', 'Failed to query providers', {
        tier,
        error: error instanceof Error ? error.message : String(error),
      });
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Singleton export
// ---------------------------------------------------------------------------

export const tierRouter = new TierRouter();
