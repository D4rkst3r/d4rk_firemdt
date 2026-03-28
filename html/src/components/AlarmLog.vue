<script setup lang="ts">
/**
 * AlarmLog.vue — Rechtes unteres Panel: "Ereignisprotokoll"
 *
 * Zeigt die letzten Alarm-Einträge des ausgewählten Systems als kompakte Timeline.
 * Farbige Dots links zeigen den Typ: rot = Alarm, grün = Störung behoben, blau = Wartung.
 * Timestamps werden relativ ("5 mins ago") und absolut ("28.03.26 14:30") angezeigt.
 *
 * Entspricht dem "EREIGNISPROTOKOLL" Panel im Mockup.
 */

import { ref, computed } from 'vue'
import { useMdtStore } from '@/stores/mdt'
import type { AlarmLogEntry, TriggerType } from '@/types'

const store = useMdtStore()

// v-dialog für die vollständige Log-Ansicht
const showFullLog = ref(false)

// ─── Berechnete Werte ────────────────────────────────────────

/**
 * Letzte 5 Log-Einträge des ausgewählten Systems für die kompakte Ansicht.
 * Die letzten 10 Einträge kommen bereits vom Server — wir zeigen nur die 5 neuesten.
 */
const recentLogs = computed<AlarmLogEntry[]>(() =>
  (store.selectedSystem?.logs ?? []).slice(0, 5)
)

/**
 * Alle Log-Einträge für den Dialog (bis zu 10 vom Server)
 */
const allLogs = computed<AlarmLogEntry[]>(() =>
  store.selectedSystem?.logs ?? []
)

// ─── Hilfsfunktionen ─────────────────────────────────────────

/**
 * Dot-Farbe je nach Trigger-Typ.
 * Entspricht dem Mockup: rot = Alarm, grün = System normal, blau = Wartung/Test
 */
function dotColor(entry: AlarmLogEntry): string {
  if (entry.trigger_type === 'automatic' || entry.trigger_type === 'manual') {
    return entry.acknowledged_by ? 'var(--color-normal)' : 'var(--color-alarm)'
  }
  return 'var(--color-info)'  // test = blau
}

/**
 * Icon je nach Trigger-Typ.
 * 👤 manual / 🤖 automatic / 🔧 test
 * In Vuetify MDI-Icons übersetzt.
 */
function triggerIcon(type: TriggerType): string {
  return {
    manual:    'mdi-hand-pointing-up',
    automatic: 'mdi-robot',
    test:      'mdi-wrench',
  }[type]
}

/**
 * Lesbares Label für den Trigger-Typ
 */
function triggerLabel(type: TriggerType): string {
  return { manual: 'Manuell', automatic: 'Automatisch', test: 'Test' }[type]
}

/**
 * Formatiert einen ISO-Timestamp als "DD.MM.YY HH:mm".
 * @param isoString - ISO 8601 Zeitstempel z.B. "2026-03-28T14:30:00Z"
 * @returns Formatierter String "28.03.26 14:30"
 *
 * Warum nicht moment.js? Für diese einfache Formatierung brauchen wir keine
 * externe Bibliothek — Date-Methoden sind ausreichend.
 */
function formatTimestamp(isoString: string): string {
  if (!isoString) return '–'
  try {
    const date = new Date(isoString)
    const dd   = String(date.getDate()).padStart(2, '0')
    const mm   = String(date.getMonth() + 1).padStart(2, '0')
    const yy   = String(date.getFullYear()).slice(-2)
    const hh   = String(date.getHours()).padStart(2, '0')
    const min  = String(date.getMinutes()).padStart(2, '0')
    return `${dd}.${mm}.${yy} ${hh}:${min}`
  } catch {
    return isoString
  }
}

/**
 * Berechnet die relative Zeit ("5 mins ago", "1 std ago").
 * @param isoString - ISO-Timestamp
 * @returns Lesbarer relativer String
 */
function relativeTime(isoString: string): string {
  if (!isoString) return ''
  try {
    const diffMs  = Date.now() - new Date(isoString).getTime()
    const diffMin = Math.floor(diffMs / 60000)
    const diffH   = Math.floor(diffMin / 60)
    const diffD   = Math.floor(diffH / 24)

    if (diffMin < 1)  return 'gerade eben'
    if (diffMin < 60) return `${diffMin} min ago`
    if (diffH < 24)   return `${diffH} std ago`
    return `${diffD} Tag${diffD > 1 ? 'e' : ''} ago`
  } catch {
    return ''
  }
}
</script>

