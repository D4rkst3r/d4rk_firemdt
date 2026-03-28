// src/types/index.ts
// Zentrale Typ-Definitionen für das gesamte MDT.
// TypeScript-Interfaces beschreiben die "Form" der Daten die vom Server kommen.
// Durch zentrale Definition an einem Ort können alle Komponenten denselben Typ importieren —
// Änderungen am Datenformat müssen nur hier angepasst werden.

// -------------------------------------------------------
// Status-Typen (Union Types)
// Union Type = "genau einer dieser String-Werte"
// Vorteil: TypeScript warnt wenn z.B. 'Alarm' statt 'alarm' verwendet wird.
// -------------------------------------------------------

/** Status eines BMA-Systems */
export type SystemStatus = 'normal' | 'alarm' | 'trouble'

/** Auslösertyp eines Alarms */
export type TriggerType = 'manual' | 'automatic' | 'test'

/** Gerätetyp — entspricht Config.Devices in d4rk_firealert */
export type DeviceType = 'panel' | 'smoke' | 'pull' | 'siren'

// -------------------------------------------------------
// Haupt-Interfaces
// Interface = Beschreibt die Struktur eines Objekts.
// Optional-Felder mit '?' markieren (z.B. acknowledged_by kann null sein).
// -------------------------------------------------------

/**
 * Einzelnes BMA-Gerät (Melder, Sirene, Panel).
 * Kommt aus fire_devices JOIN fire_systems im Server-Event.
 */
export interface Device {
  /** Primärschlüssel aus fire_devices */
  id: number
  /** Gerätetyp — bestimmt Icon und Label in der UI */
  type: DeviceType
  /** Raumbezeichnung z.B. "Küche EG" */
  zone: string
  /** Aktuelle Haltbarkeit 0–100 */
  health: number
  /** Letzter Servicezeitpunkt als ISO-String */
  last_service: string
}

/**
 * Einzelner Alarm-Log-Eintrag aus fire_alarm_log.
 * Wird im Ereignisprotokoll und im Alarm-Log-Tab angezeigt.
 */
export interface AlarmLogEntry {
  id: number
  zone: string
  trigger_type: TriggerType
  /** ISO-Timestamp — wird in formatTimestamp() umgewandelt */
  triggered_at: string
  /** null = noch nicht quittiert */
  acknowledged_by: string | null
  acknowledged_at: string | null
}

/**
 * Vollständiges BMA-System mit allen Geräten und Logs.
 * Dies ist die Hauptdatenstruktur die der Server bei mdt:getData sendet.
 */
export interface BMASystem {
  id: number
  name: string
  status: SystemStatus
  /** Alle Geräte die zu diesem System gehören */
  devices: Device[]
  /** Letzte 10 Alarm-Einträge (bereits auf Server gefiltert) */
  logs: AlarmLogEntry[]
}

// -------------------------------------------------------
// NUI-Message-Typen
// Diese beschreiben die JSON-Objekte die über SendNUIMessage() von Lua kommen
// und in App.vue per window.addEventListener('message') empfangen werden.
// -------------------------------------------------------

/** NUI öffnen-Signal */
export interface NuiMessageOpen {
  type: 'mdt_open'
}

/** NUI schließen-Signal */
export interface NuiMessageClose {
  type: 'mdt_close'
}

/** Kompletter Datensatz (beim Öffnen oder Refresh) */
export interface NuiMessageData {
  type: 'mdt_data'
  systems: BMASystem[]
}

/** Live-Update: System-Status hat sich geändert */
export interface NuiMessageStatusUpdate {
  type: 'mdt_status_update'
  systemId: number
  status: SystemStatus
}

/** Live-Update: Gerät-Health hat sich geändert */
export interface NuiMessageHealthUpdate {
  type: 'mdt_health_update'
  deviceId: number
  health: number
}

/** Admin-Status setzen */
export interface NuiMessageSetAdmin {
  type: 'mdt_set_admin'
  isAdmin: boolean
}

/** Discriminated Union aller möglichen NUI-Message-Typen */
export type NuiMessage =
  | NuiMessageOpen
  | NuiMessageClose
  | NuiMessageData
  | NuiMessageStatusUpdate
  | NuiMessageHealthUpdate
  | NuiMessageSetAdmin
