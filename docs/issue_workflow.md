# Issue Workflow (VS Code + GitHub)

Kurzer Standard-Workflow für die tägliche Arbeit mit Issues.

## 1) Issue auswählen

- Öffne in VS Code die GitHub Issues View (Extension ist installiert).
- Wähle ein offenes Issue (z. B. `#2`).
- Prüfe Labels, Milestone und Acceptance Criteria.

## 2) Branch pro Issue

- Branch-Naming: `<issue-number>-<kurzer-slug>`
- Beispiel:

```bash
git checkout main
git pull --ff-only origin main
git checkout -b 2-implement-snapshot-lifecycle-analysis-mixed-taxprocedure-detection
```

## 3) Implementieren + lokal prüfen

- Änderungen nur für dieses Issue umsetzen.
- Relevante Checks laufen lassen (z. B. Docker-Testskripte).

## 4) Commit mit Issue-Referenz

- Referenzieren (Issue bleibt offen): `refs #2`
- Schließen bei Merge: `closes #2`

Beispiel:

```bash
git add -A
git commit -m "Implement mixed taxProcedure lifecycle analysis (refs #2)"
```

## 5) Push + Pull Request

```bash
git push -u origin 2-implement-snapshot-lifecycle-analysis-mixed-taxprocedure-detection
```

- PR gegen `main` öffnen.
- In PR-Beschreibung `Closes #2` setzen, wenn nach Merge geschlossen werden soll.

## 6) Nach Merge

```bash
git checkout main
git pull --ff-only origin main
git branch -d 2-implement-snapshot-lifecycle-analysis-mixed-taxprocedure-detection
```

Optional remote aufräumen:

```bash
git push origin --delete 2-implement-snapshot-lifecycle-analysis-mixed-taxprocedure-detection
```
