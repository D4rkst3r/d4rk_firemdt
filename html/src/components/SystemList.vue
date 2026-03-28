<script setup lang="ts">
/**
 * SystemList.vue — Linke Spalte des MDT
 *
 * Zeigt alle BMA-Systeme als klickbare Liste.
 * Sortierung: alarm → trouble → normal, dann alphabetisch (via Store-Getter).
 * Das ausgewählte System triggert die mittlere und rechte Spalte.
 */

import { useMdtStore } from '@/stores/mdt'
import type { SystemStatus } from '@/types'

// useStore() aufrufen — gibt die reaktive Store-Instanz zurück.
// "Reaktiv" bedeutet: wenn store.sortedSystems sich ändert, re-rendert diese Komponente automatisch.
const store = useMdtStore()

// ─── Hilfsfunktionen ────────────────────────────────────────

/**
 * Gibt die CSS-Klasse für den Statustext zurück.
 * @param status - SystemStatus ('alarm' | 'trouble' | 'normal')
 * @returns CSS-Klassenname für die Textfarbe
 */
function statusClass(status: SystemStatus): string {
  return {
    alarm:   'text-alarm',
    trouble: 'text-trouble',
    normal:  'text-normal',
  }[status]
}

/**
 * Formatiert den Status als deutschen Anzeigetext.
 * Für 'alarm' wird auch der Zonenname des letzten Alarms angezeigt.
 */
function statusLabel(status: SystemStatus, alarmZone?: string): string {
  if (status === 'alarm') return alarmZone ? `ALARM – ${alarmZone}` : 'ALARM'
  if (status === 'trouble') return 'STÖRUNG – Prüfen'
  return 'NORMAL'
}

/**
 * Gibt das Vuetify-Icon für den Gebäudetyp zurück.
 * Erkennt anhand des Systemnamens ob es sich um ein Krankenhaus, Lager etc. handelt.
 * Fallback: mdi-office-building
 */
function buildingIcon(name: string): string {
  const lower = name.toLowerCase()
  if (lower.includes('krankenhaus') || lower.includes('hospital')) return 'mdi-hospital-building'
  if (lower.includes('lager') || lower.includes('halle'))           return 'mdi-warehouse'
  if (lower.includes('polizei'))                                     return 'mdi-police-badge'
  if (lower.includes('schule') || lower.includes('uni'))            return 'mdi-school'
  if (lower.includes('bank'))                                        return 'mdi-bank'
  return 'mdi-office-building'
}
</script>

<template>
  <!-- Panel-Header -->
  <div class="panel-header">
    <span class="panel-header__title">Aktive Systeme</span>
    <!-- Gear-Icon wie im Mockup — aktuell ohne Funktion, für zukünftige Filter-Option -->
    <v-icon size="16" color="text-secondary">mdi-cog</v-icon>
  </div>

  <!-- Systeme-Zähler -->
  <div class="systems-counter">
    <span class="font-mono">{{ store.systems.length }}</span>
    <span class="systems-counter__label">BMA-ANLAGEN REGISTRIERT</span>
  </div>

  <!-- Leere-Zustand wenn noch keine Daten geladen -->
  <div v-if="store.systems.length === 0" class="empty-state">
    <v-icon size="32" color="text-muted">mdi-lan-disconnect</v-icon>
    <p>Keine Systeme verfügbar</p>
    <p class="empty-state__sub">Verbindung zum Server wird hergestellt...</p>
  </div>

  <!--
    v-list: Vuetify-Listenkomponente mit density="compact" (weniger Padding pro Item).
    "density" in Vuetify steuert die Dichte: 'default' | 'comfortable' | 'compact'
    Je dichter, desto weniger Vertical Padding pro Item — gut für Listen mit vielen Einträgen.
  -->
  <div class="systems-list" v-else>
    <!--
      v-for: Vue-Direktive zum Rendern von Listen.
      ":key" ist PFLICHT für Vue's Virtual DOM Reconciliation —
      ohne :key kann Vue nicht effizient zwischen Updates unterscheiden.
      Wir nutzen system.id als stabilen eindeutigen Key.
    -->
    <div
      v-for="system in store.sortedSystems"
      :key="system.id"
      class="system-item"
      :class="{
        'system-item--selected': store.selectedSystemId === system.id,
        'system-item--alarm':    system.status === 'alarm',
        'system-item--trouble':  system.status === 'trouble',
      }"
      @click="store.selectSystem(system.id)"
    >
      <!-- Gebäude-Icon mit Statusfarbe -->
      <div class="system-item__icon-wrap" :class="`system-item__icon-wrap--${system.status}`">
        <v-icon size="20">{{ buildingIcon(system.name) }}</v-icon>
      </div>

      <!-- Name + Status -->
      <div class="system-item__body">
        <div class="system-item__name">{{ system.name }}</div>
        <div class="system-item__status" :class="statusClass(system.status)">
          {{ statusLabel(system.status, system.logs[0]?.zone) }}
        </div>
        <div class="system-item__meta font-mono">
          ID {{ String(system.id).padStart(3, '0') }} ·
          {{ system.devices.length }} MELDER
        </div>
      </div>

      <!-- Pulsierender Ring-Indicator rechts bei Alarm -->
      <!-- v-if vs v-show: v-if entfernt das Element komplett aus dem DOM.
           v-show versteckt es nur per CSS. Hier v-if, da nur 1-2 Alarm-Items erwartet. -->
      <div v-if="system.status === 'alarm'" class="system-item__alarm-ring pulse"></div>
      <div v-else-if="system.status === 'trouble'" class="system-item__trouble-indicator"></div>
    </div>
  </div>
