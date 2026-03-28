-- d4rk_firemdt: c_main.lua
-- Client-seitiges Lua-Skript. Zuständig für:
--   1. Öffnen/Schließen des NUI-Fensters (SetNuiFocus)
--   2. NUI-Callbacks empfangen (Vue → Lua → Server)
--   3. Server-Events abonnieren und als SendNUIMessage an Vue weiterleiten
--   4. ox_target Integration an prop_computer_02

-- =========================================================
-- Zustandsvariablen
-- =========================================================

local isOpen = false  -- Ist das MDT gerade sichtbar?

-- =========================================================
-- Hilfsfunktionen
-- =========================================================

-- Job-Check: Versucht den Export von d4rk_firealert zu nutzen.
-- Fällt auf ox_lib/qbx_core zurück wenn Export nicht erreichbar ist.
-- Rückgabe: true wenn Spieler als Feuerwehr eingeloggt ist.
local function HasFirefighterJob()
    -- Primär: Shared-Funktion aus d4rk_firealert nutzen
    local ok, result = pcall(function()
        -- Utils.HasJobClient ist global in d4rk_firealert/shared/utils.lua definiert.
        -- Da beide Resources laufen teilen sie NICHT denselben Lua-State —
        -- wir prüfen daher per direktem Framework-Zugriff.
        local jobName = nil

        if GetResourceState('qbx_core') == 'started' then
            jobName = exports.qbx_core:GetPlayerData().job.name
        elseif GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            jobName = QBCore.Functions.GetPlayerData().job.name
        end

        -- 'firefighter' ist der Standard-Job aus d4rk_firealert/config.lua.
        -- Für eigene Server: hier den Job aus einer lokalen Config lesen.
        return jobName == 'firefighter'
    end)

    if not ok then
        -- Fehler beim Framework-Zugriff → sicherheitshalber ablehnen
        return false
    end
    return result
end

-- Öffnet das MDT: Job-Check → NUI anzeigen → Daten anfordern
local function OpenMDT()
    if isOpen then return end

    if not HasFirefighterJob() then
        lib.notify({
            title       = 'Feuerwehr MDT',
            description = 'Nur Feuerwehr-Personal hat Zugang zum MDT.',
            type        = 'error',
            duration    = 3000
        })
        return
    end

    isOpen = true

    -- SetNuiFocus(hasFocus, hasCursor):
    --   hasFocus = true  → Tastatureingaben gehen ans NUI-Fenster statt ins Spiel
    --   hasCursor = true → Maus-Cursor wird sichtbar
    SetNuiFocus(true, true)

    -- Vue-App informieren dass das MDT geöffnet werden soll.
    -- SendNUIMessage sendet ein JSON-Objekt an window.addEventListener('message', ...)
    SendNUIMessage({ type = 'mdt_open' })

    -- Datenabruf starten — Server antwortet mit d4rk_firealert:client:mdt:open
    TriggerServerEvent('d4rk_firealert:server:mdt:getData')
end

-- Schließt das MDT sauber
local function CloseMDT()
    if not isOpen then return end
    isOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'mdt_close' })
end

-- =========================================================
-- NUI-Callbacks
-- Ablauf: Vue ruft axios.post('endpoint', data) auf →
-- FiveM leitet das an RegisterNUICallback weiter →
-- cb('ok') schickt die Antwort zurück an Vue (Promise resolved)
-- =========================================================

-- Vue hat den Schließen-Button geklickt oder ESC gedrückt
RegisterNUICallback('mdt_close', function(_, cb)
    CloseMDT()
    cb('ok')
end)

-- Vue möchte die Daten neu laden (Refresh-Button)
RegisterNUICallback('mdt_refresh', function(_, cb)
    -- Neuen Datenabruf starten; Server antwortet wieder mit mdt:open Event
    TriggerServerEvent('d4rk_firealert:server:mdt:getData')
    cb('ok')
end)

