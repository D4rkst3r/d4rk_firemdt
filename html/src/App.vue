<script setup lang="ts">
/**
 * App.vue — Root-Komponente des MDT
 *
 * Zuständig für:
 * 1. NUI-Message Bridge: window.addEventListener('message') empfängt
 *    alle SendNUIMessage()-Aufrufe aus c_main.lua und leitet sie an den Store weiter
 * 2. Tastatur-Events: ESC schließt das MDT
 * 3. Das 3-Spalten-Dashboard-Layout
 * 4. Anzeige-Steuerung: MDT nur rendern wenn isOpen === true
 */

// onMounted: Lifecycle-Hook — wird einmal ausgeführt wenn Komponente ins DOM eingefügt wurde
// onUnmounted: Cleanup-Hook — wichtig um Event-Listener zu entfernen
import { onMounted, onUnmounted } from 'vue'
import { useMdtStore } from '@/stores/mdt'
import type { NuiMessage } from '@/types'

// Komponenten-Imports — Vue SFCs (Single File Components)
import SystemList from '@/components/SystemList.vue'
import SystemDetail from '@/components/SystemDetail.vue'
import DeviceGrid from '@/components/DeviceGrid.vue'
import MaintenanceQueue from '@/components/MaintenanceQueue.vue'
import ActionPanel from '@/components/ActionPanel.vue'
import AlarmLog from '@/components/AlarmLog.vue'

// useMdtStore() gibt die Store-Instanz zurück.
// Da Pinia global registriert ist, gibt es immer dieselbe Instanz — kein Singleton-Problem.
const store = useMdtStore()

// =========================================================
// NUI-Message Bridge
// FiveM → Lua → SendNUIMessage(json) → window.postMessage (intern)
// → Vue empfängt es als MessageEvent
// =========================================================

/**
 * Verarbeitet eingehende NUI-Messages von c_main.lua.
 * Der event.data enthält das JSON-Objekt das Lua mit SendNUIMessage() gesendet hat.
 *
 * WICHTIG: Im Browser (npm run dev) kommen keine echten NUI-Messages.
 * Zum Testen können simulierte Messages manuell im Browser-Console gesendet werden:
 *   window.postMessage({ type: 'mdt_open' }, '*')
 *   window.postMessage({ type: 'mdt_data', systems: [...] }, '*')
 */
function onNuiMessage(event: MessageEvent<NuiMessage>) {
  const data = event.data

  // TypeScript Discriminated Union: anhand von data.type weiß TS welche
  // Felder verfügbar sind — keine unsafe any-Casts nötig
  switch (data.type) {
    case 'mdt_open':
      store.open()
      break

    case 'mdt_close':
      store.isOpen = false  // Direkt ohne nuiPost — Lua hat bereits geschlossen
      break

    case 'mdt_data':
      // Kompletter Datensatz: alle Systeme mit Geräten und Logs
      store.loadData({ systems: data.systems })
      break

    case 'mdt_status_update':
      // Live-Update: z.B. System wechselt von 'normal' zu 'alarm'
      store.updateStatus(data.systemId, data.status)
      break

    case 'mdt_set_admin':
      store.isAdmin = data.isAdmin
      break
  }
}

/**
 * ESC-Taste schließt das MDT (sendet NUI-Callback an Lua).
 */
function onKeyDown(event: KeyboardEvent) {
  if (event.key === 'Escape' && store.isOpen) {
    store.close()
  }
}

// onMounted: Event-Listener hinzufügen sobald Vue die App ins DOM gemountet hat
onMounted(() => {
  window.addEventListener('message', onNuiMessage)
  window.addEventListener('keydown', onKeyDown)
})

// onUnmounted: Listener entfernen wenn App zerstört wird (Memory-Leak-Prävention)
onUnmounted(() => {
  window.removeEventListener('message', onNuiMessage)
  window.removeEventListener('keydown', onKeyDown)
})
</script>

