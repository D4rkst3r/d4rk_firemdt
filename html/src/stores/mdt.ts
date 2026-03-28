// src/stores/mdt.ts
// Pinia Store — das "Gehirn" des MDT.
//
// Was ist ein Pinia Store?
// Ein Store ist ein globaler reaktiver Zustandsspeicher.
// Alle Komponenten die diesen Store nutzen sehen DIESELBEN Daten
// und werden automatisch aktualisiert wenn sich der Zustand ändert.
//
// Pinia unterscheidet drei Konzepte:
//   STATE    = die Rohdaten (ref() / reactive())
//   GETTERS  = berechnete Ableitungen (computed()) — wie State, aber automatisch aktualisiert
//   ACTIONS  = Funktionen die den State verändern können
//
// "Setup Store"-Syntax (vs Options Store):
// Wir nutzen die Setup-Funktion (wie in Vue 3 Composables) statt dem Options-Objekt.
// Vorteil: TypeScript-Inferenz funktioniert besser, Code-Style konsistenter mit Vue 3.

import { defineStore } from 'pinia'
// ref() = reaktive Referenz auf einen Wert → Änderungen triggern UI-Updates
// computed() = abgeleiteter Wert der sich automatisch neu berechnet
// watch() = Seiteneffekte bei State-Änderungen
import { ref, computed } from 'vue'
import { nuiPost } from '@/api/axios'
import type { BMASystem, SystemStatus, Device } from '@/types'

