# --- KONFIGURATION (Deine Server-Daten) ---
$serverIp   = "SERVER IP"
$sshUser    = "BENUTZER"
$dbUser     = "DB BENUTZER"
$dbPassword = "DB PASSWORT"

# Der exakte Pfad zu den Fliege-Serverfiles
$serverPath = "/usr/home/game" 
# ---------------------------------------------------------

Clear-Host
Write-Host "=== METIN2 GM-RECHTE MANAGER ===" -ForegroundColor Cyan

# ==========================================
# VORBEREITUNG: LOGIN-DATEI ERSTELLEN
# ==========================================
# Wir erstellen die Login-Datei sofort, damit auch die Such-Abfrage darauf zugreifen kann!
$loginConfig = @"
[client]
user=$dbUser
password=$dbPassword
"@

$localLoginPath = "$env:TEMP\mysql_login.cnf"
$loginConfig | Out-File -FilePath $localLoginPath -Encoding ascii -Force

Write-Host "Verbinde mit Server..." -ForegroundColor Cyan
scp $localLoginPath "${sshUser}@${serverIp}:/tmp/mysql_login.cnf"

# ==========================================
# 1. DATEN ABFRAGEN & ACCOUNT AUTOMATISCH SUCHEN
# ==========================================
$charName = Read-Host "Bitte Charakter-Name eingeben"
if ([string]::IsNullOrEmpty($charName)) {
    Write-Host "Fehler: Es muss ein Charakter-Name eingegeben werden!" -ForegroundColor Red
    # Aufräumen vor dem Beenden
    Remove-Item $localLoginPath -Force
    ssh "${sshUser}@${serverIp}" "rm /tmp/mysql_login.cnf"
    Exit
}

Write-Host "Suche passenden Account in der Datenbank..." -ForegroundColor Cyan

# SQL-Abfrage, um den Account-Namen anhand des Charakter-Namens zu finden
$lookupSql = "USE player; SELECT account.account.login FROM player INNER JOIN account.account ON player.account_id = account.account.id WHERE player.name = '$charName' LIMIT 1;"

# Temporäre Datei für die Such-Abfrage erstellen
$localLookupPath = "$env:TEMP\gm_lookup.sql"
$lookupSql | Out-File -FilePath $localLookupPath -Encoding ascii -Force

# Such-Datei auf den Server schieben
scp $localLookupPath "${sshUser}@${serverIp}:/tmp/gm_lookup.sql"

# MySQL ausführen (nutzt jetzt die bereits existierende mysql_login.cnf!)
$sshResult = ssh "${sshUser}@${serverIp}" "mysql --defaults-extra-file=/tmp/mysql_login.cnf -N -B < /tmp/gm_lookup.sql"

# Suchdatei lokal und auf Server löschen
Remove-Item $localLookupPath -Force
ssh "${sshUser}@${serverIp}" "rm /tmp/gm_lookup.sql"

# Prüfen, ob die SSH-Abfrage erfolgreich war und nicht NULL ist
if ($null -eq $sshResult) {
    Write-Host "Fehler: Keine Antwort vom Datenbanksystem erhalten!" -ForegroundColor Red
    Remove-Item $localLoginPath -Force
    ssh "${sshUser}@${serverIp}" "rm /tmp/mysql_login.cnf"
    Exit
}

$accountName = $sshResult.Trim()

# Prüfen, ob ein Accountname gefunden wurde
if ([string]::IsNullOrWhiteSpace($accountName)) {
    Write-Host "Fehler: Kein Account für den Charakter '$charName' gefunden! Existiert der Charakter?" -ForegroundColor Red
    Remove-Item $localLoginPath -Force
    ssh "${sshUser}@${serverIp}" "rm /tmp/mysql_login.cnf"
    Exit
}

Write-Host "Gefundener Account: $accountName" -ForegroundColor Green

