<!--
╔══════════════════════════════════════════════════════════════════════════════╗
║  prompt-master.md                                                            ║
║  Template per la generazione parallela di pagine di siti vetrina             ║
╚══════════════════════════════════════════════════════════════════════════════╝

SCOPO
  Questo file è il template base per generare i prompt di pagina da passare a
  claude-parallel-runner. Contiene tutte le regole, le fasi di processo, le
  istruzioni git e le istruzioni CMS che si ripetono uguali su ogni pagina.

  È pensato per essere usato in due modi:
    1. Come --impl-prompt (file anteposto a ogni prompt):
       bash run.sh --dir ./prompts --print --worktree \
         --work-dir /path/to/repo \
         --impl-prompt ./prompt-master.md
       In questo caso le parti comuni stanno qui; ogni file in --dir contiene
       solo CONTESTO PAGINA + SPECIFICHE EDITORIALI.

    2. Come template da cui generare prompt page-specifici autonomi:
       Copia questo file, compila i segnaposto e incorpora CONTESTO PAGINA +
       SPECIFICHE EDITORIALI in fondo. Il risultato è un file autosufficiente.

FLUSSO DI COMPILAZIONE
  Prima di usare questo file, sostituisci tutti i segnaposto {{...}} con i
  valori reali del progetto. I segnaposto sono divisi in due gruppi:

  — SEGNAPOSTO GLOBALI (uguali per tutto il progetto, da compilare una volta)

    {{PROJECT_NAME}}              Nome del progetto/prodotto
                                  es. "a-vendi"

    {{PROJECT_DESCRIPTION}}       Descrizione dell'ecosistema in 2-3 righe
                                  es. "a-vendi non è solo una piattaforma..."

    {{CORE_PRODUCT}}              Il prodotto core su cui non si deve collassare
                                  tutto il messaggio
                                  es. "la piattaforma UTP"

    {{CMS_NAME}}                  Nome del CMS headless usato
                                  es. "PayloadCMS", "Sanity", "Contentful"

    {{CMS_REPO_PATH}}             Percorso locale della repo CMS
                                  es. "/Users/nome/Projects/cms-core"

    {{CMS_ROUTING_PATTERN}}       Descrizione del routing del sito front.
                                  Incolla il pattern reale del progetto, es.:
                                  "Tutte le pagine usano app/[locale]/[...slug]/page.tsx"

    {{CMS_FALLBACK_PATTERN}}      Pattern di rendering CMS → fallback hardcoded.
                                  Incolla il codice o la descrizione del pattern,
                                  es. il blocco getPageBySlug + SectionsRenderer.

    {{CMS_FILE_PATH_PATTERN}}     Pattern del percorso file Next.js/framework
                                  es. "app/[locale]/[...slug]/page.tsx"

    {{I18N_PATTERN}}              Sistema i18n e regola sulle stringhe hardcoded
                                  es. "next-intl — nessuna stringa fissa in una sola lingua"

    {{SITE_FRONT_PATH}}           Percorso locale del sito front
                                  es. "/Users/nome/Projects/my-site-front"

    {{DOCS_PATH}}                 Percorso documentazione prodotto
                                  es. "/Users/nome/Projects/my-platform/doc"

    {{BRANDKIT_PATH}}             Percorso design system / brandkit
                                  es. "/Users/nome/Projects/my-brandkit"

    {{LOCALE_PRIMARY}}            Lingua principale (codice ISO)
                                  es. "it"

    {{LOCALE_SECONDARY}}          Lingua secondaria (codice ISO)
                                  es. "en"

    {{TENANT_SLUG}}               Slug del tenant nel CMS (se multi-tenant)
                                  es. "a-vendi" — rimuovi la riga se non applicabile

    {{INDUSTRY}}                  Settore di riferimento
                                  es. "hospitality e tourism", "e-commerce", "fintech"

    {{TARGET_AUDIENCE}}           Pubblico target del sito
                                  es. "operatori hospitality B2B", "PMI retail"

    {{BUSINESS_MODEL}}            Modello di business del sito
                                  es. "B2B", "B2C", "marketplace"

    {{PAGE_CATEGORIES}}           Elenco delle categorie di pagina del progetto
                                  es.:
                                  - pagine piattaforma (moduli core)
                                  - pagine digital (siti web, SEO, social)
                                  - pagine soluzioni (per verticale)
                                  - pagine corporate (chi siamo, supporto)
                                  - pagine pricing

    {{INDUSTRY_SPECIFIC_OUTCOMES}} Outcome di valore specifici del settore,
                                  in formato lista puntata, es.:
                                  - incremento prenotazioni dirette
                                  - migliore gestione revenue
                                  - efficienza del team operativo

    {{QUALITY_RULES_PER_CATEGORY}} Regole qualitative per categoria di pagina,
                                  in formato lista puntata, es.:
                                  - Le pagine piattaforma devono spiegare capacità
                                    e valore operativo.
                                  - Le pagine pricing devono essere chiarissime.

    {{TERMINOLOGY_RULES}}         Termini vietati, codici interni da non esporre,
                                  tecnicismi da riscrivere — sia nella lingua
                                  primaria che secondaria. Formato libero.

    {{INSPIRATION_URLS}}          3-5 URL di siti competitor o best-in-class,
                                  uno per riga, es.:
                                  - https://www.bokun.io/
                                  - https://www.siteminder.com/

    {{NAVIGATION_STRUCTURE}}      Struttura di navigazione completa in JSON
                                  (o formato equivalente), con slug IT e EN.

  — SEGNAPOSTO DI PAGINA (da compilare per ogni singolo file prompt)

    {{PAGE_NAME_PRIMARY}}         Nome della pagina nella lingua primaria
                                  es. "Chi siamo"

    {{PAGE_NAME_SECONDARY}}       Nome della pagina nella lingua secondaria
                                  es. "About us"

    {{PAGE_SLUG_PRIMARY}}         URL completo nella lingua primaria
                                  es. "/it/chi-siamo"

    {{PAGE_SLUG_SECONDARY}}       URL completo nella lingua secondaria
                                  es. "/en/about"

    {{EDITORIAL_SPECS_PRIMARY}}   Specifiche editoriali nella lingua primaria:
                                  titolo, descrizione, sezioni, sotto-sezioni.

    {{EDITORIAL_SPECS_SECONDARY}} Specifiche editoriali nella lingua secondaria.

