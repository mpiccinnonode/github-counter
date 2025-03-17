# GithubCounter
 Script Powershell per conteggiare e compilare un report delle contribuzioni su GitHub nell'arco di un mese su una specifica repository.

 ## Requisiti
 - ### Powershell v7 o superiore:
   Di default Windows ha pre-installata la versione 5, per l'esecuzione dello script è necessaria almeno la versione 7.5 [link](https://learn.microsoft.com/it-it/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)

- ### Variabile d'ambiente `GITHUB_TOKEN`:
  Dato che lo script ha necessità di interrogare le API di GitHub, è necessario impostare un token d'accesso personale come variabile d'ambiente Windows.
 La creazione del token è possibile tramite [la propria pagina profilo](https://github.com/settings/tokens) ed è importante assegnare tutti gli scope sotto la categoria `repo`.
 ![image](https://github.com/user-attachments/assets/9f4a03af-0e2b-4792-8d84-c0245ce1da4f)

  Una volta creato il token **copiarne il valore** e [impostarla come variabile d'ambiente](https://www.ilsoftware.it/focus/breve-guida-all-uso-delle-variabili-d-ambiente-in-windows_6792/).
 
  **IMPORTANTE:** usare come nome della variabile la stringa "GITHUB_TOKEN", altrimenti non verrà riconosciuta.

  _Nota:_ se si ha PowerToys installato, si può utilizzare l'utility "Variabili d'ambiente".

 ## Guida all'uso
 - ### Preparazione del report Excel
   Dopo aver clonato il repository, effettuare una copia del file _Report.template.xlsx_ e rinominarla in _Report.xlsx_. Questo passaggio è essenziale per ottenere una versione del report adatta all'elaborazione da parte dello script. Il file _Report.xlsx_ non verrà a prescindere incluso in eventuali commit.

 - ### Individuazione dei repository da analizzare
   Il template del report è attualmente impostato per accettare la scrittura dei mesi di Gennaio e Febbraio 2025. L'elenco dei repository a cui si ha contribuito nei rispettivi mesi è accessibile dalla propria pagina profilo sotto la sezione "Contribution activity": ![image](https://github.com/user-attachments/assets/2407739b-fc67-4141-8c14-8b1c6edaad82).

   Le sezioni evidenziate in giallo sono quelle da cui prendere i nomi dei repository interessate.

   **!IMPORTANTE!:** ogni repository deve essere preso **una sola volta per mese**; lo script effettua un incremento dei valori già presenti nelle celle del file, quindi eseguire lo stesso comando più volte per lo stesso mese per la stessa repo può falsarne il risultato

## Esecuzione dello script
Aprire in una sessione di **Powershell v7** la cartella in cui è stato clonato il repository e lanciare il comando formattato nel seguente modo: 

```
.\main.ps1 -Author {your_username} -Year {year} -Month {month} -RepoOwner {repo_owner} -RepoName {repo_name}
```

Quindi ad esempio:

```
.\main.ps1 -Author mpiccinnonode -Year 2025 -Month 02 -RepoOwner nodesoccoop -RepoName service-management-core
```

Attendere la fine dell'esecuzione e ripetere il processo per ogni repository su ogni mese.

_Nota:_ potrebbe volerci un po' su repository con molte contribution.
**! IMPORTANTE !:** durante l'esecuzione **NON APRIRE E NON TENERE APERTO** il file excel di destinazione, altrimenti la scrittura dei valori non andrà a buon fine.


 