# ==========================================
# 2. AKTION AUSWÄHLEN
# ==========================================
Write-Host "`nWas möchtest du tun?" -ForegroundColor Yellow
Write-Host "1) GM-Rechte AKTIVIEREN (IMPLEMENTOR)"
Write-Host "2) GM-Rechte DEAKTIVIEREN (LÖSCHEN)"
$wahl = Read-Host "Auswahl (1 oder 2)"

# ==========================================
# 3. SQL-BEFEHL VORBEREITEN
# ==========================================
if ($wahl -eq "1") {
    $sql = "USE common; INSERT INTO gmlist (mAccount, mName, mAuthority) VALUES ('$accountName', '$charName', 'IMPLEMENTOR') ON DUPLICATE KEY UPDATE mAuthority='IMPLEMENTOR';"
    $aktionText = "Aktivierung"
} elseif ($wahl -eq "2") {
    $sql = "USE common; DELETE FROM gmlist WHERE mAccount='$accountName' AND mName='$charName';"
    $aktionText = "Deaktivierung"
} else {
    Write-Host "Ungültige Auswahl! Vorgang abgebrochen." -ForegroundColor Red
    Remove-Item $localLoginPath -Force
    ssh "${sshUser}@${serverIp}" "rm /tmp/mysql_login.cnf"
    Exit
}

# ==========================================
# 4. RECHTE AKTUALISIEREN
# ==========================================
Write-Host "`nBereite SQL-Befehl vor..." -ForegroundColor Cyan

$localSqlPath = "$env:TEMP\gm_query.sql"
$sql | Out-File -FilePath $localSqlPath -Encoding ascii -Force

# SQL-Datei rüberschieben
scp $localSqlPath "${sshUser}@${serverIp}:/tmp/gm_query.sql"

Write-Host "Aktualisiere Datenbank..." -ForegroundColor Cyan
ssh "${sshUser}@${serverIp}" "mysql --defaults-extra-file=/tmp/mysql_login.cnf < /tmp/gm_query.sql"

# SQL-Datei aufräumen
Remove-Item $localSqlPath -Force
ssh "${sshUser}@${serverIp}" "rm /tmp/gm_query.sql"

# Finale Löschung der Login-Konfiguration
Remove-Item $localLoginPath -Force
ssh "${sshUser}@${serverIp}" "rm /tmp/mysql_login.cnf"

Write-Host "Datenbank-Eintrag wurde aktualisiert!" -ForegroundColor Green

# ==========================================
# 5. DIE RELOAD-ABFRAGE
# ==========================================
Write-Host "`nMöchtest du die Server-Rechte jetzt direkt neu laden?" -ForegroundColor Yellow
Write-Host "1) Ja, Spieldienste (Cores) kurz neustarten (~30 Sek)"
Write-Host "2) Nein, später manuell machen"
$reloadWahl = Read-Host "Auswahl (1 oder 2)"

if ($reloadWahl -eq "1") {
    Write-Host "`nStoppe Server-Cores via index.sh..." -ForegroundColor Magenta
    ssh "${sshUser}@${serverIp}" "cd $serverPath && printf '2\n1\ny\n' | sh index.sh"
    
    Write-Host "Warte darauf, dass die Cores vollständig herunterfahren..." -ForegroundColor Yellow
    Start-Sleep -Seconds 12
    
    Write-Host "Starte Server-Cores neu via index.sh..." -ForegroundColor Magenta
    ssh "${sshUser}@${serverIp}" "cd $serverPath && printf '1\n1\ny\n' | sh index.sh"
    
    Write-Host "Server-Cores wurden neu gestartet! Logge dich neu ein, die Rechte sollten jetzt aktiv sein." -ForegroundColor Green
}
else {
    Write-Host "`nAlles klar, vergiss nicht, den Reload später manuell im Spiel (/reload p) zu machen!" -ForegroundColor Gray
}

Write-Host "`n=== Vorgang beendet ===" -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force
