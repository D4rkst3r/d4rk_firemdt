<script setup lang="ts">
/**
 * App.vue — Root-Komponente des MDT
 * Enthält: NUI-Message Bridge, ESC-Handler, 3-Spalten-Layout
 * + Tablet-Chassis (physisches Gehäuse mit Bezel, Schrauben, Seitenbuttons, LED)
 */
import { onMounted, onUnmounted } from 'vue'
import { useMdtStore } from '@/stores/mdt'
import type { NuiMessage } from '@/types'
import SystemList from '@/components/SystemList.vue'
import SystemDetail from '@/components/SystemDetail.vue'
import DeviceGrid from '@/components/DeviceGrid.vue'
import MaintenanceQueue from '@/components/MaintenanceQueue.vue'
import ActionPanel from '@/components/ActionPanel.vue'
import AlarmLog from '@/components/AlarmLog.vue'

const store = useMdtStore()

function onNuiMessage(event: MessageEvent<NuiMessage>) {
  const data = event.data
  switch (data.type) {
    case 'mdt_open':          store.open(); break
    case 'mdt_close':         store.isOpen = false; break
    case 'mdt_data':          store.loadData({ systems: data.systems }); break
    case 'mdt_status_update': store.updateStatus(data.systemId, data.status); break
    case 'mdt_health_update': store.updateHealth(data.deviceId, data.health); break
    case 'mdt_set_admin':     store.isAdmin = data.isAdmin; break
  }
}

function onKeyDown(event: KeyboardEvent) {
  if (event.key === 'Escape' && store.isOpen) store.close()
}

onMounted(() => {
  window.addEventListener('message', onNuiMessage)
  window.addEventListener('keydown', onKeyDown)
})
onUnmounted(() => {
  window.removeEventListener('message', onNuiMessage)
  window.removeEventListener('keydown', onKeyDown)
})
</script>