</template>

<style scoped>
/* ─── Container ────────────────────────────────────── */
.systems-list {
  flex: 1;
  overflow-y: auto;
  padding: 4px 0;
}

/* ─── Zähler-Banner ──────────────────────────────── */
.systems-counter {
  display: flex;
  align-items: baseline;
  gap: 6px;
  padding: 8px 12px;
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
}

.systems-counter .font-mono {
  font-size: 18px;
  font-weight: 700;
  color: var(--color-primary);
}

.systems-counter__label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.12em;
  color: var(--text-muted);
  text-transform: uppercase;
}

/* ─── Leerer Zustand ─────────────────────────────── */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 8px;
  flex: 1;
  padding: 32px 16px;
  color: var(--text-muted);
  font-size: 13px;
  text-align: center;
}
.empty-state__sub { font-size: 11px; color: var(--text-muted); }

/* ─── System-Item ────────────────────────────────── */
.system-item {
  position: relative;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-left: 3px solid transparent;
  border-bottom: 1px solid rgba(33, 41, 58, 0.5);
  cursor: pointer;
  transition: background 0.12s, border-color 0.12s;
  user-select: none;
}

.system-item:hover {
  background: rgba(255, 255, 255, 0.04);
}

/* Ausgewählt: linke farbige Border + leichter Hintergrund */
.system-item--selected {
  background: rgba(244, 109, 47, 0.07);
  border-left-color: var(--color-primary);
}

/* Alarm-Status: roter Hintergrund-Tint */
.system-item--alarm {
  background: rgba(248, 81, 73, 0.06);
}
.system-item--alarm:hover,
.system-item--alarm.system-item--selected {
  background: rgba(248, 81, 73, 0.12);
  border-left-color: var(--color-alarm);
}

/* Störungs-Status: gelber Tint */
.system-item--trouble {
  background: rgba(210, 153, 34, 0.05);
}
.system-item--trouble.system-item--selected {
  background: rgba(210, 153, 34, 0.1);
  border-left-color: var(--color-trouble);
}

/* ─── Icon-Container ─────────────────────────────── */
.system-item__icon-wrap {
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 2px;
  flex-shrink: 0;
}

.system-item__icon-wrap--normal  { background: rgba(63, 185, 80, 0.12);  color: var(--color-normal);  }
.system-item__icon-wrap--trouble { background: rgba(210, 153, 34, 0.15); color: var(--color-trouble); }
.system-item__icon-wrap--alarm   { background: rgba(248, 81, 73, 0.2);   color: var(--color-alarm);   }

/* ─── Text-Inhalte ───────────────────────────────── */
.system-item__body {
  flex: 1;
  min-width: 0;  /* Verhindert Text-Overflow in Flex-Containern */
}

.system-item__name {
  font-size: 13px;
  font-weight: 600;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.system-item__status {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.06em;
  margin-top: 2px;
}

/* CSS-Klassen für Statusfarben — werden dynamisch via :class gesetzt */
.text-alarm   { color: var(--color-alarm); }
.text-trouble { color: var(--color-trouble); }
.text-normal  { color: var(--color-normal); }

.system-item__meta {
  font-size: 10px;
  color: var(--text-muted);
  margin-top: 2px;
  letter-spacing: 0.05em;
}

/* ─── Alarm-Ring Indikator ───────────────────────── */
.system-item__alarm-ring {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: var(--color-alarm);
  flex-shrink: 0;
}

.system-item__trouble-indicator {
  width: 8px;
  height: 8px;
  background: var(--color-trouble);
  flex-shrink: 0;
  border-radius: 50%;
}
</style>
