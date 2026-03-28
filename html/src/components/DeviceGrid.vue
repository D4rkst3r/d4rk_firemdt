<script setup lang="ts">
/**
 * DeviceGrid.vue — Oberes mittleres Panel: "Geräteübersicht"
 *
 * Zeigt für das ausgewählte System:
 *  - 3 Gerätekacheln: Rauchmelder / Handfeuermelder / Sirenen (X/Y ONLINE)
 *  - Mini-Grundriss/Heatmap als SVG mit farbigen Dots pro Gerät (Health-basiert)
 *  - v-progress-linear für Health jedes einzelnen Geräts (reaktiv via Store)
 */

import { computed } from 'vue'
import { useMdtStore } from '@/stores/mdt'
import type { Device, DeviceType } from '@/types'

const store = useMdtStore()

// ─── Gerätekachel-Konfiguration ─────────────────────────────

interface DeviceTileConfig {
  type: DeviceType
  label: string
  icon: string
}

// Konfiguration für die drei oberen Kacheln (wie im Mockup)
const tileTypes: DeviceTileConfig[] = [
  { type: 'smoke', label: 'Rauchmelder',      icon: 'mdi-smoke-detector' },
  { type: 'pull',  label: 'Handfeuermelder',  icon: 'mdi-hand-pointing-up' },
  { type: 'siren', label: 'Sirenen',           icon: 'mdi-bullhorn' },
]

// ─── Computed-Werte ─────────────────────────────────────────

/**
 * Geräte des ausgewählten Systems nach Typ gruppiert.
 * computed() cached das Ergebnis — wird nur neu berechnet wenn sich
 * store.selectedSystem ändert (z.B. anderes System ausgewählt oder Live-Update).
 */
const devicesByType = computed(() => {
  const devices = store.selectedSystem?.devices ?? []
  const grouped: Record<DeviceType, Device[]> = {
    smoke: [],
    pull:  [],
    siren: [],
    panel: [],
  }
  for (const device of devices) {
    grouped[device.type]?.push(device)
  }
  return grouped
})

/**
 * Gibt die Anzahl "ONLINE" (health > 0) für einen Typ zurück.
 * @param type - DeviceType
 * @returns { online: number, total: number }
 */
function getOnlineCount(type: DeviceType): { online: number; total: number } {
  const devices = devicesByType.value[type] ?? []
  return {
    online: devices.filter(d => d.health > 0).length,
    total:  devices.length,
  }
}

/**
 * Alle Geräte (außer Panel) für die Health-Liste und SVG-Heatmap.
 */
const allDevices = computed<Device[]>(() =>
  store.selectedSystem?.devices.filter(d => d.type !== 'panel') ?? []
)

/**
 * Gibt die Health-Farbe zurück: grün ≥75%, gelb ≥30%, rot <30%.
 * Diese Funktion wird an mehreren Stellen genutzt.
 */
function healthColor(health: number): string {
  if (health >= 75) return 'var(--color-normal)'
  if (health >= 30) return 'var(--color-trouble)'
  return 'var(--color-alarm)'
}

/**
 * Vuetify v-progress-linear color-Prop — akzeptiert CSS-Farbe oder Theme-Farbe.
 */
function progressColor(health: number): string {
  if (health >= 75) return 'success'
  if (health >= 30) return 'warning'
  return 'error'
}

/**
 * Gerät-Typ Icon
 */
function deviceIcon(type: DeviceType): string {
  return {
    smoke: 'mdi-smoke-detector',
    pull:  'mdi-hand-pointing-up',
    siren: 'mdi-bullhorn',
    panel: 'mdi-monitor-dashboard',
  }[type] ?? 'mdi-microchip'
}

// ─── SVG Mini-Grundriss Dots ─────────────────────────────────

/**
 * Generiert Pseudo-Koordinaten für die SVG-Heatmap.
 * Da wir keine echten Gebäude-Grundrisse haben, verteilen wir
 * die Geräte in einem Raster innerhalb des SVG-Viewbox.
 *
 * @returns Array von { x, y, color, label } für SVG-Circles
 */
const svgDots = computed(() => {
  const devices = allDevices.value
  if (devices.length === 0) return []

  // SVG Viewbox ist 200x120 — Geräte in einem Raster verteilen
  const cols    = Math.ceil(Math.sqrt(devices.length * 1.5))
  const rows    = Math.ceil(devices.length / cols)
  const cellW   = 180 / cols
  const cellH   = 100 / rows
  const offsetX = 10
  const offsetY = 10

  return devices.map((device, i) => {
    const col = i % cols
    const row = Math.floor(i / cols)
    // Leichtes Jitter damit es nicht zu starr aussieht
    const jitterX = ((device.id * 7) % 8) - 4
    const jitterY = ((device.id * 13) % 6) - 3

    return {
      x:     offsetX + col * cellW + cellW / 2 + jitterX,
      y:     offsetY + row * cellH + cellH / 2 + jitterY,
      color: healthColor(device.health),
      label: device.zone,
      health: device.health,
    }
  })
})
</script>

