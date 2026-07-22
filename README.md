# 🍷 Enosfera

**Enosfera** è un archivio personale vini per sommelier professionisti e appassionati. Una webapp moderna, completamente client-side, che permette di catalogare la propria cantina con schede di degustazione professionali secondo i metodi **AIS** e **FISAR**.

---

## ✨ Funzionalità

### 📷 Scansione etichette con AI
Scatta una foto all'etichetta con la fotocamera del dispositivo e l'intelligenza artificiale (Claude AI) riconosce e compila automaticamente tutti i campi: nome, produttore, annata, denominazione, vitigni, regione e gradazione.

### 🔐 Multi-utente con login
Ogni sommelier ha il proprio account con email e password. I dati di ogni utente sono completamente separati e isolati. Al momento della registrazione è possibile indicare l'associazione di appartenenza e il numero di tessera.

**Associazioni supportate:**
- AIS — Associazione Italiana Sommelier
- FISAR — Federazione Italiana Sommelier Albergatori Ristoratori
- ONAV — Organizzazione Nazionale Assaggiatori Vino
- FIS — Fondazione Italiana Sommelier

### 📋 Schede di degustazione professionali

#### Metodo AIS
- **Esame visivo**: limpidezza, colore (intensità), consistenza
- **Esame olfattivo**: intensità, complessità, qualità
- **Esame gustativo**: struttura, equilibrio, intensità gusto-olfattiva, persistenza (PAI), qualità
- **Considerazioni finali**: stato evolutivo, armonia complessiva
- Punteggio automatico su 100 con ponderazione AIS
- Note descrittive separate per olfattivo e gustativo

#### Metodo FISAR
- **Aspetto** (max 20 pt): limpidezza, colore, fluidità, effervescenza
- **Profumo** (max 30 pt): franchezza, intensità, persistenza olfattiva, qualità/finezza, armonia, tipicità varietale
- **Gusto** (max 50 pt): franchezza, struttura, morbidezza, durezza (acidità/tannini), persistenza aromatica, armonia gustativa, tipicità, qualità globale, evoluzione/potenziale, eccellenza (bonus)
- Sub-score visualizzati separatamente

#### Modalità libera
- Slider 1–100 per punteggio personale
- Note di degustazione in testo libero
- Tag personalizzati

### 📦 Archivio completo
Per ogni vino è possibile salvare:
- Foto dell'etichetta fronte e controetichetta
- Dati di identità (nome, produttore, annata, tipologia, denominazione, vitigni)
- Provenienza (regione, paese)
- Dati tecnici (gradazione, formato bottiglia)
- Dati di cantina (prezzo, quantità bottiglie, data e luogo di acquisto, finestra di consumo ottimale)

### 📊 Dashboard statistiche
- Numero totale di etichette e bottiglie
- Punteggio medio della cantina
- Valore complessivo dell'inventario
- Filtri per tipologia (Rosso, Bianco, Rosato, Spumante)
- Ricerca per nome, produttore, regione

### 📤 Export in 4 formati
- **CSV** — apri con Excel, Numbers o Google Sheets
- **JSON** — backup completo con immagini incluse (base64)
- **HTML stampabile** — schede di degustazione con parametri AIS/FISAR, pronte per la stampa
- **Inventario TXT** — lista bottiglie con prezzi, valori e stato evolutivo

---

## 🚀 Utilizzo

Enosfera è una **Single Page Application** completamente client-side. Non richiede server, database o installazione.

### Opzione 1 — Apri direttamente nel browser
Scarica `index.html` e aprilo con qualsiasi browser moderno. Funziona offline.

### Opzione 2 — GitHub Pages (consigliato)
1. Forka questa repository
2. Vai su **Settings → Pages**
3. Seleziona branch `main`, cartella `/ (root)`
4. L'app sarà disponibile su `https://[tuousername].github.io/enosfera`

### Opzione 3 — Deploy su Netlify / Vercel
Trascina la cartella su [netlify.com/drop](https://app.netlify.com/drop) per un deploy istantaneo.

---

## ⚙️ Configurazione scansione etichette AI

La funzione di **scansione etichette con AI** passa attraverso una **Supabase Edge Function** (`supabase/functions/scan-label`), che tiene la chiave Anthropic al sicuro lato server — non è mai esposta nel codice del browser.

La funzione applica anche due limiti di sicurezza per evitare costi imprevisti:
- **Per utente**: 40 scansioni/mese (modificabile in `PER_USER_MONTHLY_LIMIT`)
- **Globale**: 800 scansioni/mese per tutta l'app (modificabile in `GLOBAL_MONTHLY_LIMIT`)

Oltre questi limiti, la funzione risponde con un errore **senza chiamare Anthropic** — quindi non genera alcun costo aggiuntivo.

### Deploy della Edge Function

1. Installa la [Supabase CLI](https://supabase.com/docs/guides/cli) e accedi:
   ```bash
   supabase login
   supabase link --project-ref TUO_PROJECT_REF
   ```
2. Imposta la chiave Anthropic come secret (mai nel codice):
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxxxxxxx
   ```
3. Pubblica la funzione:
   ```bash
   supabase functions deploy scan-label
   ```
4. Esegui `supabase_schema.sql` (sezione `scan_usage`) nel SQL Editor per creare la tabella dei contatori.

In alternativa, la funzione può essere creata/incollata direttamente dalla Dashboard Supabase (**Edge Functions → Deploy a new function**), senza CLI.

> ⚠️ Non esporre mai la chiave API Anthropic nel codice del frontend (`index.html`) — deve esistere solo come secret della Edge Function.

---

## 🗄️ Storage dei dati

Tutti i dati sono salvati in **localStorage** del browser, separati per utente. Nessun dato viene inviato a server esterni (eccetto le chiamate API per la scansione etichette).

| Chiave localStorage | Contenuto |
|---|---|
| `enosfera-users` | Account utenti (email, hash, associazione) |
| `enosfera-wines` | Archivio vini per utente (incluse immagini base64) |

---

## 🧱 Stack tecnologico

| Tecnologia | Utilizzo |
|---|---|
| HTML5 / CSS3 / Vanilla JS | Core dell'applicazione |
| [Tabler Icons](https://tabler.io/icons) | Iconografia |
| [Google Fonts](https://fonts.google.com) | Playfair Display + DM Sans |
| [Anthropic Claude API](https://www.anthropic.com) | Lettura etichette con AI |
| localStorage | Persistenza dati client-side |

---

## 📱 Compatibilità

- ✅ Chrome / Edge (desktop e mobile)
- ✅ Safari (incluso iOS)
- ✅ Firefox
- ✅ Dark mode automatico (segue le preferenze di sistema)
- ✅ Responsive mobile-first

---

## 🗺️ Roadmap

- [ ] Sincronizzazione cloud (Supabase / Firebase)
- [ ] PWA con supporto offline completo
- [ ] Esportazione PDF nativa
- [ ] Abbinamenti cibo con AI
- [ ] Grafico radar per il profilo organolettico
- [ ] Condivisione schede singole con link pubblico
- [ ] Integrazione con database vini (Vivino API, Wine-Searcher)

---

## 🤝 Contribuire

Pull request e issue sono benvenute! Per modifiche sostanziali, apri prima un'issue per discutere cosa vorresti cambiare.

---

## 📄 Licenza

MIT © Enosfera

---

<div align="center">
  <sub>Fatto con ❤️ per i sommelier italiani</sub>
</div>