<template>
  <!--
    v-if="store.isOpen": Rendert die gesamte MDT-Oberfläche NUR wenn isOpen=true.
    Vorteil: Im geschlossenen Zustand verbraucht die App kein DOM/CSS/JS.

    Transition: fade-in beim Öffnen für einen sauberen Einblend-Effekt.
  -->
  <Transition name="mdt-fade">
    <div v-if="store.isOpen" class="mdt-backdrop">
      <div class="mdt-screen">

        <!-- ═══════════════════════════════════════════════════════ -->
        <!-- TABLET HEADER — Logo, System-Status-Summary, Controls  -->
        <!-- ═══════════════════════════════════════════════════════ -->
        <header class="mdt-header">
          <div class="mdt-header__brand">
            <!-- SVG Feuerwehr-Shield Icon -->
            <svg class="mdt-header__icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M12 2L3 7V12C3 16.55 7.16 20.74 12 22C16.84 20.74 21 16.55 21 12V7L12 2Z" fill="currentColor" opacity="0.2"/>
              <path d="M12 2L3 7V12C3 16.55 7.16 20.74 12 22C16.84 20.74 21 16.55 21 12V7L12 2Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
              <path d="M9.5 14.5C9.5 13.12 10.62 12 12 12C10.62 12 9.5 10.88 9.5 9.5C9.5 10.88 8.38 12 7 12C8.38 12 9.5 13.12 9.5 14.5Z" fill="currentColor"/>
              <path d="M13 16C13 14.34 14.34 13 16 13C14.34 13 13 11.66 13 10C13 11.66 11.66 13 10 13C11.66 13 13 14.34 13 16Z" fill="currentColor"/>
            </svg>
            <div>
              <div class="mdt-header__title">BMA MANAGEMENT SYSTEM</div>
              <div class="mdt-header__subtitle">FEUERWEHR EINSATZ-TERMINAL v1.0</div>
            </div>
          </div>

          <!-- Status-Indikatoren -->
          <div class="mdt-header__status">
            <div v-if="store.activeAlarmCount > 0" class="mdt-status-badge mdt-status-badge--alarm pulse">
              <v-icon size="14">mdi-alarm-light</v-icon>
              {{ store.activeAlarmCount }} ALARM{{ store.activeAlarmCount > 1 ? 'E' : '' }}
            </div>
            <div v-if="store.troubleCount > 0" class="mdt-status-badge mdt-status-badge--trouble">
              <v-icon size="14">mdi-alert</v-icon>
              {{ store.troubleCount }} STÖRUNG{{ store.troubleCount > 1 ? 'EN' : '' }}
            </div>
            <div class="mdt-status-badge mdt-status-badge--online">
              <span class="mdt-dot mdt-dot--green"></span>
              ONLINE
            </div>
          </div>

          <!-- Schließen-Button -->
          <button class="mdt-close-btn" @click="store.close()">
            <v-icon>mdi-close</v-icon>
          </button>
        </header>

        <!-- ═══════════════════════════════════════════════════════ -->
        <!-- HAUPT-DASHBOARD — 3-Spalten-Grid                       -->
        <!-- ═══════════════════════════════════════════════════════ -->
        <main class="mdt-dashboard">

          <!-- SPALTE 1: Aktive Systeme -->
          <section class="mdt-col mdt-col--left">
            <SystemList />
          </section>

          <!-- SPALTE 2: Geräteübersicht + Wartungswarteschlange -->
          <section class="mdt-col mdt-col--center">
            <!-- System-Name Header (selektiertes System) -->
            <SystemDetail />
            <!-- Oberes Panel: Gerätekacheln + Mini-Grundriss -->
            <DeviceGrid />
            <!-- Unteres Panel: Geräte mit niedrigem Health -->
            <MaintenanceQueue />
          </section>

          <!-- SPALTE 3: Aktionen + Ereignisprotokoll -->
          <section class="mdt-col mdt-col--right">
            <ActionPanel />
            <AlarmLog />
          </section>

        </main>
      </div>
    </div>
  </Transition>
</template>

<style>
/* =====================================================
   Globale Styles — gelten für die gesamte App
   CSS-Variablen für konsistente Farben überall nutzen
   ===================================================== */