<template>
  <div class="device-grid-panel">

    <!-- ─── Panel-Header ──────────────────────────── -->
    <div class="panel-header">
      <span class="panel-header__title">Geräteübersicht</span>
      <v-icon size="16" color="text-secondary">mdi-grid</v-icon>
    </div>

    <!-- Kein System ausgewählt -->
    <div v-if="!store.selectedSystem" class="no-system">
      <v-icon size="24" color="text-muted">mdi-select-off</v-icon>
      <span>Kein System ausgewählt</span>
    </div>

    <template v-else>

      <!-- ─── 3 Gerätekacheln ────────────────────── -->
      <div class="tiles-row">
        <div
          v-for="tile in tileTypes"
          :key="tile.type"
          class="device-tile"
        >
          <!-- Icon -->
          <div class="device-tile__icon-wrap">
            <v-icon size="22" color="text-secondary">{{ tile.icon }}</v-icon>
          </div>

          <!-- Counts -->
          <div class="device-tile__body">
            <div class="device-tile__label">{{ tile.label }}</div>
            <!-- Zählt online Geräte dieses Typs -->
            <div
              class="device-tile__count font-mono"
              :class="{
                'text-alarm': getOnlineCount(tile.type).online === 0 && getOnlineCount(tile.type).total > 0
              }"
            >
              {{ getOnlineCount(tile.type).online }}/{{ getOnlineCount(tile.type).total }}
            </div>
            <div class="device-tile__online">
              <span
                class="mdt-dot"
                :class="getOnlineCount(tile.type).online > 0 ? 'mdt-dot--green' : 'mdt-dot--red'"
              ></span>
              ONLINE
            </div>
          </div>
        </div>
      </div>

      <!-- ─── SVG Mini-Grundriss ─────────────────── -->
      <div class="floorplan-wrap">
        <div class="floorplan-label">GEBÄUDE-ÜBERSICHT</div>
        <svg
          class="floorplan-svg"
          viewBox="0 0 200 120"
          xmlns="http://www.w3.org/2000/svg"
          preserveAspectRatio="xMidYMid meet"
        >
          <!-- Raumgitter-Hintergrund -->
          <rect x="5" y="5" width="190" height="110" fill="rgba(33,41,58,0.5)" rx="1"/>

          <!-- Symbolische Raumtrennungen -->
          <line x1="70"  y1="5"  x2="70"  y2="115" stroke="rgba(33,41,58,0.8)"  stroke-width="1"/>
          <line x1="130" y1="5"  x2="130" y2="115" stroke="rgba(33,41,58,0.8)"  stroke-width="1"/>
          <line x1="5"   y1="60" x2="195" y2="60"  stroke="rgba(33,41,58,0.8)"  stroke-width="1"/>

          <!-- Gerät-Dots mit Health-Farbe -->
          <!--
            v-for auf SVG-Elemente funktioniert genauso wie auf HTML-Elemente.
            :cx / :cy = dynamische Attribute → Vue-Binding ohne Template-Syntax
          -->
          <g v-for="(dot, idx) in svgDots" :key="idx">
            <!-- Glow-Halo -->
            <circle
              :cx="dot.x"
              :cy="dot.y"
              r="5"
              :fill="dot.color"
              opacity="0.2"
            />
            <!-- Haupt-Dot -->
            <circle
              :cx="dot.x"
              :cy="dot.y"
              r="3"
              :fill="dot.color"
            />
          </g>
        </svg>

        <!-- Health-Legende -->
        <div class="floorplan-legend">
          <span class="legend-item"><span class="mdt-dot mdt-dot--green"></span>≥75%</span>
          <span class="legend-item"><span class="mdt-dot mdt-dot--yellow"></span>30–74%</span>
          <span class="legend-item"><span class="mdt-dot mdt-dot--red"></span>&lt;30%</span>
        </div>
      </div>

      <!-- ─── Geräteliste mit Health-Bars ───────── -->
      <div class="device-list-section">
        <div class="device-list-header">
          ALLE MELDER ({{ allDevices.length }})
        </div>

        <div class="device-list">
          <div
            v-for="device in allDevices"
            :key="device.id"
            class="device-row"
          >
            <!-- Icon + Typ -->
            <v-icon size="14" :color="device.health > 0 ? 'text-secondary' : 'error'" class="device-row__icon">
              {{ deviceIcon(device.type) }}
            </v-icon>

            <!-- Zone-Name -->
            <div class="device-row__zone">{{ device.zone }}</div>

            <!-- ID -->
            <div class="device-row__id font-mono">#{{ device.id }}</div>

            <!-- Health-Prozentzahl -->
            <div
              class="device-row__health font-mono"
              :style="{ color: healthColor(device.health) }"
            >
              {{ device.health }}%
            </div>

            <!-- Vuetify v-progress-linear:
                 :model-value = Wert (0–100)
                 :color = Farbe aus dem Vuetify-Theme (success/warning/error)
                 height = Höhe in px
                 bg-color = Hintergrundfarbe des Tracks
                 Reagiert reaktiv auf Store-Updates — wenn updateHealth() aufgerufen wird,
                 ändert sich device.health und die Bar aktualisiert sich ohne Re-Mount. -->
            <v-progress-linear
              :model-value="device.health"
              :color="progressColor(device.health)"
              bg-color="rgba(33,41,58,0.8)"
              height="3"
              class="device-row__bar"
            />
          </div>

          <!-- Leere Liste -->
          <div v-if="allDevices.length === 0" class="device-list-empty">
            Keine Melder in diesem System
          </div>
        </div>
      </div>

    </template>
  </div>
