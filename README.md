# GM-Rechte Manager (PowerShell)

Ein intelligentes, interaktives PowerShell-Skript zur automatisierten Verwaltung von Game-Master-Rechten auf einem FreeBSD-Server. Das Skript ermittelt den zugehörigen Login-Account vollautomatisch anhand des Ingame-Charakternamens, manipuliert die Spieldatenbank (MariaDB/MySQL) sicher aus der Windows-Konsole heraus und startet bei Bedarf die Server-Cores neu.

### Motivation & Ziel
In der Metin2-Datenbankstruktur verlangt die Tabelle `common.gmlist` zwingend sowohl den Account- als auch den Charakternamen. Das manuelle Suchen des Accounts über Datenbank-Tools sowie das anschließende Neustarten der Server-Cores über SSH ist extrem zeitaufwendig. 

Dieses Tool automatisiert den gesamten Workflow: **Man gibt nur noch den Charakternamen ein.** Das Skript übernimmt die relationale Suche im Hintergrund, verhindert durch ein temporäres Datei-Streaming jegliche Sonderzeichen-Konflikte (Escaping-Probleme) bei der SSH-Übertragung und wendet die Änderungen direkt an.

### Eingesetzte Technologien & Skills
* **Scripting & Automatisierung:** PowerShell (interaktive CLI, Datei-Streaming, Umgebungsvariablen)
* **Netzwerk & Protokolle:** Remote-Befehle via SSH, sicherer Dateitransfer via SCP
* **Datenbanken:** MySQL / MariaDB (Datenbank-Joins, `INSERT ON DUPLICATE KEY UPDATE`, `DELETE`)
* **Linux-Administration:** Prozesssteuerung unter FreeBSD, Automatisierung interaktiver Shell-Skripte (`sh index.sh`) mittels `printf`-Pipelines

---

## Kernfunktionen
* **Automatisierter Account-Lookup:** Führt beim Start einen automatischen `INNER JOIN` zwischen den Tabellen `player.player` und `account.account` aus, um den korrekten Login-Namen des Charakters zu ermitteln.
* **Sicheres Query-Handling:** Sensible Zugangsdaten und SQL-Befehle werden lokal im Windows-Temp-Ordner generiert (`mysql_login.cnf` / `gm_query.sql`), per SCP übertragen und nach der Ausführung auf beiden Systemen restlos gelöscht. Keine Klartext-Passwörter in der Prozessliste!
* **Rechte-Verwaltung:** Ermöglicht das gezielte Aktivieren (Setzen des höchsten Rangs `IMPLEMENTOR` inkl. Duplikatsprüfung via `ON DUPLICATE KEY`) oder das Deaktivieren (Löschen des Eintrags) eines Charakters.
* **Automatisierter Core-Neustart:** Optionale Steuerung der Serverfiles-Verwaltung (`index.sh`). Das Skript simuliert die Menüauswahl automatisiert, fährt die Spielkanäle (Cores) sauber herunter, wartet auf die Freigabe der Ports und fährt sie frisch hoch.

## Systemvoraussetzungen
1. **Windows Host:** Windows 10/11 mit installierter PowerShell und nativem SSH/SCP-Client.
2. **Server-Infrastruktur:** Laufender Metin2-Server auf FreeBSD-Basis mit installiertem MySQL/MariaDB-Server.
3. **SSH-Zugang:** Ein eingerichteter, passwortloser SSH-Key-Zugang zum FreeBSD-Server wird dringend empfohlen.

---

## Konfiguration & Anpassung
Vor der ersten Nutzung (oder vor der Kompilierung zur `.exe`) müssen die Variablen im Kopfbereich des Skripts angepasst werden:

```powershell
# --- KONFIGURATION (Deine Server-Daten) ---
$serverIp   = "IHRE_SERVER_IP"      # IP-Adresse des FreeBSD-Servers
$sshUser    = "Ihr_SSH_User"        # SSH-Benutzername (z. B. root)
$dbUser     = "Ihr_DB_User"         # MySQL-Root-User
$dbPassword = "Ihr_DB_Passwort"     # MySQL-Passwort
$serverPath = "/usr/home/game"      # Installationspfad der Serverfiles
```

## Nutzung / Deployment
Das Skript kann wahlweise als nackter Quellcode oder als kompilierte Windows-Anwendung ausgeführt werden:

1. Öffne die PowerShell im Ordner des Tools.
2. Starte das Skript via `.\gm_manager.ps1` oder öffne die kompilierte `gm_manager.exe`.
3. Gib den Charakternamen ein und wähle die gewünschte Aktion (Aktivieren/Deaktivieren). Den Rest erledigt das Skript vollautomatisch.

---
*Entwickelt von denneonblue – Fokus auf pragmatische IT-Lösungen, relationale Datenbank-Strukturen und Prozessautomatisierung.*
