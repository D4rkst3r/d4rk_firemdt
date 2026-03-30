-- d4rk_firemdt: c_main.lua
-- Client-seitiges Lua-Skript. Zuständig für:
--   1. Öffnen/Schließen des NUI-Fensters (SetNuiFocus)
--   2. NUI-Callbacks empfangen (Vue → Lua → Server)
--   3. Server-Events abonnieren und als SendNUIMessage an Vue weiterleiten
--   4. ox_target Integration an prop_computer_02
--   5. Tablet-Prop (prop_cs_tablet) + Animation beim Öffnen/Schließen

-- =========================================================
-- Zustandsvariablen
-- =========================================================

local isOpen    = false  -- Ist das MDT gerade sichtbar?
local tabletProp = nil   -- Entity-Handle des gespawnten Tablet-Props

-- =========================================================
-- Animations- und Prop-Konfiguration
-- =========================================================

local TABLET_CONFIG = {
    prop     = 'prop_cs_tablet',
    bone     = 'SKEL_R_Hand',
    boneId   = 28422,
    offset   = { x = 0.015,  y = -0.011, z = -0.075 },
    rotation = { x = 0.0,    y = 0.0,    z = 0.0 },
    animDict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    animClip = 'base',
}

-- =========================================================
-- Hilfsfunktionen
-- =========================================================

-- Job-Check: Versucht den Export von d4rk_firealert zu nutzen.
-- Fällt auf qbx_core/qb-core zurück wenn Export nicht erreichbar ist.
-- Rückgabe: true wenn Spieler als Feuerwehr eingeloggt ist.
local function HasFirefighterJob()
    local ok, result = pcall(function()
        local jobName = nil

        if GetResourceState('qbx_core') == 'started' then
            jobName = exports.qbx_core:GetPlayerData().job.name
        elseif GetResourceState('qb-core') == 'started' then
            local QBCore = exports['qb-core']:GetCoreObject()
            jobName = QBCore.Functions.GetPlayerData().job.name
        end

        return jobName == 'firefighter'
    end)

    if not ok then return false end
    return result
end

-- Spawnt das Tablet-Prop und attached es an die rechte Hand des Spielers
local function SpawnTabletProp()
    local ped = PlayerPedId()

    -- Model laden
    RequestModel(`prop_cs_tablet`)
    while not HasModelLoaded(`prop_cs_tablet`) do Wait(0) end

    -- Prop erzeugen und an Knochen attachieren
    tabletProp = CreateObject(`prop_cs_tablet`, 0.0, 0.0, 0.0, true, true, false)

    AttachEntityToEntity(
        tabletProp,
        ped,
        GetEntityBoneIndexByName(ped, TABLET_CONFIG.bone),
        TABLET_CONFIG.offset.x,
        TABLET_CONFIG.offset.y,
        TABLET_CONFIG.offset.z,
        TABLET_CONFIG.rotation.x,
        TABLET_CONFIG.rotation.y,
        TABLET_CONFIG.rotation.z,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(`prop_cs_tablet`)
end

-- Spielt die Tablet-Halte-Animation ab
local function PlayTabletAnim()
    local ped      = PlayerPedId()
    local animDict = TABLET_CONFIG.animDict
    local animClip = TABLET_CONFIG.animClip

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(0) end

    -- Flag 49 = Loop + obere Körperhälfte
    TaskPlayAnim(ped, animDict, animClip, 3.0, -1.0, -1, 49, 0.0, false, false, false)
end

-- Stoppt Animation und löscht das Prop
local function CleanupTablet()
    local ped = PlayerPedId()

    -- Animation sanft stoppen (blendout 3.0 Sekunden)
    StopAnimTask(ped, TABLET_CONFIG.animDict, TABLET_CONFIG.animClip, 3.0)

    -- Prop entfernen
    if tabletProp and DoesEntityExist(tabletProp) then
        DetachEntity(tabletProp, true, true)
        DeleteObject(tabletProp)
        tabletProp = nil
    end
end

-- =========================================================
-- MDT öffnen / schließen
-- =========================================================

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

    -- Prop spawnen und Animation starten
    SpawnTabletProp()
    PlayTabletAnim()

    -- NUI öffnen
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'mdt_open' })

    -- Daten vom Server anfordern
    TriggerServerEvent('d4rk_firealert:server:mdt:getData')
end

local function CloseMDT()
    if not isOpen then return end
    isOpen = false

    -- Animation und Prop aufräumen
    CleanupTablet()

    -- NUI schließen
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'mdt_close' })
end

-- =========================================================
-- NUI-Callbacks
-- =========================================================

RegisterNUICallback('mdt_close', function(_, cb)
    CloseMDT()
    cb('ok')
end)

RegisterNUICallback('mdt_refresh', function(_, cb)
    TriggerServerEvent('d4rk_firealert:server:mdt:getData')
    cb('ok')
end)

RegisterNUICallback('mdt_quittieren', function(data, cb)
    if data and data.systemId then
        TriggerServerEvent('d4rk_firealert:server:quittieren', data.systemId)
    end
    cb('ok')
end)

RegisterNUICallback('mdt_probe_alarm', function(data, cb)
    if data and data.systemId then
        TriggerServerEvent('d4rk_firemdt:server:probeAlarm', data.systemId)
    end
    cb('ok')
end)

RegisterNUICallback('mdt_assign_repair', function(data, cb)
    if data and data.deviceId then
        TriggerServerEvent('d4rk_firemdt:server:assignRepair', data.deviceId)
    end
    cb('ok')
end)

RegisterNetEvent('d4rk_firemdt:client:setAdmin', function(isAdmin)
    if not isOpen then return end
    SendNUIMessage({ type = 'mdt_set_admin', isAdmin = isAdmin })
end)

-- =========================================================
-- Command
-- =========================================================

RegisterCommand('firemdt', function()
    if isOpen then
        CloseMDT()
    else
        OpenMDT()
    end
end, false)

-- =========================================================
-- Server-Events → NUI weiterleiten
-- =========================================================

RegisterNetEvent('d4rk_firealert:client:mdt:open', function(systems)
    if not isOpen then return end
    SendNUIMessage({ type = 'mdt_data', systems = systems })
end)

RegisterNetEvent('d4rk_firealert:client:updateSystemStatus', function(systemId, status)
    if not isOpen then return end
    SendNUIMessage({
        type     = 'mdt_status_update',
        systemId = systemId,
        status   = status
    })
end)

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
-- =========================================================

CreateThread(function()
    if GetResourceState('ox_target') ~= 'started' then return end

    exports.ox_target:addModel(`prop_computer_02`, {
        {
            name     = 'open_firemdt',
            icon     = 'fas fa-fire-extinguisher',
            label    = 'Feuerwehr MDT öffnen',
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
    if isOpen then
        SetNuiFocus(false, false)
        CleanupTablet()
    end
end)