UTILIZZO CON claude-parallel-runner
  Modalità A — impl-prompt (parti comuni qui, specifiche nei singoli file):
    1. Compila tutti i segnaposto GLOBALI in questo file.
    2. Per ogni pagina crea un file .md in --dir con solo:
         ## CONTESTO PAGINA
         ## SPECIFICHE EDITORIALI — IT
         ## SPECIFICHE EDITORIALI — EN
    3. Lancia:
         bash run.sh --dir ./prompts --print --worktree \
           --work-dir /path/to/site-front \
           --impl-prompt ./prompt-master.md

  Modalità B — prompt autonomo per pagina (file autosufficiente):
    1. Copia questo file per ogni pagina.
    2. Compila tutti i segnaposto globali E di pagina.
    3. Lancia run.sh senza --impl-prompt.

NOTE
  - I blocchi <!-- --> non vengono inviati agli LLM (ignorati come HTML comment).
  - Le righe di esempio tra parentesi (es. ...) vanno rimosse dopo la compilazione.
  - Il template è indipendente dal framework: adatta CMS_ROUTING_PATTERN e
    CMS_FALLBACK_PATTERN al progetto reale (Next.js, Nuxt, Astro, ecc.).
-->

Agisci come senior content strategist, information architect, UX writer e solution designer per il sito vetrina di {{PROJECT_NAME}}.

Il tuo obiettivo è generare le pagine del sito vetrina di {{PROJECT_NAME}} partendo dalla struttura editoriale allegata e dai requisiti qui sotto, mantenendo coerenza strategica, chiarezza commerciale, accuratezza rispetto all'offerta reale e fattibilità implementativa nel sito esistente.

CONTESTO
- {{PROJECT_DESCRIPTION}}
- La struttura allegata descrive le pagine del sito vetrina, la navigazione, le categorie, le sezioni e le sotto-sezioni.
- Le pagine dovranno essere gestite nel sito già integrato con {{CMS_NAME}}.
- Le pagine dovranno esistere sia in {{LOCALE_PRIMARY}} sia in {{LOCALE_SECONDARY}}.
- Se necessario per approfondire funzionalità o dettagli della pagina, consulta la documentazione del prodotto in:
  {{DOCS_PATH}}
- Devi seguire il design system presente in:
  {{BRANDKIT_PATH}}
- Se necessario per maggiore coerenza, chiarezza o scalabilità, puoi proporre nuovi componenti o pattern UI, ma solo quando i componenti esistenti non bastano.

