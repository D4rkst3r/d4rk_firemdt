<script setup lang="ts">
/**
 * ActionPanel.vue — Rechtes oberes Panel: "Aktionen"
 *
 * 4 große Aktions-Buttons gemäß Mockup:
 *   QUITTIEREN  — Alarm stoppen (gelb, nur bei aktivem Alarm)
 *   RESET       — Status zurücksetzen (grün)
 *   PROBEALARM  — Test-Alarm (blau, nur für Admins)
 *   REPARATUR   — Wartungsdialog öffnen (orange)
 */

import { ref, computed } from 'vue'
import { useMdtStore } from '@/stores/mdt'
import { nuiPost } from '@/api/axios'

const store = useMdtStore()

// ─── Repair-Dialog ───────────────────────────────────────────
// ref<boolean> = reaktiver Boolean-Wert für v-model des v-dialog
const showRepairDialog = ref(false)
const repairLoading    = ref(false)

/**
 * Ist der QUITTIEREN-Button aktiv?
 * computed() reagiert auf Status-Änderungen via Live-Update aus d4rk_firealert.
 */
const canQuittieren = computed(() => store.selectedSystem?.status === 'alarm')

/**
 * Geräte die repariert werden könnten (health < 100) für den Dialog
 */
const repairableDevices = computed(() =>
  store.selectedSystem?.devices.filter(d => d.health < 100) ?? []
)

// ─── Action-Handler ──────────────────────────────────────────

/**
 * Alarm quittieren — delegiert an den Store.
 * Store führt optimistisches Update + NUI-Callback durch.
 */
async function handleQuittieren() {
  await store.quittieren()
}

/**
 * RESET: Setzt den Systemstatus auf 'normal' zurück.
 * Hinweis: Erfordert ggf. ein separates Server-Event in d4rk_firealert.
 * Hier: Gleicher Mechanismus wie Quittieren.
 */
async function handleReset() {
  await store.quittieren()
}

/**
 * PROBEALARM: Nur für Admins. Sendet NUI-Callback der Lua triggert.
 */
async function handleProbeAlarm() {
  if (!store.isAdmin || !store.selectedSystem) return
  await nuiPost('mdt_probe_alarm', { systemId: store.selectedSystem.id })
}

/**
 * Reparatur-Dialog öffnen.
 */
function handleRepair() {
  if (!store.selectedSystem) return
  showRepairDialog.value = true
}

/**
 * Reparatur eines Geräts beauftragen.
 * @param deviceId - ID des Geräts das repariert werden soll
 */
async function assignRepair(deviceId: number) {
  repairLoading.value = true
  await nuiPost('mdt_assign_repair', { deviceId })
  repairLoading.value = false
  showRepairDialog.value = false
}
</script>