<template>
  <Transition name="mdt-fade">
    <div v-if="store.isOpen" class="mdt-backdrop">

      <!-- ═══════════════════════════════════════════════════════════════ -->
      <!-- TABLET CHASSIS — ruggedized Toughpad Gehäuse                   -->
      <!-- Struktur: .mdt-tablet > .mdt-bezel > .mdt-screen (UI-Inhalt)  -->
      <!-- ═══════════════════════════════════════════════════════════════ -->
      <div class="mdt-tablet">

        <!-- Torx-Schrauben in allen 4 Ecken -->
        <div class="mdt-screw mdt-screw--tl"><div class="mdt-screw__cross"></div></div>
        <div class="mdt-screw mdt-screw--tr"><div class="mdt-screw__cross"></div></div>
        <div class="mdt-screw mdt-screw--bl"><div class="mdt-screw__cross"></div></div>
        <div class="mdt-screw mdt-screw--br"><div class="mdt-screw__cross"></div></div>

        <!-- Linke Seitenleiste: Status-LED + Hardware-Buttons + Grip -->
        <div class="mdt-side mdt-side--left">
          <div class="mdt-led-housing">
            <div class="mdt-led"
              :class="{
                'mdt-led--green':  store.activeAlarmCount === 0 && store.troubleCount === 0,
                'mdt-led--yellow': store.troubleCount > 0 && store.activeAlarmCount === 0,
                'mdt-led--red':    store.activeAlarmCount > 0,
              }"
            ></div>
          </div>
          <div class="mdt-hw-btn"></div>
          <div class="mdt-hw-btn"></div>
          <div class="mdt-grip">
            <div v-for="n in 12" :key="n" class="mdt-grip__dot"></div>
          </div>
        </div>

        <!-- Rechte Seitenleiste: Buttons + Grip + USB-C Port -->
        <div class="mdt-side mdt-side--right">
          <div class="mdt-hw-btn mdt-hw-btn--tall"></div>
          <div class="mdt-hw-btn mdt-hw-btn--tall"></div>
          <div class="mdt-grip">
            <div v-for="n in 12" :key="n" class="mdt-grip__dot"></div>
          </div>
          <div class="mdt-port-usbc"></div>
        </div>

        <!-- Obere Leiste: Lüftungsschlitze + Kamera + Modellbezeichnung -->
        <div class="mdt-top-bar">
          <div class="mdt-vents">
            <div v-for="n in 10" :key="n" class="mdt-vent"></div>
          </div>
          <div class="mdt-camera-wrap">
            <div class="mdt-camera">
              <div class="mdt-camera__lens">
                <div class="mdt-camera__reflect"></div>
              </div>
            </div>
            <div class="mdt-camera__ir"></div>
          </div>
          <div class="mdt-top-label font-mono">D4RK-T900 · FD-EINSATZ-TERMINAL</div>
          <div class="mdt-vents">
            <div v-for="n in 10" :key="n" class="mdt-vent"></div>
          </div>
        </div>

        <!-- Untere Leiste: Ports + Seriennummer -->
        <div class="mdt-bottom-bar">
          <div class="mdt-ports-row">
            <div class="mdt-port mdt-port--usb">USB</div>
            <div class="mdt-port mdt-port--usbc">C</div>
            <div class="mdt-port mdt-port--hdmi">HDMI</div>
          </div>
          <div class="mdt-serial font-mono">
            SN: FD-9341-{{ store.systems.length > 0 ? 'BMA' : '---' }} · MFG 2026
          </div>
          <div class="mdt-ports-row">
            <div class="mdt-port mdt-port--audio">&#9898;</div>
            <div class="mdt-port mdt-port--sd">SD</div>
          </div>
        </div>

        <!-- Innerer Bezel — Einfassung des Bildschirms -->
        <div class="mdt-bezel">
          <div class="mdt-screen">

            <!-- Scan-Line CRT-Overlay -->
            <div class="mdt-scanlines" aria-hidden="true"></div>

            <!-- HEADER -->
            <header class="mdt-header">
              <div class="mdt-header__brand">
                <svg class="mdt-header__icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
                  <path d="M12 2L3 7V12C3 16.55 7.16 20.74 12 22C16.84 20.74 21 16.55 21 12V7L12 2Z" fill="currentColor" opacity="0.2"/>
                  <path d="M12 2L3 7V12C3 16.55 7.16 20.74 12 22C16.84 20.74 21 16.55 21 12V7L12 2Z" stroke="currentColor" stroke-width="1.5" stroke-linejoin="round"/>
                  <path d="M9.5 14.5C9.5 13.12 10.62 12 12 12C10.62 12 9.5 10.88 9.5 9.5C9.5 10.88 8.38 12 7 12C8.38 12 9.5 13.12 9.5 14.5Z" fill="currentColor"/>
                  <path d="M13 16C13 14.34 14.34 13 16 13C14.34 13 13 11.66 13 10C13 11.66 11.66 13 10 13C11.66 13 13 14.34 13 16Z" fill="currentColor"/>
                </svg>
                <div>
                  <div class="mdt-header__title">Fire Alarm System</div>
                  <div class="mdt-header__subtitle">FACP (Fire Alarm Control Panel)</div>
                </div>
              </div>
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
              <button class="mdt-close-btn" @click="store.close()">
                <v-icon>mdi-close</v-icon>
              </button>
            </header>

            <!-- DASHBOARD 3-Spalten -->
            <main class="mdt-dashboard">
              <section class="mdt-col mdt-col--left">
                <SystemList />
              </section>
              <section class="mdt-col mdt-col--center">
                <SystemDetail />
                <!-- Tab 0: Geraete + Wartung | Tab 1: Alarm-Log -->
                <template v-if="store.activeTab === 0">
                  <DeviceGrid />
                  <MaintenanceQueue />
                </template>
                <AlarmLog v-else-if="store.activeTab === 1" class="mdt-col--alarm-log" />
              </section>
              <section class="mdt-col mdt-col--right">
                <ActionPanel />
                <AlarmLog />  <!-- Ereignisprotokoll bleibt rechts -->
              </section>
            </main>

          </div><!-- /.mdt-screen -->
        </div><!-- /.mdt-bezel -->

      </div><!-- /.mdt-tablet -->
    </div><!-- /.mdt-backdrop -->
  </Transition>
</template>

<style>
/* ── Globale Styles ───────────────────────────────────────────── */
@import url('https://fonts.googleapis.com/css2?family=Rajdhani:wght@400;500;600;700&family=Share+Tech+Mono&display=swap');

*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

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

  --chassis:       #1a1f2e;
  --chassis-light: #232a3a;
  --chassis-dark:  #0d1018;
  --chassis-edge:  #2a3347;
  --rubber:        #0e1118;
}

html, body { width: 100%; height: 100%; overflow: hidden; background: transparent !important; }
#app {
  background: transparent !important; width: 100vw; height: 100vh; font-family: var(--font-ui); color: var(--text-primary); }

