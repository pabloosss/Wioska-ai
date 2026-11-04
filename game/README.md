# Wioska AI — prototyp

Projekt Godot 4 z automatycznym przygotowaniem lokalnego AI.

## Uruchomienie

1. Zainstaluj Godot 4 i otwórz projekt z `game/project.godot`.
2. Naciśnij **F5**.
3. Przy pierwszym uruchomieniu gra sprawdzi, czy Ollama już działa. Jeśli nie, sama pobierze przenośny runtime, uruchomi go i pobierze model `qwen3.5:35b`.

Nie musisz osobno instalować Ollamy ani ręcznie pobierać modelu. Pierwsze przygotowanie wymaga internetu i wolnego miejsca na dysku. Model 35B zajmuje dużo miejsca, a pobieranie może potrwać.

## Sterowanie

- **Spacja** — pauza/wznowienie.
- **1–5** albo kliknięcie mieszkańca — wybór postaci.
- **F2** lub przycisk **Ustawienia AI** — otwarcie ustawień.
- **R** — ponowne sprawdzenie i wznowienie przygotowania AI.

## Panel gry

- **Wioska** — zadania wszystkich mieszkańców, wybrana postać, potrzeby, ładunek, sprzęt, umiejętność, uzasadnienie AI i wspomnienia. Długie informacje można przewijać.
- **AI / wydajność** — status i model, czas bieżącej oraz ostatniej odpowiedzi, licznik zapytań i błędów, przyjęte decyzje, czas do kolejnego zapytania.
- **Dziennik** — ostatnie 100 zdarzeń, przewijanie i czyszczenie widoku.
- Przyciski pauzy, ręcznego zapisu oraz tempo symulacji 0.5× / 1× / 2×.

## Ustawienia AI i wydajność

W zakładce AI ustaw przerwę po odpowiedzi (10, 30, 60 lub 120 sekund czasu rzeczywistego), limit 30/60 FPS, liczbę wątków CPU modelu i długość odpowiedzi. Naciśnij **Zastosuj wydajność**, aby zapisać ustawienia. Limit wątków CPU nie ogranicza wykorzystania GPU.

Domyślnie po odpowiedzi jest 30 sekund przerwy. Przy wolnej odpowiedzi przerwa wynosi co najmniej połowę czasu generowania. W danej chwili jest najwyżej jedno zapytanie. Limit oczekiwania na decyzje to 120 sekund; pobieranie modelu ma osobny tryb bez tego limitu. Kontekst modelu jest ograniczony do 4096 tokenów.

**Zaplanuj teraz** pomija przerwę, jeśli AI jest gotowe i wolne. **Przerwij** przerywa oczekiwanie klienta; Ollama może jeszcze kończyć obliczenia. Wyłączenie nowych decyzji zachowuje dotychczasowe zadania mieszkańców.

F2 otwiera ustawienia modelu, priorytetu wioski, swobody odpowiedzi i własnych wskazówek. Lista modeli pokazuje modele z lokalnej Ollamy.

## Jak działa AI

- Jeden model wybiera zadania dla mieszkańców: zbieranie jedzenia, drewna, budowę, dostawę, jedzenie, odpoczynek, ogrzanie lub oczekiwanie.
- Gra wykonuje ruch i kolejne kroki wybranego zadania. Zbieranie obejmuje dostarczenie pełnego ładunku do magazynu.
- Gra nie wybiera zastępczego zadania w razie braku decyzji. AI widzi potrzeby, zapasy, aktualne zadania i ostatnie wspomnienia.
- Dane sieciowe są odbierane w wątku HTTPRequest. Interfejs informacyjny odświeża się dwa razy na sekundę, a zapis świata odbywa się co 30 sekund, na żądanie i przy zamknięciu okna.
- Model 35B nadal może obciążać GPU; ograniczenia gry nie stanowią limitu pamięci ani wykorzystania GPU Ollamy.

## Weryfikacja tej wersji

Godot 4.6.3: uruchomiono scenę i panel z testowym serwerem HTTP udającym Ollamę. Sprawdzono opóźnioną odpowiedź, brak kolejnego zapytania w okresie przerwy, jednorazowe jedzenie, wymóg dojścia do magazynu, fizyczną dostawę, zapis i ustawienia. Nie jest to pomiar wydajności prawdziwego modelu na Windows.

## Ograniczenia prototypu

Automatyczne pobieranie runtime'u Ollamy i modelu jest przygotowane dla Windows. Gra działa obecnie z poziomu edytora Godot; samodzielny instalator/plik EXE do udostępniania powstanie w kolejnym etapie. Wagi modelu nie są częścią repozytorium.