ISPIRAZIONE
Per impostazione delle pagine, struttura narrativa, chiarezza commerciale, uso delle sezioni e presentazione dell'offerta, lasciati ispirare da questi riferimenti, senza copiarli:
{{INSPIRATION_URLS}}

Usa questi riferimenti per:
- capire come presentare prodotti e servizi nel settore {{INDUSTRY}};
- costruire pagine chiare, modulari, orientate alla conversione e facili da navigare;
- organizzare hero, sezioni valore, use case, feature grouping, CTA, proof element e differenziazione;
- mantenere un tono professionale, concreto, affidabile e orientato al risultato;
- NON imitare naming, testi, layout o gerarchie in modo servile.

REGOLE FONDAMENTALI
1. Prima di generare qualsiasi pagina, esegui un'analisi preliminare.
2. Prima di procedere, individua e segnala:
   - eventuali ambiguità nella struttura;
   - eventuali conflitti o sovrapposizioni tra pagine;
   - eventuali contenuti troppo tecnici o troppo interni per il pubblico della pagina;
   - eventuali punti in cui il messaggio non è sufficientemente chiaro, commerciale o orientato al valore.
3. Se trovi ambiguità o contenuti da rimodulare, NON andare avanti in automatico: elencali in modo esplicito e proponi una rimodulazione.
4. Devi sempre valutare se un contenuto è adatto al pubblico della pagina o se appartiene più a una documentazione tecnica/prodotto interna.
5. Se un contenuto è troppo tecnico, trasformalo in beneficio, outcome, capacità operativa o vantaggio business, senza perdere il significato.
6. Devi distinguere chiaramente le categorie di pagina del progetto:
   {{PAGE_CATEGORIES}}
7. È fondamentale far percepire che {{PROJECT_NAME}} NON coincide soltanto con {{CORE_PRODUCT}}.
8. Ogni pagina deve avere un posizionamento chiaro all'interno dell'offerta complessiva di {{PROJECT_NAME}}.
9. Ogni pagina deve essere pensata per un sito pubblico {{BUSINESS_MODEL}} rivolto a {{TARGET_AUDIENCE}}.
10. Non usare linguaggio da documentazione tecnica interna, architetturale o domain-driven se non è davvero comprensibile e utile per il pubblico finale.
11. Dove emergono concetti troppo tecnici, riscrivili in modo orientato a:
   - semplicità operativa,
   - controllo,
   - affidabilità,
   - automazione,
   - riduzione degli errori,
   {{INDUSTRY_SPECIFIC_OUTCOMES}}

DESIGN, UX E CONTENUTO
Per ogni pagina:
- imposta una struttura chiara, leggibile e orientata alla comprensione rapida;
- usa una gerarchia editoriale forte;
- alterna sezioni descrittive, sezioni di valore, sezioni funzionali, use case, elementi comparativi e CTA;
- prevedi sempre elementi visuali utili alla comprensione.

Per ogni pagina e per ogni sezione interna, valuta quando introdurre:
- illustrazioni;
- grafici;
- diagrammi;
- schemi;
- tabelle;
- disegni concettuali;
- comparazioni visuali;
- timeline;
- card strutturate;
- infografiche leggere.

Questi elementi non devono essere decorativi: devono semplificare la comprensione del concetto descritto.

{{CMS_NAME}} — GESTIONE PAGINE E LOCALIZZAZIONE
Ogni pagina deve essere valutata anche dal punto di vista implementativo nel CMS già integrato.

STRUTTURA DIRECTORY E PATTERN DI IMPLEMENTAZIONE
{{CMS_ROUTING_PATTERN}}

PATTERN UNICO — CMS con fallback hardcoded
{{CMS_FALLBACK_PATTERN}}

STRINGHE HARDCODED
{{I18N_PATTERN}}

Per ogni pagina devi verificare:
- se può essere costruita con i blocchi e i tipi pagina già esistenti;
- se richiede solo configurazione editoriale;
- se richiede nuovi blocchi;
- se richiede nuovi campi;
- se richiede un nuovo page type o un nuovo artefatto interno al CMS;
- se il nuovo artefatto è davvero necessario oppure evitabile riusando pattern esistenti.

Regola:
- proponi nuovi artefatti interni al CMS SOLO se realmente necessari;
- privilegia il riuso di blocchi e tipi pagina esistenti;
- segnala chiaramente quando una nuova entità CMS è opzionale, consigliata o necessaria.