::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-track { background: var(--bg-deep); }
::-webkit-scrollbar-thumb { background: var(--border-light); border-radius: 2px; }

.v-application { background: transparent !important; font-family: var(--font-ui) !important; }
.v-application__wrap { background: transparent !important; min-height: 0 !important; }
.v-layout { background: transparent !important; }
.v-application__wrap { background: transparent !important; min-height: 0 !important; }
.v-btn { font-family: var(--font-ui) !important; }
.v-list-item-title { font-family: var(--font-ui) !important; }

.panel-header {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 12px; background: var(--bg-deep); border-bottom: 1px solid var(--border);
}
.panel-header__title {
  font-family: var(--font-ui); font-size: 11px; font-weight: 600;
  letter-spacing: 0.15em; text-transform: uppercase; color: var(--text-secondary);
}

@keyframes pulse-ring {
  0%   { box-shadow: 0 0 0 0 rgba(248,81,73,.6); }
  70%  { box-shadow: 0 0 0 8px rgba(248,81,73,0); }
  100% { box-shadow: 0 0 0 0 rgba(248,81,73,0); }
}
@keyframes led-blink {
  0%,100% { opacity: 1; }
  50%     { opacity: 0.25; }
}

.pulse { animation: pulse-ring 1.5s infinite; }

.mdt-dot { display: inline-block; width: 6px; height: 6px; border-radius: 50%; margin-right: 5px; }
.mdt-dot--green  { background: var(--color-normal); box-shadow: 0 0 4px var(--color-normal); }
.mdt-dot--red    { background: var(--color-alarm);  box-shadow: 0 0 4px var(--color-alarm); }
.mdt-dot--yellow { background: var(--color-trouble); box-shadow: 0 0 4px var(--color-trouble); }

.health-high   { color: var(--color-normal); }
.health-medium { color: var(--color-trouble); }
.health-low    { color: var(--color-alarm); }
.font-mono     { font-family: var(--font-mono) !important; }
.text-alarm    { color: var(--color-alarm); }
.text-trouble  { color: var(--color-trouble); }
.text-normal   { color: var(--color-normal); }
</style>

<style scoped>
/* ── Backdrop ────────────────────────────────────────────────── */
.mdt-backdrop {
  position: fixed; inset: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(0,0,0,0.72);
  z-index: 9999;
}

/* ════════════════════════════════════════════════════════════════
   TABLET CHASSIS
   Größe: Screen (1260×760) + Bezel (6px padding) + Chassis-Rand (22px)
   ════════════════════════════════════════════════════════════════ */
.mdt-tablet {
  position: relative;
  width:  1324px;
  height: 832px;
  max-width: 99vw;
  max-height: 98vh;

  background: linear-gradient(155deg,
    var(--chassis-light) 0%,
    var(--chassis)       45%,
    var(--chassis-dark)  100%
  );
  border-radius: 14px;
  border: 1.5px solid var(--chassis-edge);
  outline: 2px solid rgba(0,0,0,0.7);

  box-shadow:
    inset 0 1px 0 rgba(255,255,255,0.07),
    inset 0 -1px 0 rgba(0,0,0,0.5),
    inset 1px 0 0 rgba(255,255,255,0.03),
    0 40px 100px rgba(0,0,0,0.9),
    0 10px 40px rgba(0,0,0,0.6),
    0 0 80px rgba(244,109,47,0.04);
}