// defineStore(id, setupFn):
//   id = eindeutiger Name des Stores (wichtig für DevTools)
//   setupFn = Funktion die State, Getters und Actions zurückgibt
export const useMdtStore = defineStore('mdt', () => {
  // =====================================================
  // STATE — die Rohdaten
  // ref<T>() = reaktive Variable des Typs T
  // Änderungen via .value = ... triggern automatisch UI-Re-Renders
  // =====================================================

  /** Alle BMA-Systeme mit Geräten und Logs */
  const systems = ref<BMASystem[]>([])

  /** ID des aktuell im MDT ausgewählten Systems (linke Liste) */
  const selectedSystemId = ref<number | null>(null)

  /** Ist das MDT-Fenster gerade sichtbar? */
  const isOpen = ref(false)

  /**
   * Hat der Spieler Admin-Rechte?
   * Wird vom Server mitgeliefert und steuert ob der PROBEALARM-Button sichtbar ist.
   * Für MVP: false (Admin-Check kann später ergänzt werden)
   */
  const isAdmin = ref(false)

  /** Läuft gerade ein Refresh? → Spinner anzeigen */
  const isLoading = ref(false)

  // =====================================================
  // GETTERS — berechnete Ableitungen (computed)
  //
  // computed() unterscheidet sich von einer normalen Funktion durch:
  //   - Caching: Ergebnis wird gespeichert und nur neu berechnet
  //     wenn sich eine abhängige ref() ändert
  //   - Reaktivität: Template-Teile die computed-Werte nutzen
  //     werden automatisch neu gerendert
  // =====================================================

  /**
   * Das aktuell ausgewählte System-Objekt (oder null wenn keins ausgewählt).
   * Automatisch aktualisiert wenn selectedSystemId oder systems sich ändern.
   */
  const selectedSystem = computed<BMASystem | null>(() =>
    systems.value.find(s => s.id === selectedSystemId.value) ?? null
  )

  /**
   * Systeme sortiert nach Priorität: alarm → trouble → normal, dann alphabetisch.
   * [...systems.value] = shallow copy damit sort() das Original nicht mutiert.
   */
  const sortedSystems = computed<BMASystem[]>(() => {
    // Numerische Priorität für stabiles Sortieren
    const priority: Record<SystemStatus, number> = { alarm: 0, trouble: 1, normal: 2 }
    return [...systems.value].sort((a, b) => {
      const diff = priority[a.status] - priority[b.status]
      // Bei gleicher Priorität alphabetisch nach Name
      return diff !== 0 ? diff : a.name.localeCompare(b.name, 'de')
    })
  })

  /**
   * Geräte des ausgewählten Systems mit Health < 50%, aufsteigend sortiert.
   * Diese werden in der Wartungswarteschlange angezeigt.
   */
  const maintenanceQueue = computed<Device[]>(() => {
    if (!selectedSystem.value) return []
    return [...selectedSystem.value.devices]
      .filter(d => d.health < 50)
      .sort((a, b) => a.health - b.health)  // Schlechteste zuerst
  })

  /**
   * Gesamtanzahl aktiver Alarme — für den Tablet-Header-Badge
   */
  const activeAlarmCount = computed<number>(() =>
    systems.value.filter(s => s.status === 'alarm').length
  )

  /**
   * Anzahl Systeme mit Störung
   */
  const troubleCount = computed<number>(() =>
    systems.value.filter(s => s.status === 'trouble').length
  )

  // =====================================================
  // ACTIONS — Funktionen die den State verändern
  //
  // Actions sind normale Funktionen (sync oder async).
  // Sie dürfen State direkt via .value = ... mutieren.
  // Pinia macht das reaktiv — keine Mutations wie in Vuex nötig.
  // =====================================================

  /**
   * Lädt den kompletten Datensatz vom Server (beim Öffnen / Refresh).
   * @param payload.systems - Array aller BMA-Systeme
   * @param payload.isAdmin - Optional: ob Spieler Admin-Rechte hat
   */
  function loadData(payload: { systems: BMASystem[]; isAdmin?: boolean }) {
    systems.value = payload.systems

    if (payload.isAdmin !== undefined) {
      isAdmin.value = payload.isAdmin
    }

    // Beim ersten Laden das erste System automatisch auswählen (oder alarm-System)
    if (systems.value.length > 0) {
      const alarmSystem = systems.value.find(s => s.status === 'alarm')
      if (!selectedSystemId.value || !systems.value.find(s => s.id === selectedSystemId.value)) {
        // Wenn ein Alarm aktiv ist → dieses System zuerst zeigen
        selectedSystemId.value = alarmSystem?.id ?? systems.value[0].id
      }
    }

    isLoading.value = false
  }

  /**
   * Live-Update: Status eines Systems hat sich geändert.
   * Wird von d4rk_firealert:client:updateSystemStatus → c_main.lua → NUI-Message getriggert.
   * @param systemId - ID des betroffenen Systems
   * @param status - Neuer Status
   */
  function updateStatus(systemId: number, status: SystemStatus) {
    const system = systems.value.find(s => s.id === systemId)
    if (system) {
      system.status = status
    }
    // Hinweis: Da system ein Objekt innerhalb des ref()-Arrays ist,
    // erkennt Vue die Mutation direkt — kein .value-Reassignment nötig.
  }

  /**
   * Live-Update: Health eines einzelnen Geräts.
   * Sucht durch alle Systeme nach dem Gerät mit der passenden ID.
   * @param deviceId - ID des Geräts
   * @param health - Neue Health (0–100)
   */
  function updateHealth(deviceId: number, health: number) {
    // O(n*m) Suche — bei typischer Servergröße (<100 Geräte) kein Problem
    for (const system of systems.value) {
      const device = system.devices.find(d => d.id === deviceId)
      if (device) {
        device.health = health
        break  // Gefunden, Schleife beenden
      }
    }
  }

  /**
   * Setzt das aktuell ausgewählte System (linke Liste → mittlere/rechte Panels).
   * @param id - System-ID oder null zum Abwählen
   */
  function selectSystem(id: number) {
    selectedSystemId.value = id
  }

  /**
   * Alarm quittieren — optimistisches Update + NUI-Callback an Lua.
   * "Optimistisch" bedeutet: UI wird sofort aktualisiert bevor der Server antwortet.
   * Wenn der Server Fehler meldet (z.B. kein Job), korrigiert das nächste updateStatus den Zustand.
   */
  async function quittieren() {
    const system = selectedSystem.value
    if (!system || system.status !== 'alarm') return

    // Optimistisches Update: sofort in der UI auf 'normal' setzen
    system.status = 'normal'

    // NUI-Callback senden → c_main.lua → TriggerServerEvent('quittieren')
    // nuiPost ist in api/axios.ts definiert
    await nuiPost('mdt_quittieren', { systemId: system.id })
  }

  /**
   * Refresh-Request an Lua senden (Daten neu laden).
   * isLoading setzt den Spinner in der UI.
   */
  async function refresh() {
    isLoading.value = true
    await nuiPost('mdt_refresh')
  }

  /** MDT öffnen (wird von NUI-Message 'mdt_open' aufgerufen) */
  function open() {
    isOpen.value = true
  }

  /** MDT schließen (ESC oder Schließen-Button → NUI-Callback 'mdt_close') */
  async function close() {
    isOpen.value = false
    await nuiPost('mdt_close')
  }

  // =====================================================
  // Exportierte API des Stores
  // Alle Werte und Funktionen die Komponenten nutzen dürfen
  // =====================================================
  return {
    // State
    systems,
    selectedSystemId,
    isOpen,
    isAdmin,
    isLoading,
    // Getters
    selectedSystem,
    sortedSystems,
    maintenanceQueue,
    activeAlarmCount,
    troubleCount,
    // Actions
    loadData,
    updateStatus,
    updateHealth,
    selectSystem,
    quittieren,
    refresh,
    open,
    close,
  }
})
