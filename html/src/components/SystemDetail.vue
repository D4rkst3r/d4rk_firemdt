<script setup lang="ts">
/**
 * SystemDetail.vue — Header des mittleren Panels
 *
 * Zeigt Systemname, Status-Badge und QUITTIEREN-Button für das aktuell
 * ausgewählte System. Positioniert sich über DeviceGrid in der Mittel-Spalte.
 *
 * Die Tabs "Geräte | Alarm-Log" steuern welcher Inhalt im mittleren Bereich
 * angezeigt wird — DeviceGrid.vue oder die kompakte Alarm-Log-Ansicht.
 */

import { computed } from 'vue'
import { useMdtStore } from '@/stores/mdt'

const store = useMdtStore()

// ─── Tab-Verwaltung ──────────────────────────────────────────
// ref() erstellt eine reaktive Variable.
// Wenn activeTab sich ändert → Tab-Inhalt re-rendert sich.
// '0' und '1' sind die Tab-Indices (Vuetify v-tabs verwendet numerische oder String-Keys)
// computed() — abgeleiteter Wert: Ist der QUITTIEREN-Button aktiv?
// Abhängig von store.selectedSystem.status → reagiert auf Live-Updates
const canQuittieren = computed<boolean>(() =>
  store.selectedSystem?.status === 'alarm'
)

// Status-Badge Config — eine einfache Mapping-Funktion vermeidet v-if/v-else-Ketten im Template
const statusConfig = computed(() => {
  const status = store.selectedSystem?.status ?? 'normal'
  return {
    alarm:   { label: 'ALARM AKTIV',   color: 'alarm',  icon: 'mdi-alarm-light' },
    trouble: { label: 'STÖRUNG',        color: 'trouble', icon: 'mdi-alert-circle' },
    normal:  { label: 'NORMALBETRIEB',  color: 'normal',  icon: 'mdi-check-circle' },
  }[status]
})
</script>

<template>
  <!-- Kein System ausgewählt → Platzhalter -->
  <div v-if="!store.selectedSystem" class="detail-empty">
    <v-icon size="20" color="text-muted">mdi-cursor-pointer</v-icon>
    <span>System aus der Liste auswählen</span>
  </div>

  <!-- System ausgewählt → Header + Tabs -->
  <div v-else class="detail-header">

    <!-- Obere Zeile: Systemname + Status-Badge + Quittieren -->
    <div class="detail-header__top">
      <div class="detail-header__info">
        <div class="detail-header__id font-mono">
          SYSTEM #{{ String(store.selectedSystem.id).padStart(3, '0') }}
        </div>
        <div class="detail-header__name">{{ store.selectedSystem.name }}</div>
      </div>

      <div class="detail-header__controls">
        <!-- Status-Badge: color-Prop nutzt unsere Custom-Vuetify-Theme-Farben
             variant="tonal" = halbtransparenter Hintergrund (Vuetify 3 Variante) -->
        <v-chip
          :color="statusConfig.color"
          variant="tonal"
          density="comfortable"
          class="status-chip"
        >
          <template #prepend>
            <v-icon size="14" class="mr-1">{{ statusConfig.icon }}</v-icon>
          </template>
          {{ statusConfig.label }}
        </v-chip>

        <!--
          QUITTIEREN-Button: nur enabled wenn Alarm aktiv.
          :disabled="!canQuittieren" — Vue-Binding, :disabled = dynamisches Attribut
          Ohne ':' wäre es ein statischer String "!canQuittieren" → Vuetify ignoriert das
        -->
        <v-btn
          :disabled="!canQuittieren"
          color="action-quittieren"
          variant="flat"
          size="small"
          class="quittieren-btn"
          @click="store.quittieren()"
        >
          <v-icon start size="16">mdi-bell-cancel</v-icon>
          QUITTIEREN
        </v-btn>
      </div>
    </div>

    <!-- Tab-Navigation -->
    <!--
      v-model="store.activeTab": Two-Way-Binding zwischen Tab-Komponente und activeTab-ref.
      Wenn der Nutzer Tab 2 klickt → activeTab.value = 1 → computed-Werte reagieren.
      v-model ist syntaktischer Zucker für :modelValue + @update:modelValue.
    -->
    <v-tabs
      v-model="store.activeTab"
      density="compact"
      class="detail-tabs"
      color="primary"
      bg-color="transparent"
    >
      <v-tab :value="0" class="detail-tab">
        <v-icon start size="14">mdi-microchip</v-icon>
        GERÄTE
      </v-tab>
      <v-tab :value="1" class="detail-tab">
        <v-icon start size="14">mdi-history</v-icon>
        ALARM-LOG
      </v-tab>
    </v-tabs>
  </div>
</template>

<style scoped>
/* Kein System ausgewählt */
.detail-empty {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
  color: var(--text-muted);
  font-size: 12px;
}

/* Header Container */
.detail-header {
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
  flex-shrink: 0;
}

/* Obere Zeile */
.detail-header__top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 16px 8px;
  gap: 12px;
}

.detail-header__info {
  min-width: 0;
  flex: 1;
}

.detail-header__id {
  font-size: 10px;
  color: var(--text-muted);
  letter-spacing: 0.1em;
  margin-bottom: 2px;
}

.detail-header__name {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: 0.05em;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.detail-header__controls {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}

/* Status-Chip Override */
.status-chip {
  font-family: var(--font-ui) !important;
  font-size: 11px !important;
  font-weight: 700 !important;
  letter-spacing: 0.08em !important;
  border-radius: 2px !important;
}

/* Quittieren-Button */
.quittieren-btn {
  font-size: 11px !important;
  letter-spacing: 0.1em !important;
  height: 28px !important;
  min-width: 0 !important;
}

/* Tab-Leiste */
.detail-tabs {
  border-top: 1px solid var(--border);
  height: 36px !important;
}

/* Einzelner Tab */
.detail-tab {
  font-family: var(--font-ui) !important;
  font-size: 11px !important;
  font-weight: 700 !important;
  letter-spacing: 0.1em !important;
  min-width: 100px !important;
  height: 36px !important;
  color: var(--text-secondary) !important;
}
</style>