</template>

<style scoped>
.device-grid-panel {
  display: flex;
  flex-direction: column;
  border-bottom: 1px solid var(--border);
}

.no-system {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 24px;
  color: var(--text-muted);
  font-size: 12px;
}

/* ─── Kacheln ────────────────────────────────────── */
.tiles-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  border-bottom: 1px solid var(--border);
}

.device-tile {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-right: 1px solid var(--border);
}
.device-tile:last-child { border-right: none; }

.device-tile__icon-wrap {
  width: 36px;
  height: 36px;
  background: rgba(33, 41, 58, 0.8);
  border: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  border-radius: 2px;
}

.device-tile__body { flex: 1; min-width: 0; }

.device-tile__label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.08em;
  color: var(--text-secondary);
  text-transform: uppercase;
  margin-bottom: 2px;
}

.device-tile__count {
  font-size: 18px;
  font-weight: 700;
  color: var(--text-primary);
  line-height: 1.1;
}

.device-tile__online {
  display: flex;
  align-items: center;
  font-size: 9px;
  font-weight: 700;
  color: var(--color-normal);
  letter-spacing: 0.12em;
  margin-top: 2px;
}

/* ─── SVG Grundriss ──────────────────────────────── */
.floorplan-wrap {
  padding: 8px 12px;
  border-bottom: 1px solid var(--border);
  background: rgba(7, 9, 12, 0.4);
}

.floorplan-label {
  font-size: 9px;
  font-weight: 600;
  letter-spacing: 0.15em;
  color: var(--text-muted);
  margin-bottom: 6px;
}

.floorplan-svg {
  width: 100%;
  height: 90px;
  display: block;
}

.floorplan-legend {
  display: flex;
  gap: 12px;
  margin-top: 4px;
  font-size: 9px;
  color: var(--text-muted);
  letter-spacing: 0.08em;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 4px;
}

/* ─── Geräteliste ────────────────────────────────── */
.device-list-section {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.device-list-header {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.15em;
  color: var(--text-muted);
  padding: 6px 12px;
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
}

.device-list {
  overflow-y: auto;
  flex: 1;
}

.device-row {
  display: grid;
  /* Icon | Zone | ID | Health% | ProgressBar */
  grid-template-columns: 20px 1fr 50px 40px 80px;
  align-items: center;
  gap: 6px;
  padding: 5px 12px;
  border-bottom: 1px solid rgba(33, 41, 58, 0.4);
  min-height: 0;
}

.device-row:hover { background: rgba(255, 255, 255, 0.02); }

.device-row__icon { flex-shrink: 0; }

.device-row__zone {
  font-size: 12px;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.device-row__id {
  font-size: 10px;
  color: var(--text-muted);
  text-align: right;
}

.device-row__health {
  font-size: 11px;
  font-weight: 700;
  text-align: right;
}

.device-row__bar {
  /* Vollbreite in der Grid-Zelle */
}

.device-list-empty {
  padding: 16px 12px;
  font-size: 12px;
  color: var(--text-muted);
  text-align: center;
}
</style>