-- Vue hat QUITTIEREN geklickt
-- data.systemId: number — ID des Systems das quittiert werden soll
RegisterNUICallback('mdt_quittieren', function(data, cb)
    if data and data.systemId then
        -- Das Event ist in d4rk_firealert/server/main.lua definiert.
        -- Server prüft erneut den Job des aufrufenden Spielers.
        TriggerServerEvent('d4rk_firealert:server:quittieren', data.systemId)
    end
    cb('ok')
end)

-- Vue hat PROBEALARM-Button geklickt (nur für Admins)
-- data.systemId: number
RegisterNUICallback('mdt_probe_alarm', function(data, cb)
    if data and data.systemId then
        TriggerServerEvent('d4rk_firemdt:server:probeAlarm', data.systemId)
    end
    cb('ok')
end)

-- Vue hat Reparatur für ein Gerät beauftragt
-- data.deviceId: number
RegisterNUICallback('mdt_assign_repair', function(data, cb)
    if data and data.deviceId then
        TriggerServerEvent('d4rk_firemdt:server:assignRepair', data.deviceId)
    end
    cb('ok')
end)

-- Admin-Status vom Server empfangen und per NUI weiterschicken
RegisterNetEvent('d4rk_firemdt:client:setAdmin', function(isAdmin)
    if not isOpen then return end
    SendNUIMessage({ type = 'mdt_set_admin', isAdmin = isAdmin })
end)

-- =========================================================
-- Command
-- =========================================================

-- /firemdt — öffnet oder schließt das MDT (Toggle)
RegisterCommand('firemdt', function()
    if isOpen then
        CloseMDT()
    else
        OpenMDT()
    end
end, false)

-- =========================================================
-- Server-Events abhören und als NUI-Message weiterleiten
-- Diese Events werden von d4rk_firealert gesendet — wir "lauschen" sie nur mit.
-- =========================================================

-- Antwort auf mdt:getData — enthält alle Systeme mit Geräten + Logs
RegisterNetEvent('d4rk_firealert:client:mdt:open', function(systems)
    -- Nur weiterleiten wenn MDT auch geöffnet ist
    if not isOpen then return end
    SendNUIMessage({ type = 'mdt_data', systems = systems })
end)

-- Live-Update: Status eines Systems hat sich geändert (alarm/trouble/normal)
-- systemId: number, status: string
RegisterNetEvent('d4rk_firealert:client:updateSystemStatus', function(systemId, status)
    if not isOpen then return end
    SendNUIMessage({
        type     = 'mdt_status_update',
        systemId = systemId,
        status   = status
    })
end)

-- Live-Update: Health eines einzelnen Geräts hat sich geändert
-- deviceId: number, health: number (0–100)
RegisterNetEvent('d4rk_firealert:client:updateDeviceHealth', function(deviceId, health)
    if not isOpen then return end
    SendNUIMessage({
        type     = 'mdt_health_update',
        deviceId = deviceId,
        health   = health
    })
end)

-- =========================================================
-- ox_target Integration
-- Spieler können das MDT durch Interaktion mit einem Computer-Prop öffnen.
-- =========================================================

CreateThread(function()
    -- Nur starten wenn ox_target überhaupt läuft
    if GetResourceState('ox_target') ~= 'started' then return end

    -- prop_computer_02 = Standard GTA5 Bürocomputer (passt zu Feuerwache)
    exports.ox_target:addModel(`prop_computer_02`, {
        {
            name     = 'open_firemdt',
            icon     = 'fas fa-fire-extinguisher',
            label    = 'Feuerwehr MDT öffnen',
            -- Kein groups-Check hier — HasFirefighterJob() übernimmt das in OpenMDT()
            distance = 2.0,
            onSelect = function()
                OpenMDT()
            end
        }
    })
end)

-- =========================================================
-- Cleanup beim Resource-Stop
-- =========================================================

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- NUI-Focus freigeben damit der Spieler nicht gefangen bleibt
    if isOpen then
        SetNuiFocus(false, false)
    end
end)