/* ── Schrauben ──────────────────────────────────────────────── */
.mdt-screw {
  position: absolute;
  width: 13px; height: 13px;
  border-radius: 50%;
  background: radial-gradient(circle at 35% 30%, #3a4255, #14181f);
  border: 1.5px solid #111620;
  box-shadow: inset 0 1px 3px rgba(0,0,0,.9), 0 1px 0 rgba(255,255,255,.04);
  z-index: 10;
}
.mdt-screw--tl { top: 11px; left: 11px; }
.mdt-screw--tr { top: 11px; right: 11px; }
.mdt-screw--bl { bottom: 11px; left: 11px; }
.mdt-screw--br { bottom: 11px; right: 11px; }
.mdt-screw__cross {
  position: absolute; inset: 2px;
  background:
    linear-gradient(#0a0d14, #0a0d14) center / 1.5px 70% no-repeat,
    linear-gradient(#0a0d14, #0a0d14) center / 70% 1.5px no-repeat;
  opacity: .8;
}

/* ── Seitenleisten ──────────────────────────────────────────── */
.mdt-side {
  position: absolute;
  top: 32px; bottom: 32px; width: 20px;
  display: flex; flex-direction: column; align-items: center;
  gap: 8px; padding: 14px 0;
}
.mdt-side--left  { left: 4px; }
.mdt-side--right { right: 4px; }

.mdt-led-housing {
  width: 13px; height: 13px; border-radius: 50%;
  background: var(--chassis-dark); border: 1px solid #080b10;
  display: flex; align-items: center; justify-content: center;
  box-shadow: inset 0 1px 4px rgba(0,0,0,1);
}
.mdt-led {
  width: 7px; height: 7px; border-radius: 50%;
  transition: background .3s, box-shadow .3s;
}
.mdt-led--green  { background: var(--color-normal); box-shadow: 0 0 5px var(--color-normal), 0 0 10px rgba(63,185,80,.35); }
.mdt-led--yellow { background: var(--color-trouble); box-shadow: 0 0 5px var(--color-trouble), 0 0 10px rgba(210,153,34,.35); }
.mdt-led--red    { background: var(--color-alarm); box-shadow: 0 0 5px var(--color-alarm), 0 0 10px rgba(248,81,73,.5); animation: led-blink .8s infinite; }

.mdt-hw-btn {
  width: 13px; height: 22px;
  background: linear-gradient(180deg, #252d3e 0%, #161c28 100%);
  border-radius: 3px;
  border: 1px solid #0c1018;
  box-shadow: inset 0 1px 0 rgba(255,255,255,.05), 0 2px 5px rgba(0,0,0,.6);
}
.mdt-hw-btn--tall { height: 32px; }

.mdt-grip { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; }
.mdt-grip__dot {
  width: 5px; height: 5px; border-radius: 50%;
  background: var(--rubber);
  border: 1px solid #080b10;
  box-shadow: inset 0 1px 2px rgba(0,0,0,.9);
}

.mdt-port-usbc {
  width: 9px; height: 5px; border-radius: 3px;
  background: var(--chassis-dark); border: 1px solid #080b10;
  box-shadow: inset 0 1px 3px rgba(0,0,0,.9);
}

/* ── Obere Leiste ───────────────────────────────────────────── */
.mdt-top-bar {
  position: absolute; top: 5px; left: 28px; right: 28px; height: 20px;
  display: flex; align-items: center; justify-content: space-between; gap: 10px;
}
.mdt-vents { display: flex; gap: 3px; align-items: center; }
.mdt-vent {
  width: 9px; height: 3px;
  background: var(--chassis-dark); border-radius: 1px;
  border: 1px solid #080b10;
  box-shadow: inset 0 1px 2px rgba(0,0,0,.9);
}

.mdt-camera-wrap { display: flex; align-items: center; gap: 4px; }
.mdt-camera {
  width: 14px; height: 14px; border-radius: 50%;
  background: radial-gradient(circle at 35% 30%, #1c2230, #030508);
  border: 1px solid #080b10;
  box-shadow: inset 0 1px 4px rgba(0,0,0,1), 0 0 0 1px rgba(255,255,255,.02);
  display: flex; align-items: center; justify-content: center;
}
.mdt-camera__lens {
  width: 8px; height: 8px; border-radius: 50%;
  background: radial-gradient(circle at 35% 28%, #1a3a5c, #020408);
  border: 1px solid #0d1520; position: relative;
}
.mdt-camera__reflect {
  position: absolute; top: 1px; left: 1px;
  width: 3px; height: 2px;
  background: rgba(88,166,255,.22); border-radius: 50%;
}
.mdt-camera__ir {
  width: 5px; height: 5px; border-radius: 50%;
  background: #100814; border: 1px solid #080b10;
}
.mdt-top-label {
  font-size: 8px; color: var(--text-muted);
  letter-spacing: .12em; white-space: nowrap; opacity: .55;
}

/* ── Untere Leiste ──────────────────────────────────────────── */
.mdt-bottom-bar {
  position: absolute; bottom: 5px; left: 28px; right: 28px; height: 20px;
  display: flex; align-items: center; justify-content: space-between;
}
.mdt-ports-row { display: flex; gap: 4px; align-items: center; }
.mdt-port {
  height: 10px; background: var(--chassis-dark);
  border: 1px solid #080b10;
  box-shadow: inset 0 1px 3px rgba(0,0,0,.9);
  display: flex; align-items: center; justify-content: center;
  font-family: var(--font-mono); font-size: 5px; color: var(--text-muted);
  letter-spacing: .04em; border-radius: 1px;
}
.mdt-port--usb  { width: 16px; }
.mdt-port--usbc { width: 10px; border-radius: 3px; }
.mdt-port--hdmi { width: 20px; }
.mdt-port--audio{ width: 8px; border-radius: 50%; font-size: 7px; }
.mdt-port--sd   { width: 14px; }

.mdt-serial {
  font-size: 8px; color: var(--text-muted);
  letter-spacing: .1em; opacity: .45;
}

/* ── Innerer Bezel ──────────────────────────────────────────── */
.mdt-bezel {
  position: absolute;
  top: 27px; bottom: 27px; left: 26px; right: 26px;
  background: #07090d;
  border-radius: 4px;
  border: 1px solid #0b0e14;
  padding: 6px;
  box-shadow:
    inset 0 2px 10px rgba(0,0,0,1),
    inset 0 -1px 6px rgba(0,0,0,.6),
    inset 2px 0 8px rgba(0,0,0,.7),
    inset -2px 0 8px rgba(0,0,0,.7);
}

/* ── Screen ─────────────────────────────────────────────────── */
.mdt-screen {
  position: relative;
  width: 100%; height: 100%;
  background: var(--bg-base);
  border-radius: 2px;
  display: flex; flex-direction: column;
  overflow: hidden;
  box-shadow: 0 0 30px rgba(244,109,47,.05), inset 0 0 80px rgba(0,0,0,.2);
}

.mdt-scanlines {
  position: absolute; inset: 0; pointer-events: none; z-index: 100; border-radius: 2px;
  background: repeating-linear-gradient(
    to bottom, transparent 0px, transparent 2px,
    rgba(0,0,0,.04) 2px, rgba(0,0,0,.04) 3px
  );
}

/* ── Header ─────────────────────────────────────────────────── */
.mdt-header {
  display: flex; align-items: center; gap: 16px;
  padding: 10px 16px;
  background: var(--bg-deep);
  border-bottom: 2px solid var(--color-primary);
  flex-shrink: 0;
}
.mdt-header__brand { display: flex; align-items: center; gap: 12px; flex: 1; }
.mdt-header__icon  { width: 36px; height: 36px; color: var(--color-primary); flex-shrink: 0; }
.mdt-header__title { font-size: 16px; font-weight: 700; letter-spacing: .12em; color: var(--text-primary); line-height: 1.2; }
.mdt-header__subtitle { font-family: var(--font-mono); font-size: 10px; color: var(--text-muted); letter-spacing: .08em; }
.mdt-header__status { display: flex; align-items: center; gap: 8px; }

.mdt-status-badge {
  display: flex; align-items: center; gap: 5px;
  padding: 4px 10px; font-size: 11px; font-weight: 700;
  letter-spacing: .1em; border-radius: 2px;
}
.mdt-status-badge--alarm   { background: rgba(248,81,73,.15);  border: 1px solid var(--color-alarm);  color: var(--color-alarm); }
.mdt-status-badge--trouble { background: rgba(210,153,34,.15); border: 1px solid var(--color-trouble); color: var(--color-trouble); }
.mdt-status-badge--online  { background: rgba(63,185,80,.1);   border: 1px solid rgba(63,185,80,.3);  color: var(--color-normal); font-size: 10px; letter-spacing: .15em; }

.mdt-close-btn {
  background: rgba(248,81,73,.1); border: 1px solid rgba(248,81,73,.3);
  color: var(--color-alarm); width: 32px; height: 32px;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer; border-radius: 2px;
  transition: background .15s, border-color .15s; flex-shrink: 0;
}
.mdt-close-btn:hover { background: rgba(248,81,73,.25); border-color: var(--color-alarm); }

/* ── Dashboard ──────────────────────────────────────────────── */
.mdt-dashboard {
  display: grid; grid-template-columns: 270px 1fr 260px;
  flex: 1; overflow: hidden; min-height: 0;
}
.mdt-col { display: flex; flex-direction: column; overflow: hidden; min-height: 0; }
.mdt-col--left   { border-right: 1px solid var(--border); }
.mdt-col--center { border-right: 1px solid var(--border); overflow-y: auto; }

/* ── Transition ─────────────────────────────────────────────── */
.mdt-fade-enter-active, .mdt-fade-leave-active {
  transition: opacity .2s ease, transform .2s ease;
}
.mdt-fade-enter-from, .mdt-fade-leave-to {
  opacity: 0; transform: scale(.97) translateY(8px);
}
</style>