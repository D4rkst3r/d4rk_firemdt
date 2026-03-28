# d4rk_firemdt 🚒

Taktisches Feuerwehr-MDT Tablet für FiveM — eigenständige Resource die auf `d4rk_firealert` aufbaut.

**Tech-Stack:** Vue 3 · TypeScript · Pinia · Vuetify 3 · Vite

---

## Features

- **3-Spalten Dashboard** — Systemliste / Geräteübersicht / Aktionen & Log
- **Live-Updates** — Status- und Health-Änderungen werden ohne Refresh angezeigt
- **Alarm-Quittierung** direkt aus dem MDT
- **Wartungswarteschlange** — Geräte mit Health < 50% sortiert nach Priorität
- **Ereignisprotokoll** — Timeline der letzten Alarme mit Quittierungs-Status
- **Mini-Grundriss** — SVG-Heatmap mit farbigen Dots je Gerät-Health
- **Admin-Modus** — PROBEALARM-Button für `group.admin`
- **Dark Industrial UI** — Fonts: Rajdhani + Share Tech Mono

---

## Abhängigkeiten

| Resource | Pflicht |
|---|---|
| `d4rk_firealert` | ✅ Ja — liefert alle Daten + Events |
| `ox_lib` | ✅ Ja — Notifications, Lua-Helpers |
| `ox_target` | Optional — für prop_computer_02 Interaktion |
| `oxmysql` | ✅ Ja — Direkt-DB-Zugriff in s_main.lua |
| `qb-core` oder `qbx_core` | ✅ Ja — Job-Check |

---

## Installation

### 1. Resource kopieren
```
resources/
  [einsatz]/
    d4rk_firealert/    ← muss bereits laufen
    d4rk_firemdt/      ← diese Resource
```

### 2. Vue-App bauen
```bash
cd d4rk_firemdt/html
npm install
npm run build
```
→ Erzeugt `html/dist/` das von FiveM als NUI ausgeliefert wird.

### 3. server.cfg
```cfg
ensure d4rk_firealert
ensure d4rk_firemdt

# Feuerwehr darf MDT öffnen
add_ace group.firefighter command.firemdt allow

# Admins dürfen Probealarm via MDT auslösen
add_ace group.admin command.firemdt allow
```

---

## Befehle

| Befehl | Beschreibung | Berechtigung |
|---|---|---|
| `/firemdt` | MDT öffnen / schließen | Job: firefighter |

---

## Kommunikations-Flow

```
Spieler drückt /firemdt
       │
       ▼
c_main.lua — Job-Check → OpenMDT()
       │
       ├─ SetNuiFocus(true, true)
       ├─ SendNUIMessage({ type: 'mdt_open' })
       └─ TriggerServerEvent('mdt:getData')
                 │
                 ▼
         s_main.lua — MySQL-Abfragen
                 │
                 └─ TriggerClientEvent('mdt:open', src, data)
                           │
                           ▼
                   c_main.lua empfängt
                           │
                           └─ SendNUIMessage({ type: 'mdt_data', systems })
                                     │
                                     ▼
                             App.vue — onNuiMessage()
                                     │
                                     └─ store.loadData(payload)
                                               │
                                               ▼
                                      UI reaktiv aktualisiert

── Live-Updates (d4rk_firealert sendet) ──────────────────────────
d4rk_firealert:client:updateSystemStatus  ──► c_main.lua ──► NUI ──► store.updateStatus()
d4rk_firealert:client:updateDeviceHealth  ──► c_main.lua ──► NUI ──► store.updateHealth()
```

---

## Entwicklung (Browser)

```bash
cd html
npm run dev
```
Die App läuft dann im Browser unter `http://localhost:5173`.
Im Dev-Modus gibt es keine echten FiveM-Daten — NUI-Callbacks schlagen still fehl (axios interceptor).

**Test-Daten in der Browser-Console einspielen:**
```javascript
// MDT öffnen
window.postMessage({ type: 'mdt_open' }, '*')

// Test-Systeme laden
window.postMessage({
  type: 'mdt_data',
  systems: [
    {
      id: 101, name: 'Polizeistation', status: 'normal',
      devices: [
        { id: 1, type: 'smoke', zone: 'EG Lobby',   health: 95, last_service: new Date().toISOString() },
        { id: 2, type: 'pull',  zone: 'EG Eingang', health: 42, last_service: new Date().toISOString() },
        { id: 3, type: 'siren', zone: 'Dach',       health: 80, last_service: new Date().toISOString() },
      ],
      logs: []
    },
    {
      id: 102, name: 'Lagerhalle', status: 'alarm',
      devices: [
        { id: 4, type: 'smoke', zone: 'Lager EG', health: 100, last_service: new Date().toISOString() },
      ],
      logs: [
        { id: 1, zone: 'Lager EG', trigger_type: 'automatic', triggered_at: new Date().toISOString(), acknowledged_by: null, acknowledged_at: null }
      ]
    }
  ]
}, '*')

// Live-Update simulieren
window.postMessage({ type: 'mdt_status_update', systemId: 101, status: 'trouble' }, '*')
window.postMessage({ type: 'mdt_health_update', deviceId: 1, health: 15 }, '*')
```

---

## Dateistruktur

```
d4rk_firemdt/
├── fxmanifest.lua          FiveM Resource Manifest
├── c_main.lua              Client Lua (NUI-Bridge, Commands, Events)
├── s_main.lua              Server Lua (mdt:getData, probeAlarm, assignRepair)
└── html/
    ├── index.html          NUI Einstiegspunkt
    ├── package.json        NPM Abhängigkeiten
    ├── vite.config.ts      Build-Konfiguration
    ├── tsconfig.json       TypeScript-Konfiguration
    └── src/
        ├── main.ts                    Vue App Einstiegspunkt
        ├── App.vue                    Root-Komponente + NUI-Message-Bridge
        ├── types/
        │   └── index.ts              TypeScript-Interfaces (BMASystem, Device, etc.)
        ├── api/
        │   └── axios.ts              NUI-Callback HTTP-Bridge
        ├── plugins/
        │   └── vuetify.ts            Dark Tactical Theme
        ├── stores/
        │   └── mdt.ts                Pinia Store (State, Getters, Actions)
        └── components/
            ├── SystemList.vue        Linke Spalte: Systemliste
            ├── SystemDetail.vue      Mitte oben: System-Header + Tabs
            ├── DeviceGrid.vue        Mitte: Gerätekacheln + Grundriss + Health-Liste
            ├── MaintenanceQueue.vue  Mitte unten: Wartungswarteschlange
            ├── ActionPanel.vue       Rechts oben: 4 Aktions-Buttons
            └── AlarmLog.vue         Rechts unten: Ereignis-Timeline
```

---

## Konfiguration

Aktuell sind Job-Name (`firefighter`) und SQL-Queries direkt in `s_main.lua` und `c_main.lua` hardcodiert.
Für eigene Server: Die Strings `'firefighter'` durch eine eigene `config.lua` ersetzen.

---

## Changelog

### v1.0.0
- Initiales Release
- 3-Spalten Dark-Tactical Dashboard
- Live-Updates via d4rk_firealert Events
- Alarm-Quittierung, Wartungswarteschlange, Alarm-Log
- SVG Mini-Grundriss mit Health-Heatmap
- Admin Probealarm via MDT
