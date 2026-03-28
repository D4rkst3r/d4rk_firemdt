<script setup lang="ts">
/**
 * MaintenanceQueue.vue — Unteres mittleres Panel: "Wartungswarteschlange"
 *
 * Zeigt alle Geräte des ausgewählten Systems mit Health < 50%, aufsteigend sortiert.
 * Entspricht dem "WARTUNGSWARTESCHLANGE" Panel im Mockup.
 */

import { useMdtStore } from '@/stores/mdt'
import type { Device } from '@/types'

const store = useMdtStore()

/**
 * Priorität-Badge Konfiguration basierend auf Health-Wert.
 * < 20% → Hohe Priorität (rot/orange), 20–49% → Mittel (gelb)
 */
function priorityConfig(health: number): { label: string; color: string } {
  if (health < 20) return { label: 'HOHE PRIORITÄT', color: 'var(--color-alarm)' }
  return { label: 'MITTEL', color: 'var(--color-trouble)' }
}

/**
 * Gerätetyp-Label kurz
 */
function typeLabel(device: Device): string {
  return {
    smoke: 'Rauchmelder',
    pull:  'Handfeuermelder',
    siren: 'Sirene',
    panel: 'Zentrale',
  }[device.type] ?? 'Gerät'
}
</script>

<template>
  <!-- Panel-Header -->
  <div class="panel-header">
    <span class="panel-header__title">Wartungswarteschlange</span>
    <v-icon size="16" color="text-secondary">mdi-cog</v-icon>
  </div>

  <!-- Leer: alles OK -->
  <div v-if="store.maintenanceQueue.length === 0" class="queue-empty">
    <v-icon size="18" color="normal">mdi-check-all</v-icon>
    <span>Alle Geräte in Ordnung</span>
  </div>

  <!-- Wartungs-Items -->
  <div v-else class="queue-list">
    <div
      v-for="device in store.maintenanceQueue"
      :key="device.id"
      class="queue-item"
    >
      <!-- Schraubenschlüssel Icon -->
      <v-icon size="16" color="text-secondary" class="queue-item__icon">
        mdi-wrench
      </v-icon>

      <!-- Name + Zone -->
      <div class="queue-item__info">
        <div class="queue-item__name">{{ typeLabel(device) }}</div>
        <div class="queue-item__zone">@ {{ device.zone }}</div>
      </div>

      <!-- Health -->
      <div class="queue-item__health font-mono" :style="{ color: priorityConfig(device.health).color }">
        {{ device.health }}%
      </div>

      <!-- Priorität-Badge -->
      <div
        class="queue-item__priority"
        :style="{ color: priorityConfig(device.health).color, borderColor: priorityConfig(device.health).color }"
      >
        {{ priorityConfig(device.health).label }}
      </div>
    </div>
  </div>
</template>

<style scoped>
.queue-empty {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  color: var(--text-secondary);
  font-size: 12px;
}

.queue-list {
  overflow-y: auto;
  max-height: 140px;
}

.queue-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 7px 12px;
  border-bottom: 1px solid rgba(33, 41, 58, 0.4);
}

.queue-item:hover { background: rgba(255, 255, 255, 0.02); }

.queue-item__icon { flex-shrink: 0; }

.queue-item__info {
  flex: 1;
  min-width: 0;
}

.queue-item__name {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-primary);
}

.queue-item__zone {
  font-size: 10px;
  color: var(--text-secondary);
}

.queue-item__health {
  font-size: 12px;
  font-weight: 700;
  flex-shrink: 0;
}

.queue-item__priority {
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  padding: 2px 6px;
  border: 1px solid;
  border-radius: 2px;
  flex-shrink: 0;
  white-space: nowrap;
}
</style>
