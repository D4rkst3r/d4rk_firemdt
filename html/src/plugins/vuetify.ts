// src/plugins/vuetify.ts
// Vuetify-Konfiguration: Hier wird das visuelle Theme des MDT definiert.
//
// Warum ein eigenes Theme statt Vuetify-Defaults?
// Vuetify-Defaults (Material Design mit hellen Farben) passen nicht zum
// "Dark Industrial Tablet"-Stil. Ein eigenes Theme überschreibt alle
// Vuetify-Komponentenfarben global — keine lokalen color-Props nötig.

import { createVuetify } from 'vuetify'
import * as components from 'vuetify/components'
import * as directives from 'vuetify/directives'
// @mdi/font stellt alle Material Design Icons bereit (mdi-fire, mdi-bell, etc.)
import '@mdi/font/css/materialdesignicons.css'
// Vuetify base styles
import 'vuetify/styles'
import '@/styles/nui-override.css'  // ← NEU: überschreibt Vuetify im Bundle

// -------------------------------------------------------
// Farb-Definitionen
// -------------------------------------------------------

/** Farbpalette für das taktische Dark-Theme */
const colors = {
  // Hintergründe — drei Abstufungen für Tiefe
  bgDeep:    '#07090c',   // Tiefster Hintergrund (außerhalb des Tablets)
  bgBase:    '#0e1117',   // Tablet-Screen Hintergrund
  bgSurface: '#161b22',   // Panel/Card Hintergrund
  bgBorder:  '#21293a',   // Panel-Borders

  // Akzentfarben
  primary:   '#f46d2f',   // Fire Orange — Primärfarbe, Buttons, Highlights
  alarm:     '#f85149',   // Rot — aktiver Alarm
  trouble:   '#d29922',   // Gelb/Amber — Störung
  normalGreen: '#3fb950', // Grün — Normalbetrieb

  // Aktions-Button Farben (entsprechen dem Mockup)
  actionQuittieren: '#e3b341', // Gelb
  actionReset:      '#3fb950', // Grün
  actionProbe:      '#58a6ff', // Blau
  actionRepair:     '#f46d2f', // Orange = primary

  // Text
  textPrimary:   '#e6edf3',   // Haupttext (fast weiß)
  textSecondary: '#8b949e',   // Sekundärtext (Panel-Header, Labels)
  textMuted:     '#484f58',   // Sehr gedämpft
}

export default createVuetify({
  // Welche Vuetify-Komponenten und Direktiven eingebunden werden
  components,
  directives,

  // Icon-Set: MDI (Material Design Icons) — vorinstalliert mit @mdi/font
  icons: {
    defaultSet: 'mdi',
  },

  theme: {
    // Standardmäßig das dark-tactical Theme nutzen
    defaultTheme: 'darkTactical',
    cspNonce: undefined,
    // Verhindert dass Vuetify background-color auf <html>/<body> setzt
    variations: false,
    themes: {
      darkTactical: {
        dark: true,  // Vuetify weiß: dunkle Variante aller Komponenten nutzen

        colors: {
          // Pflichtfelder die Vuetify für seine internen Berechnungen braucht:
          background: colors.bgDeep,  // transparent: sonst füllt Vuetify den ganzen Screen auch wenn MDT geschlossen ist
          surface:    colors.bgSurface,

          // 'primary' wird von Vuetify für Buttons, Chips, Links etc. als Default genutzt
          primary:   colors.primary,
          secondary: colors.textSecondary,
          error:     colors.alarm,
          warning:   colors.trouble,
          success:   colors.normalGreen,
          info:      colors.actionProbe,

          // Eigene Custom-Farben — können in Templates als color="alarm" etc. genutzt werden
          alarm:     colors.alarm,
          trouble:   colors.trouble,
          normal:    colors.normalGreen,

          // Panel-Farben (für v-card, v-list etc.)
          'bg-deep':    colors.bgDeep,
          'bg-surface': colors.bgSurface,
          'border-col': colors.bgBorder,

          // Text
          'text-primary':   colors.textPrimary,
          'text-secondary': colors.textSecondary,
          'text-muted':     colors.textMuted,

          // Aktions-Buttons
          'action-quittieren': colors.actionQuittieren,
          'action-reset':      colors.actionReset,
          'action-probe':      colors.actionProbe,
          'action-repair':     colors.actionRepair,
        },

        // CSS-Variablen werden von Vuetify automatisch als --v-theme-<name> gesetzt.
        // Zusätzlich eigene CSS-Variablen definieren damit wir sie in <style> nutzen können.
        variables: {
          // Border-Radius: 2px für den eckig-taktischen Look
          'border-radius-root': '2px',
          // Elevation-Farbe für Box-Shadows
          'shadow-key-umbra-opacity': 0.3,
        },
      },
    },
  },

  // Globale Komponenten-Defaults — überschreiben Vuetify-Defaults für ALLE Instanzen
  defaults: {
    VBtn: {
      // Kein Rounded-Corners (border-radius: 2px aus theme variables)
      rounded: 0,
      // Uppercase-Text für taktischen Look
      style: 'letter-spacing: 0.1em; font-family: "Rajdhani", sans-serif; font-weight: 700;',
    },
    VCard: {
      rounded: 0,
      elevation: 0,
    },
    VChip: {
      rounded: 0,
      // density="compact" = weniger Padding — passt besser für Status-Badges
      density: 'compact',
    },
    VList: {
      bgColor: 'transparent',
    },
    VListItem: {
      rounded: 0,
    },
  },
})