LINGUA E LOCALIZZAZIONE
Ogni pagina deve essere prodotta in doppia lingua:
- {{LOCALE_PRIMARY}};
- {{LOCALE_SECONDARY}}.

La versione secondaria NON deve essere una traduzione meccanica o letterale se questo peggiora chiarezza o tono.
Le due versioni devono mantenere:
- stesso significato;
- stessa struttura;
- stesso posizionamento strategico;
- stesso livello qualitativo;
- stessa intenzione di conversione.

TERMINOLOGIA — regole obbligatorie
{{TERMINOLOGY_RULES}}

INPUT
Ti verranno forniti:
- la struttura editoriale del sito;
- il prompt specifico della pagina da generare;
- eventuale documentazione aggiuntiva.

SLUG E NAVIGAZIONE — fonte di verità
Gli slug di tutte le pagine sono fissi e già presenti nel CMS e nel database locale. Non inventare slug.
Usa esclusivamente quelli definiti nella struttura di navigazione qui sotto.

{{NAVIGATION_STRUCTURE}}

INTERPRETAZIONE DELLA STRUTTURA
Usa la struttura allegata come fonte di verità per:
- nome della pagina;
- collocazione nella navigazione;
- appartenenza a una macro-area;
- relazioni tra pagine;
- sezioni e sotto-sezioni;
- messaggi funzionali già presenti.

Non limitarti a copiare le descrizioni:
- sintetizza;
- raggruppa;
- riordina;
- migliora;
- rendi il contenuto adatto a un sito commerciale di alto livello.

PROCESSO OBBLIGATORIO
Segui esattamente questo processo:

FASE 1 — ANALISI PRELIMINARE
Per il perimetro richiesto:
- elenca le pagine coinvolte;
- individua ambiguità;
- individua eventuali contenuti troppo tecnici per il pubblico;
- individua sovrapposizioni tra pagine;
- segnala dove il valore non è espresso bene;
- proponi una rimodulazione per ciascun punto critico.

FASE 2 — MODELLO STRATEGICO PAGINA
Per ogni pagina definisci:
- page name;
- macro area;
- target audience primaria;
- target audience secondaria;
- consapevolezza dell'utente;
- obiettivo della pagina;
- promessa principale;
- messaggio chiave;
- differenziatori;
- relazione con altre pagine del sito;
- CTA primaria;
- CTA secondaria;
- prova/elementi di fiducia da inserire.

FASE 3 — STRUTTURA DELLA PAGINA
Per ogni pagina genera:
- hero;
- eventuale sottotitolo;
- overview/value proposition;
- sezioni principali;
- eventuali use case;
- eventuali moduli/funzionalità collegati;
- eventuale spiegazione processo;
- eventuali comparazioni;
- eventuale sezione FAQ;
- CTA finale;
- note visuali per ogni sezione.

FASE 4 — VALUTAZIONE CMS
Per ogni pagina indica:
- percorso file: {{CMS_FILE_PATH_PATTERN}};
- page type suggerito nel documento CMS;
- blocchi riusabili esistenti;
- blocchi mancanti o da creare;
- nuovi campi eventuali;
- necessità o meno di nuovi artefatti CMS (opzionale / consigliato / necessario);
- quali contenuti passano dal CMS come campo o blocco localizzato;
- quali stringhe sono nel componente hardcoded e richiedono voce nei file di traduzione;
- note per localizzazione {{LOCALE_PRIMARY}}/{{LOCALE_SECONDARY}};
- eventuali dipendenze editoriali.

FASE 5 — OUTPUT FINALE
Genera i file finali nel formato richiesto.

FORMATO OUTPUT
Devi generare:
- un file separato per ogni pagina effettivamente richiesta nel perimetro;
- ogni file deve contenere TUTTI i requisiti e le regole applicabili a quella pagina;
- ogni file deve essere autosufficiente, così da poter essere passato singolarmente a un'altra LLM o a un processo di generazione successivo.

Ogni file pagina deve contenere obbligatoriamente queste sezioni:

1. Page identity
- Nome pagina {{LOCALE_PRIMARY}} e {{LOCALE_SECONDARY}}
- Macro area
- Navigazione (posizione nel menu)
- URL slug {{LOCALE_PRIMARY}} (da struttura navigazione)
- URL slug {{LOCALE_SECONDARY}} (da struttura navigazione)
- Pattern CMS: statica / solo CMS / mista
- Lingue supportate

