# Wioska AI

Projekt lokalnej symulacji wioski z autonomicznymi mieszkańcami. Każdy NPC ma własne potrzeby, charakter, umiejętności, ekwipunek i pamięć. Jeden lokalny model AI podejmuje decyzje mieszkańców, a symulacja wykonuje ruch i pracę zgodnie z zasadami świata.

## Status

Prototyp Godot 4 ma pięciu mieszkańców, potrzeby, transport surowców do wspólnego magazynu, budowanie, lokalną integrację z Ollamą oraz zapis pamięci i stanu gry. Instalator gry i automatyczne pobieranie modelu pozostają do zrobienia.

## Struktura

- `game/` — projekt Godot 4 i prototyp symulacji.
- `game/scripts/ollama_bridge.gd` — połączenie z lokalnym Ollama API.
- `assets/medieval-village-2.5d/` — paczka wioski z uprawami i animacjami pracy.
- `assets/fantasy-village-adventurers/` — alternatywny zestaw postaci, terenu i budynków.
- `assets/forest-foraging-icons/` — ikony jedzenia i przedmiotów do zbierania.
- `docs/project-design.md` — założenia projektu.
- `docs/roadmap.md` — etapy dalszej pracy.

Uruchomienie i wymagania AI opisuje [game/README.md](game/README.md).

## Ważne: licencje assetów

Każda paczka ma własną licencję. Repozytorium zawiera surowe pliki assetów, więc przed publicznym udostępnianiem sprawdź ograniczenia licencji. Jeśli repo ma pozostać publiczne, część surowych paczek może wymagać usunięcia lub przeniesienia do prywatnego repozytorium.