<template>
  <!-- Panel-Header -->
  <div class="panel-header">
    <span class="panel-header__title">Ereignisprotokoll</span>
    <!-- Listenansicht-Icon → öffnet vollständigen Log-Dialog -->
    <v-btn
      icon
      variant="text"
      size="x-small"
      @click="showFullLog = true"
      title="Vollständigen Log öffnen"
    >
      <v-icon size="16" color="text-secondary">mdi-format-list-bulleted</v-icon>
    </v-btn>
  </div>

  <!-- Leer-Zustand -->
  <div v-if="!store.selectedSystem || recentLogs.length === 0" class="log-empty">
    <v-icon size="18" color="text-muted">mdi-history</v-icon>
    <span>Keine Einträge vorhanden</span>
  </div>

  <!-- Kompakte Timeline -->
  <div v-else class="log-list">
    <!--
      v-for mit Index: (item, index) in array
      Der Index wird hier nicht genutzt, aber :key="entry.id" ist wichtig.
      Wenn Pinia Live-Updates durchführt (neue Logs hinzugefügt), kann Vue
      anhand der ID entscheiden welche DOM-Elemente aktualisiert werden müssen.
    -->
    <div
      v-for="entry in recentLogs"
      :key="entry.id"
      class="log-item"
    >
      <!-- Farbiger Dot links -->
      <div class="log-item__dot-col">
        <div class="log-item__dot" :style="{ background: dotColor(entry), boxShadow: `0 0 5px ${dotColor(entry)}` }"></div>
        <!-- Vertikale Verbindungslinie zwischen Dots -->
        <div class="log-item__line"></div>
      </div>

      <!-- Inhalt: Zone + Typ-Badge + Zeit + Quittierung -->
      <div class="log-item__content">
        <div class="log-item__top">
          <!-- Trigger-Icon + Zone -->
          <v-icon size="12" color="text-muted" class="mr-1">{{ triggerIcon(entry.trigger_type) }}</v-icon>
          <span class="log-item__zone">{{ entry.zone }}</span>
        </div>

        <div class="log-item__meta">
          <!-- Trigger-Typ Badge -->
          <span class="log-item__type-badge">{{ triggerLabel(entry.trigger_type) }}</span>

          <!-- Timestamp -->
          <span class="log-item__time font-mono" :title="formatTimestamp(entry.triggered_at)">
            {{ relativeTime(entry.triggered_at) }}
          </span>
        </div>

        <!-- Quittierungs-Status -->
        <div v-if="entry.acknowledged_by" class="log-item__ack log-item__ack--done">
          <v-icon size="10">mdi-check-circle</v-icon>
          {{ entry.acknowledged_by }}
        </div>
        <div v-else class="log-item__ack log-item__ack--pending">
          <v-icon size="10">mdi-clock-outline</v-icon>
          Nicht quittiert
        </div>
      </div>
    </div>
  </div>

  <!-- ─── Vollständiger Log-Dialog ──────────────── -->
  <!--
    Lazy-loading: der Dialog-Inhalt wird erst gerendert wenn der Dialog
    zum ersten Mal geöffnet wird (eager=false, Standard in Vuetify 3).
  -->
  <v-dialog v-model="showFullLog" max-width="520">
    <v-card class="full-log-card">
      <div class="panel-header">
        <span class="panel-header__title">
          Alarm-Protokoll — {{ store.selectedSystem?.name }}
        </span>
        <v-btn icon variant="text" size="small" @click="showFullLog = false">
          <v-icon size="16">mdi-close</v-icon>
        </v-btn>
      </div>

      <div class="full-log-list">
        <div
          v-for="entry in allLogs"
          :key="entry.id"
          class="full-log-item"
        >
          <!-- Trigger-Icon -->
          <div class="full-log-item__icon">
            <v-icon size="18" :color="entry.acknowledged_by ? 'success' : 'error'">
              {{ triggerIcon(entry.trigger_type) }}
            </v-icon>
          </div>

          <!-- Haupt-Inhalt -->
          <div class="full-log-item__body">
            <div class="full-log-item__zone">{{ entry.zone }}</div>
            <div class="full-log-item__meta">
              <span class="full-log-item__type">{{ triggerLabel(entry.trigger_type) }}</span>
              <span class="full-log-item__time font-mono">
                {{ formatTimestamp(entry.triggered_at) }}
              </span>
            </div>
          </div>

          <!-- Quittierung -->
          <div class="full-log-item__ack">
            <template v-if="entry.acknowledged_by">
              <v-icon size="14" color="success">mdi-check-circle</v-icon>
              <span class="full-log-item__ack-name">{{ entry.acknowledged_by }}</span>
              <div class="full-log-item__ack-time font-mono">
                {{ formatTimestamp(entry.acknowledged_at ?? '') }}
              </div>
            </template>
            <template v-else>
              <v-icon size="14" color="error">mdi-close-circle</v-icon>
              <span class="full-log-item__ack-pending">Offen</span>
            </template>
          </div>
        </div>

        <div v-if="allLogs.length === 0" class="full-log-empty">
          Keine Alarm-Einträge für dieses System.
        </div>
      </div>
    </v-card>
  </v-dialog>