/* Google Fonts: Rajdhani für Labels, Share Tech Mono für IDs/Timestamps */
@import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;500;600;700&family=Share+Tech+Mono&display=swap');

/* CSS Reset für konsistentes Rendering */
*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

/* CSS Custom Properties — globale Design-Tokens */
:root {
  --bg-deep:      #07090c;
  --bg-base:      #0e1117;
  --bg-surface:   #161b22;
  --bg-surface-2: #1c2330;
  --border:       #21293a;
  --border-light: #2d3748;

  --color-primary: #f46d2f;
  --color-alarm:   #f85149;
  --color-trouble: #d29922;
  --color-normal:  #3fb950;
  --color-info:    #58a6ff;

  --text-primary:   #e6edf3;
  --text-secondary: #8b949e;
  --text-muted:     #484f58;

  --font-ui:   'Rajdhani', sans-serif;
  --font-mono: 'Share Tech Mono', monospace;
  --radius:    2px;

  /* Scan-line Overlay Frequenz */
  --scanline-size: 3px;
}

html, body {
  width: 100%;
  height: 100%;
  overflow: hidden;
  background: transparent !important;
}

#app {
  width: 100vw;
  height: 100vh;
  font-family: var(--font-ui);
  color: var(--text-primary);
}

/* Scrollbar-Styling für das dunkle Theme */
::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-track { background: var(--bg-deep); }
::-webkit-scrollbar-thumb { background: var(--border-light); border-radius: 2px; }
::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }

/* Vuetify Overrides — Schriften und Farben anpassen */
.v-application {
  background: transparent !important;
  font-family: var(--font-ui) !important;
}

.v-application__wrap {
  background: transparent !important;
  min-height: 0 !important;
}

.v-btn { font-family: var(--font-ui) !important; }
.v-list-item-title { font-family: var(--font-ui) !important; }

/* Panel-Header Stil (wird in mehreren Komponenten genutzt) */
.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 8px 12px;
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
}

.panel-header__title {
  font-family: var(--font-ui);
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--text-secondary);
}

/* Pulsierende Animation für aktive Alarme */
@keyframes pulse-ring {
  0%   { box-shadow: 0 0 0 0 rgba(248, 81, 73, 0.6); }
  70%  { box-shadow: 0 0 0 8px rgba(248, 81, 73, 0); }
  100% { box-shadow: 0 0 0 0 rgba(248, 81, 73, 0); }
}

@keyframes pulse-bg {
  0%, 100% { opacity: 1; }
  50%       { opacity: 0.7; }
}

.pulse { animation: pulse-ring 1.5s infinite; }

/* Status-Dot */
.mdt-dot {
  display: inline-block;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  margin-right: 5px;
}
.mdt-dot--green  { background: var(--color-normal); box-shadow: 0 0 4px var(--color-normal); }
.mdt-dot--red    { background: var(--color-alarm);  box-shadow: 0 0 4px var(--color-alarm);  }
.mdt-dot--yellow { background: var(--color-trouble);box-shadow: 0 0 4px var(--color-trouble);}

/* Health-Farben für progress bars */
.health-high   { color: var(--color-normal); }
.health-medium { color: var(--color-trouble); }
.health-low    { color: var(--color-alarm); }

/* Mono-Font für IDs und Timestamps */
.font-mono { font-family: var(--font-mono) !important; }
</style>

<style scoped>
/* =====================================================
   Scoped Styles — nur für App.vue
   "scoped" bedeutet: diese CSS-Klassen gelten NUR für
   Elemente in dieser Komponente, nicht für Kind-Komponenten.
   ===================================================== */

/* Halbtransparenter Backdrop hinter dem Tablet-Screen */
.mdt-backdrop {
  position: fixed;
  inset: 0;  /* top/right/bottom/left = 0 */
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.75);
  z-index: 9999;
}

