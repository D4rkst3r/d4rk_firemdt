-- d4rk_firemdt: s_main.lua
-- Server-seitiges Lua-Skript für das MDT.
-- Zuständig für:
--   1. Abhandlung von d4rk_firealert:server:mdt:getData
--      → Systeme + Geräte + Logs zusammensammeln und zurückschicken
--   2. NUI-Callback für mdt_probe_alarm (Probealarm via MDT)
--   3. NUI-Callback für mdt_assign_repair (Reparatur beauftragen via MDT)
--
-- WICHTIG: Dieses Skript wird auf dem SERVER ausgeführt.
-- Es hat Zugriff auf MySQL (oxmysql) und die ActiveSystems-Tabelle
-- aus d4rk_firealert — sofern die Resource geladen ist.

---------------------------------------------------------
-- Hilfsfunktion: Daten für ein System zusammenstellen
---------------------------------------------------------

-- Lädt alle Systeme mit Geräten und den letzten 10 Alarm-Logs
-- und gibt sie als Array zurück das direkt an den Client geschickt werden kann.
-- Rückgabe: table[] — Array von System-Objekten
local function BuildMDTPayload()
    -- Alle Systeme aus der Datenbank holen (via d4rk_firealert db-Modul)
    -- db ist global in d4rk_firealert/server/database.lua definiert.
    -- Da beide Resources denselben Server-State teilen NICHT: jede Resource hat
    -- eigene Lua-State. Wir müssen daher direkt MySQL nutzen.

    local systems = MySQL.query.await('SELECT * FROM fire_systems')
    if not systems then return {} end

    local payload = {}

    for _, system in ipairs(systems) do
        -- Geräte dieses Systems laden
        local devices = MySQL.query.await(
            'SELECT id, type, zone, health, last_service FROM fire_devices WHERE system_id = ?',
            { system.id }
        )

        -- Alarm-Logs (letzte 10) laden
        local logs = MySQL.query.await(
            'SELECT id, zone, trigger_type, triggered_at, acknowledged_by, acknowledged_at FROM fire_alarm_log WHERE system_id = ? ORDER BY triggered_at DESC LIMIT 10',
            { system.id }
        )

        table.insert(payload, {
            id     = system.id,
            name   = system.name,
            status = system.status or 'normal',
            -- coords nicht mitschicken — spart Bandbreite, MDT braucht sie nicht
            devices = devices or {},
            logs    = logs    or {},
        })
    end

    return payload
end

---------------------------------------------------------
-- Event: MDT Daten anfordern
-- Wird von c_main.lua via TriggerServerEvent() ausgelöst
---------------------------------------------------------

RegisterNetEvent('d4rk_firealert:server:mdt:getData', function()
    local src = source

    -- Job-Check: Nur Feuerwehr darf MDT-Daten sehen
    -- Wir nutzen dieselbe Logik wie d4rk_firealert/shared/utils.lua
    local jobName = nil

    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if Player then jobName = Player.PlayerData.job.name end
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then jobName = Player.PlayerData.job.name end
    end

    -- Konfigurierter Job — muss mit Config.Job in d4rk_firealert übereinstimmen
    local requiredJob = 'firefighter'

    if jobName ~= requiredJob then
        print(("[d4rk_firemdt] Spieler %s (%s) hat mdt:getData ohne Job versucht!"):format(
            GetPlayerName(src) or '?', src
        ))
        return
    end

    -- Daten laden und zurückschicken
    -- TriggerClientEvent sendet an einen EINZELNEN Client (src = Player-ID)
    local data = BuildMDTPayload()

    -- Admin-Status prüfen (für PROBEALARM-Button)
    local isAdmin = IsPlayerAceAllowed(tostring(src), 'group.admin')

    TriggerClientEvent('d4rk_firealert:client:mdt:open', src, data)

    -- Admin-Flag separat senden damit Store isAdmin setzen kann
    -- Alternativ: im Payload mitschicken — hier getrennt für Übersichtlichkeit
    if isAdmin then
        TriggerClientEvent('d4rk_firemdt:client:setAdmin', src, true)
    end

    print(("[d4rk_firemdt] MDT-Daten für Spieler %s gesendet (%d Systeme)."):format(
        GetPlayerName(src) or '?', #data
    ))
end)

---------------------------------------------------------
-- Event: Probealarm via MDT auslösen (NUI-Callback Umweg)
-- c_main.lua empfängt den NUI-Callback und schickt dieses Event
---------------------------------------------------------

RegisterNetEvent('d4rk_firemdt:server:probeAlarm', function(systemId)
    local src = source

    -- Nur Admins
    if not IsPlayerAceAllowed(tostring(src), 'group.admin') then
        return
    end

    -- Probealarm via d4rk_firealert auslösen
    -- Da TriggerAlarm() in d4rk_firealert server/main.lua global definiert ist
    -- und Lua-States zwischen Resources NICHT geteilt werden, nutzen wir
    -- das Server-Event das d4rk_firealert bereits hat.
    --
    -- Alternativ: lib.addCommand 'test_bma' aus d4rk_firealert direkt nutzen.
    -- Wir loggen direkt in fire_alarm_log mit type 'test'.
    if systemId then
        MySQL.update('UPDATE fire_systems SET status = ? WHERE id = ?', { 'alarm', systemId })
        MySQL.insert(
            'INSERT INTO fire_alarm_log (system_id, system_name, zone, trigger_type) SELECT ?, name, ?, ? FROM fire_systems WHERE id = ?',
            { systemId, 'MDT Probealarm', 'test', systemId }
        )
        -- Alle Clients über den Alarm informieren
        TriggerClientEvent('d4rk_firealert:client:updateSystemStatus', -1, systemId, 'alarm')
    end
end)

---------------------------------------------------------
-- Event: Reparatur beauftragen (NUI-Callback Umweg)
---------------------------------------------------------

RegisterNetEvent('d4rk_firemdt:server:assignRepair', function(deviceId)
    local src = source

    -- Job-Check
    local jobName = nil
    if GetResourceState('qbx_core') == 'started' then
        local Player = exports.qbx_core:GetPlayer(src)
        if Player then jobName = Player.PlayerData.job.name end
    elseif GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then jobName = Player.PlayerData.job.name end
    end

    if jobName ~= 'firefighter' then return end

    -- Gerät direkt reparieren (100% Health, kein Item-Check via MDT)
    MySQL.update(
        'UPDATE fire_devices SET health = 100, last_service = CURRENT_TIMESTAMP WHERE id = ?',
        { deviceId }
    )

    -- Alle Clients über die neue Health informieren
    TriggerClientEvent('d4rk_firealert:client:updateDeviceHealth', -1, deviceId, 100)

    -- MDT-Spieler bestätigen
    TriggerClientEvent('ox_lib:notify', src, {
        title       = 'MDT Reparatur',
        description = 'Gerät #' .. deviceId .. ' auf 100% gesetzt.',
        type        = 'success'
    })
end)

---------------------------------------------------------
-- NUI-Callback Weiterleitung: Lua empfängt und triggert Server-Event
-- (NUI-Callbacks kommen vom CLIENT — der muss sie an den Server weiterleiten)
---------------------------------------------------------
-- Diese Events werden in c_main.lua per RegisterNUICallback empfangen
-- und dann via TriggerServerEvent hierher weitergeleitet.
-- Das ist der Standard FiveM NUI → Server Kommunikationsweg.
