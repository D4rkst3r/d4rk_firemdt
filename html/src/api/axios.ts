// src/api/axios.ts
// NUI-Bridge: Verbindet Vue-Code mit dem FiveM Lua-Backend über HTTP-Requests.
//
// Wie NUI-Callbacks in FiveM funktionieren:
// ┌─────────────────────────────────────────────────────────────────┐
// │  Vue-Seite                     │  Lua-Seite (c_main.lua)       │
// │  axios.post('mdt_close', {})   │  RegisterNUICallback(         │
// │  ─────────────────────────►    │    'mdt_close',               │
// │                                │    function(data, cb)         │
// │  ◄─────────────────────────    │      cb('ok')  ← Promise      │
// │  Promise resolved              │    end)                       │
// └─────────────────────────────────────────────────────────────────┘
//
// FiveM stellt intern einen lokalen HTTP-Server unter
// https://<resourceName>/<callbackName> bereit.
// Axios sendet einen POST-Request dorthin — Lua empfängt ihn als NUI-Callback.

import axios from 'axios'

// Ressourcenname MUSS exakt mit dem Ordnernamen der FiveM Resource übereinstimmen.
// Falsche Schreibweise → alle NUI-Callbacks schlagen still fehl.
const RESOURCE_NAME = 'd4rk_firemdt'

// Axios-Instanz mit Basis-URL auf die aktuelle FiveM Resource.
// Alle post()-Aufrufe werden relativ zu dieser URL ausgeführt.
const instance = axios.create({
  baseURL: `https://${RESOURCE_NAME}/`,
  // Timeout damit Vue nicht ewig auf eine Lua-Antwort wartet
  timeout: 5000,
})

/**
 * Sendet einen NUI-Callback an Lua.
 * @param endpoint - Name des RegisterNUICallback (z.B. 'mdt_close')
 * @param data - Beliebige JSON-serialisierbare Nutzlast (optional)
 * @returns Promise das resolved wenn Lua cb() aufruft
 */
export const nuiPost = async <T = unknown>(
  endpoint: string,
  data?: Record<string, unknown>
): Promise<T> => {
  const response = await instance.post<T>(endpoint, data ?? {})
  return response.data
}

// Dev-Umgebung: Im Browser (npm run dev) existiert kein FiveM-Lua.
// Axios würde CORS-Fehler werfen. Wir fangen das ab damit die App
// auch außerhalb von FiveM entwickelt/getestet werden kann.
if ((import.meta as { env?: { DEV?: boolean } }).env?.DEV) {
  instance.interceptors.response.use(
    (res) => res,
    (error) => {
      // Im Dev-Modus einfach loggen statt zu crashen
      console.warn('[MDT Dev] NUI-Callback fehlgeschlagen (normal im Browser):', error.config?.url)
      return Promise.resolve({ data: 'ok' })
    }
  )
}

export default instance