/* Haupt-Container: Tablet-Rahmen */
.mdt-screen {
  position: relative;
  width: 1280px;
  height: 780px;
  max-width: 98vw;
  max-height: 96vh;
  background: var(--bg-base);
  border: 1px solid var(--border-light);
  border-radius: 6px;
  display: flex;
  flex-direction: column;
  overflow: hidden;

  /* Subtiler äußerer Glow — Tablet-Bildschirm-Effekt */
  box-shadow:
    0 0 0 1px var(--border),
    0 0 40px rgba(244, 109, 47, 0.08),
    0 20px 60px rgba(0, 0, 0, 0.8);
}

/* Scan-Line Overlay — taktischer CRT-Effekt */
.mdt-screen::before {
  content: '';
  position: absolute;
  inset: 0;
  background: repeating-linear-gradient(
    to bottom,
    transparent 0px,
    transparent calc(var(--scanline-size) - 1px),
    rgba(0, 0, 0, 0.06) calc(var(--scanline-size) - 1px),
    rgba(0, 0, 0, 0.06) var(--scanline-size)
  );
  pointer-events: none;
  z-index: 100;
}

/* ─── Header ────────────────────────────────────────── */
.mdt-header {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 10px 16px;
  background: var(--bg-deep);
  border-bottom: 2px solid var(--color-primary);
  flex-shrink: 0;
}

.mdt-header__brand {
  display: flex;
  align-items: center;
  gap: 12px;
  flex: 1;
}

.mdt-header__icon {
  width: 36px;
  height: 36px;
  color: var(--color-primary);
  flex-shrink: 0;
}

.mdt-header__title {
  font-size: 16px;
  font-weight: 700;
  letter-spacing: 0.12em;
  color: var(--text-primary);
  line-height: 1.2;
}

.mdt-header__subtitle {
  font-family: var(--font-mono);
  font-size: 10px;
  color: var(--text-muted);
  letter-spacing: 0.08em;
}

.mdt-header__status {
  display: flex;
  align-items: center;
  gap: 8px;
}

.mdt-status-badge {
  display: flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.1em;
  border-radius: 2px;
}

.mdt-status-badge--alarm {
  background: rgba(248, 81, 73, 0.15);
  border: 1px solid var(--color-alarm);
  color: var(--color-alarm);
}

.mdt-status-badge--trouble {
  background: rgba(210, 153, 34, 0.15);
  border: 1px solid var(--color-trouble);
  color: var(--color-trouble);
}

.mdt-status-badge--online {
  background: rgba(63, 185, 80, 0.1);
  border: 1px solid rgba(63, 185, 80, 0.3);
  color: var(--color-normal);
  font-size: 10px;
  letter-spacing: 0.15em;
}

.mdt-close-btn {
  background: rgba(248, 81, 73, 0.1);
  border: 1px solid rgba(248, 81, 73, 0.3);
  color: var(--color-alarm);
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-radius: 2px;
  transition: background 0.15s, border-color 0.15s;
  flex-shrink: 0;
}

.mdt-close-btn:hover {
  background: rgba(248, 81, 73, 0.25);
  border-color: var(--color-alarm);
}

/* ─── Dashboard Grid ────────────────────────────────── */
.mdt-dashboard {
  display: grid;
  /* 3 Spalten: Links schmaler (Systemliste), Mitte breit, Rechts mittel */
  grid-template-columns: 270px 1fr 260px;
  gap: 0;
  flex: 1;
  overflow: hidden;
  min-height: 0;  /* Wichtig: ohne das overflow:hidden in flex-items nicht wirkt */
}

.mdt-col {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 0;
}

.mdt-col--left {
  border-right: 1px solid var(--border);
}

.mdt-col--center {
  border-right: 1px solid var(--border);
  overflow-y: auto;
}

.mdt-col--right {
  /* Keine extra Borders nötig */
}

/* ─── Fade-Transition ──────────────────────────────── */
/* Vue Transition: mdt-fade-enter-active/leave-active definieren Dauer */
.mdt-fade-enter-active,
.mdt-fade-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.mdt-fade-enter-from,
.mdt-fade-leave-to {
  opacity: 0;
  transform: scale(0.98);
}
</style>