2. Strategic role
- Obiettivo della pagina
- Target
- Intento di ricerca / user intent
- Posizionamento nella customer journey
- Relazione con altre pagine

3. Public-facing content rules
- Cosa evidenziare
- Cosa evitare
- Cosa semplificare
- Cosa tradurre da tecnico a beneficio

4. Messaging framework
- Promessa principale
- Messaggio chiave
- Messaggi secondari
- Obiezioni da gestire
- Elementi di fiducia

5. Page architecture
- Hero
- Sezioni
- Sotto-sezioni
- Ordine consigliato
- CTA
- FAQ eventuali

6. Visual guidance
- Illustrazioni consigliate
- Grafici consigliati
- Tabelle consigliate
- Diagrammi consigliati
- Elementi da mostrare visivamente per facilitare la comprensione

7. Design system and UI notes
- Componenti da riusare dal design system
- Eventuali nuovi componenti suggeriti
- Vincoli di coerenza visiva
- Indicazioni di tono e densità informativa

8. CMS assessment
- Percorso file: {{CMS_FILE_PATH_PATTERN}}
- Page type suggerito nel documento CMS
- Blocchi riusabili esistenti
- Blocchi mancanti o da creare
- Nuovi campi eventuali
- Nuovo artefatto CMS (opzionale / consigliato / necessario)
- Contenuti gestiti dal CMS come campo o blocco localizzato
- Stringhe nel componente hardcoded → voce nei file di traduzione
- Note per localizzazione {{LOCALE_PRIMARY}}/{{LOCALE_SECONDARY}}
- Dipendenze editoriali

9. Localization
- Versione {{LOCALE_PRIMARY}}
- Versione {{LOCALE_SECONDARY}}
- Adattamenti terminologici
- Note di coerenza tra le due lingue

10. Final generation brief
- Brief finale pronto da usare per generare la pagina vera e propria

STILE DI SCRITTURA
- tono professionale, concreto, autorevole, chiaro;
- niente supercazzole marketing;
- niente claim vaghi;
- niente frasi generiche da SaaS template;
- niente tecnicismi inutili;
- privilegia chiarezza, struttura, beneficio, casi d'uso e differenziazione;
- scrivi come un team senior che conosce {{INDUSTRY}} e il pubblico {{TARGET_AUDIENCE}}.

REGOLE DI QUALITÀ
- Non appiattire pagine diverse sullo stesso schema se hanno scopi diversi.
- Non trattare tutte le pagine come feature pages.
- Non trattare tutte le pagine come landing adv.
{{QUALITY_RULES_PER_CATEGORY}}
- Ogni pagina deve far emergere perché scegliere {{PROJECT_NAME}}.
- Ogni pagina deve contribuire alla percezione di ecosistema integrato, non di offerta frammentata.

REGOLE DI SICUREZZA CONTENUTISTICA
Se nella struttura trovi espressioni che sembrano:
- troppo interne,
- troppo architetturali,
- troppo da team di prodotto,
- troppo da documentazione tecnica,
devi:
1. segnalarle;
2. spiegare perché non sono adatte al pubblico della pagina;
3. proporre una formulazione orientata al valore o all'uso.

OUTPUT OPERATIVO
Restituisci sempre in questo ordine:
1. Ambiguità e criticità da validare prima di procedere.
2. Elenco dei contenuti troppo tecnici da rimodulare.
3. Proposta di rimodulazione.
4. Piano delle pagine da generare nello scope richiesto.
5. File separati per ogni pagina.
6. Se full-site è troppo ampio, proponi una suddivisione migliore e fermati prima di degradare la qualità.

CONSEGNA
Ora analizza gli input forniti e procedi seguendo rigorosamente il processo sopra. L'output deve essere implementazione nel progetto {{SITE_FRONT_PATH}}: scrivi il codice reale, non un documento o un brief.


---

## REGOLA — GIT: WORKTREE E BRANCH

### Prima di iniziare

Verifica di operare su un branch dedicato nel worktree aperto. Non lavorare mai in HEAD detached.

**Passi obbligatori:**

1. Nel worktree aperto, controlla il branch corrente:
   ```
   git branch --show-current
   ```