<template>
  <!-- Panel-Header -->
  <div class="panel-header">
    <span class="panel-header__title">Aktionen</span>
  </div>

  <!-- Button-Grid: 4 große Buttons, volle Breite -->
  <div class="actions-grid">

    <!-- QUITTIEREN — Gelb, nur aktiv bei Alarm -->
    <!--
      variant="flat" in Vuetify = gefüllter Button ohne Elevation-Shadow.
      :disabled — verhindert Klick wenn kein Alarm.
      :class="{ 'btn--disabled': !canQuittieren }" — visuelles Dimming
    -->
    <v-btn
      :disabled="!canQuittieren"
      color="action-quittieren"
      variant="flat"
      class="action-btn"
      @click="handleQuittieren"
    >
      <div class="action-btn__content">
        <v-icon size="22">mdi-bell-cancel</v-icon>
        <span>QUITTIEREN</span>
      </div>
    </v-btn>

    <!-- RESET — Grün -->
    <v-btn
      color="action-reset"
      variant="flat"
      class="action-btn"
      @click="handleReset"
    >
      <div class="action-btn__content">
        <v-icon size="22">mdi-restore</v-icon>
        <span>RESET</span>
      </div>
    </v-btn>

    <!-- PROBEALARM — Blau, nur für Admins -->
    <!--
      v-show vs v-if:
      v-show="store.isAdmin" versteckt den Button via display:none — DOM-Element bleibt.
      v-if würde es komplett entfernen. v-show ist besser wenn der Button häufig
      ein-/ausgeblendet werden soll (kein DOM-Erzeugen/Zerstören).
    -->
    <v-btn
      v-show="store.isAdmin"
      color="action-probe"
      variant="flat"
      class="action-btn"
      :disabled="!store.selectedSystem"
      @click="handleProbeAlarm"
    >
      <div class="action-btn__content">
        <v-icon size="22">mdi-fire-alert</v-icon>
        <span>PROBEALARM</span>
      </div>
    </v-btn>

    <!-- REPARATUR ZUWEISEN — Orange (primary) -->
    <v-btn
      color="action-repair"
      variant="flat"
      class="action-btn"
      :disabled="!store.selectedSystem"
      @click="handleRepair"
    >
      <div class="action-btn__content">
        <v-icon size="22">mdi-wrench</v-icon>
        <span>REPARATUR ZUWEISEN</span>
      </div>
    </v-btn>

  </div>

  <!-- ─── Reparatur-Dialog ──────────────────────────── -->
  <!--
    v-dialog ist ein Vuetify-Modal.
    v-model="showRepairDialog" bindet die Sichtbarkeit an unsere ref().
    Wenn der Nutzer außerhalb klickt oder ESC drückt → showRepairDialog = false → Dialog schließt.
  -->
  <v-dialog v-model="showRepairDialog" max-width="420" class="repair-dialog-outer">
    <v-card class="repair-dialog">
      <div class="repair-dialog__header">
        <v-icon size="18" color="action-repair">mdi-wrench</v-icon>
        REPARATUR ZUWEISEN
        <v-spacer />
        <v-btn icon variant="text" size="small" @click="showRepairDialog = false">
          <v-icon size="16">mdi-close</v-icon>
        </v-btn>
      </div>

      <div class="repair-dialog__body">
        <div v-if="repairableDevices.length === 0" class="repair-dialog__empty">
          Alle Geräte vollständig in Ordnung.
        </div>

        <div
          v-for="device in repairableDevices"
          :key="device.id"
          class="repair-dialog__item"
          @click="assignRepair(device.id)"
        >
          <div class="repair-dialog__item-info">
            <span class="font-mono repair-dialog__item-id">#{{ device.id }}</span>
            <span class="repair-dialog__item-zone">{{ device.zone }}</span>
          </div>
          <div class="repair-dialog__item-health" :style="{ color: device.health < 30 ? 'var(--color-alarm)' : 'var(--color-trouble)' }">
            {{ device.health }}%
          </div>
          <v-btn
            size="x-small"
            color="action-repair"
            variant="flat"
            :loading="repairLoading"
          >
            BEAUFTRAGEN
          </v-btn>
        </div>
      </div>
    </v-card>
  </v-dialog>
</template>

<style scoped>
/* ─── Actions Grid ───────────────────────────────── */
.actions-grid {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px;
}

/* Großer Action-Button — volle Breite, fett, taktisch */
.action-btn {
  width: 100% !important;
  height: 46px !important;
  border-radius: 2px !important;
  font-family: var(--font-ui) !important;
  font-size: 13px !important;
  font-weight: 700 !important;
  letter-spacing: 0.12em !important;
}

.action-btn__content {
  display: flex;
  align-items: center;
  gap: 10px;
  width: 100%;
  justify-content: center;
}

/* ─── Repair Dialog ──────────────────────────────── */
.repair-dialog {
  background: var(--bg-surface) !important;
  border: 1px solid var(--border-light) !important;
  border-radius: 2px !important;
}

.repair-dialog__header {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px 16px;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.12em;
  color: var(--text-secondary);
  background: var(--bg-deep);
  border-bottom: 1px solid var(--border);
}

.repair-dialog__body {
  padding: 8px 0;
  max-height: 300px;
  overflow-y: auto;
}

.repair-dialog__empty {
  padding: 16px;
  text-align: center;
  color: var(--text-muted);
  font-size: 12px;
}

.repair-dialog__item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 8px 16px;
  border-bottom: 1px solid rgba(33, 41, 58, 0.5);
  cursor: pointer;
}
.repair-dialog__item:hover { background: rgba(255, 255, 255, 0.03); }

.repair-dialog__item-info {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 8px;
}

.repair-dialog__item-id {
  font-size: 11px;
  color: var(--text-muted);
}

.repair-dialog__item-zone {
  font-size: 13px;
  color: var(--text-primary);
}

.repair-dialog__item-health {
  font-family: var(--font-mono);
  font-size: 13px;
  font-weight: 700;
  flex-shrink: 0;
}
</style>
