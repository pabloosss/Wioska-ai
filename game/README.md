# Wioska AI 0.2 — wykonawca planów AI

## Aktualizacja i uruchomienie

Pobierz cały folder `game`, także nowe skrypty. Otwórz `project.godot` w Godot 4 i naciśnij F5. Nie trzeba ręcznie instalować Ollamy: na Windows gra przygotuje runtime i pobierze wybrany model. Pierwszy start wymaga internetu. Na innych systemach połączenie działa z już uruchomioną lokalną Ollamą.

Nowe instalacje domyślnie używają `qwen3:4b-instruct`. Istniejący wybór modelu zostaje zachowany. Jeśli poprzednio wybrano 35B i komputer się zacina, w zakładce **Opcje** wybierz **Szybki model: qwen3:4b-instruct**. Gra wyśle żądanie zwolnienia poprzedniego modelu, sprawdzi nowy i pobierze go, jeżeli go brakuje. Poczekaj na zakończenie bieżącego zapytania przed zmianą modelu.

## Dlaczego mieszkańcy kończą teraz dostawę

AI wybiera do trzech kolejnych zadań dla wolnych mieszkańców. Jedno zadanie zbierania ma etapy: dojście → zbiór 4 jednostek → powrót z widocznym ładunkiem → oddanie do magazynu. Stan magazynu zmienia się dopiero po dotarciu postaci. Nowa odpowiedź modelu nie może przerywać aktywnego zadania. Każdy plan jest przypisany do wersji stanu mieszkańca; spóźnione odpowiedzi są odrzucane.

Gra nie wybiera zastępczej pracy. Jeśli nie ma poprawnego planu, mieszkaniec czeka. Błędna decyzja (np. jedzenie przy pustym magazynie i braku własnej porcji) kończy zadanie z wynikiem przekazywanym AI. Model może zaplanować kolejne działanie. Polecenie jedzenia oznacza jedną porcję. Prywatne jedzenie i ładunek nie są automatycznie zawartością wspólnego magazynu.

## Widoczność AI i sterowanie

Stały pasek u góry pokazuje stan AI, model, czas trwającego zapytania i limit, ostatni przyjęty plan oraz FPS. Znalezienie modelu nie jest przedstawiane jako dowód poprawnych decyzji. Błąd modelu pozostaje widoczny na głównym ekranie.

- **Mieszkańcy**: aktualne zadania, potrzeby, ładunki, rzeczy prywatne, powód decyzji, kolejne kroki i wspomnienia.
- **AI**: czas odpowiedzi, liczba zapytań, błędów, przyjętych planów i oczekujących osób.
- **Opcje**: model, automatyczne pobieranie lekkiego modelu, przerwa 10–120 s, limit 30/60 FPS, timeout 45/120 s, wskazówki dla AI, widoczność trasy i eksport diagnostyki.
- **Dziennik**: ostatnie 160 zdarzeń.
- **Spacja**: pauza. **1–5** lub kliknięcie: wybór postaci. **F2**: opcje.
- Na górnym pasku: tempo 0.5× / 1× / 2×, ręczny plan, ponowne połączenie i zapis.

Wyłączenie AI zatrzymuje nowe zapytania; już otrzymane plany są kończone. Pauza zatrzymuje świat. Przycisk „Zaplanuj teraz” nie przerywa aktywnych zadań i nie dodaje równoległych zapytań.

## Obciążenie i zapis

Symulacja pracuje ze stałym krokiem 20 Hz, interfejs tekstowy 4 Hz. Zapytania sieciowe oraz weryfikacja i rozpakowanie pobranego runtime'u pracują poza wątkiem renderowania. Model ma kontekst 4096 tokenów i limit odpowiedzi 1024 tokenów. Nie ma kolejki równoległych zapytań. Jeśli wszyscy mają plan, AI nie dostaje następnego zapytania. Domyślna przerwa to 20 sekund po odpowiedzi; wolne odpowiedzi mogą ją wydłużyć. Duży model nadal może obciążać CPU/GPU systemu — limit FPS gry nie jest ograniczeniem mocy Ollamy.

Autozapis co 30 sekund oraz przy zamknięciu. Zapis przez plik tymczasowy, z kopią poprzedniego pliku `.bak`. Stare zapisy są wczytywane z zachowaniem zapasów, potrzeb, ładunków i rzeczy prywatnych. Stare pozycje są ograniczane do widocznej mapy. Nowe zapisy przechowują aktywne polecenie i kolejkę AI; po wczytaniu mieszkaniec wznawia polecenie z zachowanym ładunkiem. Praca przy zbiorze/budowie może rozpocząć swój etap od początku; nie powiela to zasobów.

Eksport diagnostyki zapisuje lokalny plik `wioska_diagnostyka.txt` i otwiera folder danych gry. Nic nie jest wysyłane automatycznie.

## Architektura

- `scripts/simulation.gd`: stan świata, skończone zadania, transport, potrzeby i zapis; bez sieci i interfejsu.
- `scripts/ollama_bridge.gd`: przygotowanie lokalnego silnika, HTTP, walidacja odpowiedzi, timeout i metryki.
- `scripts/village.gd`: harmonogram zapytań i integracja.
- `scripts/world_view.gd`: rysowanie świata i zaznaczanie mieszkańców.
- `scripts/village_ui.gd`: stały status, zakładki i ustawienia.

## Testy

Z folderu `game`:

```sh
godot --headless --path . --script res://tests/test_simulation.gd
godot --headless --path . --script res://tests/test_bridge.gd
python tests/mock_ollama.py
```

Test integracyjny wymaga wolnego portu 11434 i używa tymczasowego folderu danych na Linuksie. Nie uruchamiaj go obok prawdziwej Ollamy. Testy nie pobierają modelu.

W Godot 4.6.3 sprawdzono pełne cykle zbioru i transportu dla pięciu NPC, pojedyncze posiłki, budowę, plan trzyetapowy, odrzucanie starych decyzji, zapis z ładunkiem, odpowiedzi opóźnione/błędne i timeout, zmianę modelu, status na wszystkich zakładkach, wymiary panelu i rozpakowanie w tle. Testowy serwer nie mierzy jakości prawdziwego modelu ani wydajności Windows/GPU użytkownika.

## Ograniczenia

To nadal prototyp: mapa używa czytelnych figur, bez podłączonych paczek animacji; brak kolizji i szukania ścieżek między przeszkodami. Nie ma jeszcze gotowego EXE/instalatora, pełnej ekonomii ani rozwoju populacji. Nowa struktura oddziela te obszary od połączenia AI i interfejsu.