</template>

<style scoped>
/* ─── Leer-Zustand ───────────────────────────────── */
.log-empty {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  color: var(--text-muted);
  font-size: 12px;
}

/* ─── Kompakte Timeline ──────────────────────────── */
.log-list {
  padding: 8px 0;
  overflow-y: auto;
  flex: 1;
}

.log-item {
  display: flex;
  gap: 10px;
  padding: 4px 12px;
  min-height: 0;
}

/* Dot-Spalte (links) */
.log-item__dot-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding-top: 3px;
  flex-shrink: 0;
  width: 12px;
}

.log-item__dot {
  width: 9px;
  height: 9px;
  border-radius: 50%;
  flex-shrink: 0;
}

/* Vertikale Linie zwischen Dots */
.log-item__line {
  width: 1px;
  flex: 1;
  background: var(--border);
  margin-top: 3px;
  min-height: 8px;
}

/* Letztes Item: keine Linie */
.log-item:last-child .log-item__line {
  display: none;
}

/* Inhalt */
.log-item__content {
  flex: 1;
  padding-bottom: 8px;
  min-width: 0;
}

.log-item__top {
  display: flex;
  align-items: center;
  margin-bottom: 2px;
}

.log-item__zone {
  font-size: 12px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.log-item__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 2px;
}

.log-item__type-badge {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-muted);
  background: rgba(33, 41, 58, 0.6);
  padding: 1px 5px;
  border-radius: 2px;
}

.log-item__time {
  font-size: 10px;
  color: var(--text-muted);
}

.log-item__ack {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 10px;
}

.log-item__ack--done    { color: var(--color-normal);  }
.log-item__ack--pending { color: var(--color-alarm); opacity: 0.7; }

/* ─── Vollständiger Log Dialog ───────────────────── */
.full-log-card {
  background: var(--bg-surface) !important;
  border: 1px solid var(--border-light) !important;
  border-radius: 2px !important;
}

.full-log-list {
  max-height: 400px;
  overflow-y: auto;
  padding: 4px 0;
}

.full-log-item {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 10px 16px;
  border-bottom: 1px solid rgba(33, 41, 58, 0.5);
}
.full-log-item:hover { background: rgba(255, 255, 255, 0.02); }

.full-log-item__icon {
  flex-shrink: 0;
  margin-top: 2px;
}

.full-log-item__body { flex: 1; min-width: 0; }

.full-log-item__zone {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 3px;
}

.full-log-item__meta {
  display: flex;
  gap: 10px;
  align-items: center;
}

.full-log-item__type {
  font-size: 10px;
  color: var(--text-muted);
  background: rgba(33, 41, 58, 0.6);
  padding: 1px 6px;
  border-radius: 2px;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.full-log-item__time {
  font-size: 11px;
  color: var(--text-secondary);
}

.full-log-item__ack {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 2px;
  flex-shrink: 0;
  text-align: right;
}

.full-log-item__ack-name {
  font-size: 11px;
  color: var(--color-normal);
}

.full-log-item__ack-time {
  font-size: 10px;
  color: var(--text-muted);
}

.full-log-item__ack-pending {
  font-size: 11px;
  color: var(--color-alarm);
  opacity: 0.8;
}

.full-log-empty {
  padding: 24px;
  text-align: center;
  color: var(--text-muted);
  font-size: 12px;
}
</style>
