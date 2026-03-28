-- d4rk_firemdt: fxmanifest.lua
-- FiveM Resource Manifest — definiert Metadaten, Skript-Reihenfolge,
-- NUI-Einstiegspunkt und Abhängigkeiten zu anderen Resources.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author  'D4rkst3r'
version '1.0.0'
description 'Feuerwehr MDT Tablet — basiert auf d4rk_firealert'

-- Server-seitiges Lua-Skript (läuft auf dem FiveM-Dedikated-Server)
-- Zuständig für mdt:getData, probeAlarm, assignRepair
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    's_main.lua'
}

-- Client-seitige Lua-Skripte (werden beim Spieler ausgeführt)
-- ox_lib/init.lua muss ZUERST geladen werden, damit lib.* verfügbar ist
client_scripts {
    '@ox_lib/init.lua',
    'c_main.lua'
}

-- NUI-Einstiegspunkt: Die HTML-Datei die als "Bildschirm" des Tablets dient.
-- Vuetify/Vue wird per Vite in html/dist/ gebaut → index.html ist das Bundle.
ui_page 'html/dist/index.html'

-- Alle Build-Artefakte müssen explizit als Ressourcen-Dateien deklariert werden,
-- damit FiveM sie über die NUI-URL ausliefern kann.
files {
    'html/dist/**'
}

-- Abhängigkeiten: Diese Resources müssen gestartet sein bevor d4rk_firemdt läuft.
-- d4rk_firealert ist PFLICHT — wir nutzen dessen Server-Events.
dependencies {
    'ox_lib',
    'ox_target',
    'd4rk_firealert'
}

-- ACE-Permissions für Commands:
-- In server.cfg eintragen:
--   add_ace group.firefighter command.firemdt allow
ace_permissions {
    'command.firemdt'
}