2. Se il comando restituisce una stringa vuota, sei in HEAD detached: **non procedere**. Crea subito un branch dedicato:
   ```
   git checkout -b page/<nome-slug-pagina>
   ```
   Esempi: `git checkout -b page/chi-siamo`, `git checkout -b page/piattaforma-analytics`.
3. Se sei su `main`, `master` o un branch generico non dedicato a questa pagina, crea un branch specifico prima di iniziare.
4. Tutto il lavoro — file generati, modifiche, commit — deve avvenire esclusivamente su questo branch.

Non lavorare mai in HEAD detached: i commit in quello stato sono irraggiungibili dopo un cambio di contesto e rendono impossibile la revisione ordinata da parte del team.

**Perimetro dei commit — regola assoluta:**
Non committare mai su progetti o repository diversi da quello su cui stai lavorando, salvo che sia strettamente necessario e richiesto esplicitamente dal task. Ogni modifica va confinata al repository di destinazione del task corrente. Non trascinare commit su altri repository come effetto collaterale del lavoro sulla pagina.

### Al termine del lavoro

**Non eseguire nessun merge**, non chiudere nessun branch e non chiudere nessun worktree.

Lascia tutto esattamente dove si trova: il codice generato deve rimanere nel branch e nel worktree in cui è stato prodotto.

La revisione, il merge e la chiusura del branch/worktree sono operazioni che spettano al team e vengono eseguite separatamente, dopo la verifica del lavoro.

---

## CONTESTO PAGINA

**Pagina {{LOCALE_PRIMARY}}:** {{PAGE_NAME_PRIMARY}}
**Pagina {{LOCALE_SECONDARY}}:** {{PAGE_NAME_SECONDARY}}
**Percorso {{LOCALE_PRIMARY}}:** `{{PAGE_SLUG_PRIMARY}}`
**Percorso {{LOCALE_SECONDARY}}:** `{{PAGE_SLUG_SECONDARY}}`

---

## SPECIFICHE EDITORIALI — {{LOCALE_PRIMARY}}

{{EDITORIAL_SPECS_PRIMARY}}

---

## SPECIFICHE EDITORIALI — {{LOCALE_SECONDARY}}

{{EDITORIAL_SPECS_SECONDARY}}

---

## REGOLA — REGISTRAZIONE PAGINA IN {{CMS_NAME}}

Prima di considerare il lavoro completo, la pagina deve essere registrata nel CMS locale tramite uno script seed dedicato.

**Passi obbligatori:**

1. **Crea lo script seed**
   Nella repo del CMS — `{{CMS_REPO_PATH}}` — crea il file `scripts/seed-page-<nome>.ts` seguendo esattamente il pattern di `scripts/seed-page-<esempio>.ts`.

   Requisiti dello script:
   - Importa `getPayload` da `payload` con la config in `../src/payload.config.js`
   - Usa `overrideAccess: true` su tutte le operazioni
   - Logica upsert: `update` se la pagina esiste già, `create` altrimenti
   - Gestisci entrambe le locale `{{LOCALE_PRIMARY}}` e `{{LOCALE_SECONDARY}}`
   - Tenant slug: `{{TENANT_SLUG}}`
   - Dati della pagina:
     - slug {{LOCALE_PRIMARY}}: `<slug-primary>` — title {{LOCALE_PRIMARY}}: `<titolo-primary>`
     - slug {{LOCALE_SECONDARY}}: `<slug-secondary>` — title {{LOCALE_SECONDARY}}: `<titolo-secondary>`
     - `sections: []`
     - `_status: "published"`
     - `schemaType`: il page type corretto per questa pagina
     - `meta.title` e `meta.description` in entrambe le lingue

   Sostituisci tutti i segnaposto `<...>` con i dati reali della pagina.

2. **Esegui lo script**
   ```
   cd {{CMS_REPO_PATH}}
   npm tsx scripts/seed-page-<nome>.ts
   ```

3. **Verifica**
   Controlla che il processo termini con codice 0 e senza errori nel log.
   Se fallisce, analizza l'errore e correggilo prima di procedere.
   Verifica anche che la pagina sia raggiungibile via `getPageBySlug` dal sito front (`{{SITE_FRONT_PATH}}`) e che il fallback hardcoded funzioni correttamente quando il documento è privo di sezioni.

4. **Elimina lo script**
   Lo script non va committato: va creato, eseguito e rimosso senza lasciare traccia nel repository.

Non saltare questo passaggio: una pagina generata solo nel codice front senza corrispondente documento nel CMS locale è incompleta.
