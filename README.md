# Wioska AI

Projekt lokalnej symulacji wioski z autonomicznymi mieszkańcami. Każdy NPC ma własne potrzeby, charakter, umiejętności, ekwipunek i pamięć. Docelowo jeden lokalny model AI będzie podejmował decyzje mieszkańców, a symulacja wykona ruch i pracę zgodnie z zasadami świata.

## Status

Repozytorium zawiera pierwszy prototyp w Godot 4: pięciu mieszkańców, potrzeby, prace, wspólny magazyn, budowanie i log zdarzeń. Integracja AI z Ollamą oraz instalator są kolejnymi etapami.

## Struktura

- `game/` — projekt Godot 4 i prototyp symulacji.
- `assets/medieval-village-2.5d/` — paczka wioski z uprawami i animacjami pracy.
- `assets/fantasy-village-adventurers/` — alternatywny zestaw postaci, terenu i budynków.
- `assets/forest-foraging-icons/` — ikony jedzenia i przedmiotów do zbierania.
- `docs/project-design.md` — założenia projektu.
- `docs/roadmap.md` — etapy dalszej pracy.

Uruchomienie prototypu opisuje [game/README.md](game/README.md).

## Ważne: licencje assetów

Każda paczka ma własną licencję. Repozytorium zawiera surowe pliki assetów, więc przed publicznym udostępnianiem sprawdź ograniczenia licencji. Jeśli repo ma pozostać publiczne, część surowych paczek może wymagać usunięcia lub przeniesienia do prywatnego repozytorium.
