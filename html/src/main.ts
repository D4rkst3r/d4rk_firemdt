// src/main.ts
// Einstiegspunkt der Vue-Applikation.
// Hier werden alle Plugins registriert und die App an das DOM gemountet.

import { createApp } from 'vue'
// createPinia() erzeugt die globale Pinia-Instanz (Store-Registry)
import { createPinia } from 'pinia'
import App from './App.vue'
import vuetify from './plugins/vuetify'

// App-Instanz erstellen
const app = createApp(App)

// Plugins registrieren:
// .use(plugin) installiert das Plugin global — alle Komponenten können es nutzen
app.use(createPinia())   // Pinia: alle defineStore() sind jetzt zugänglich
app.use(vuetify)         // Vuetify: alle v-btn, v-card etc. sind global registriert

// App in #app div mounten (definiert in index.html)
app.mount('#app')
