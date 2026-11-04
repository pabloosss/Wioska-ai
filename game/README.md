# Wioska AI 0.4 — żywa osada, rodziny i zagrożenia

## Aktualizacja i uruchomienie

Pobierz cały folder `game`, także nowe skrypty. Otwórz `project.godot` w Godot 4 i naciśnij F5. Nie trzeba ręcznie instalować Ollamy: na Windows gra przygotuje runtime i pobierze wybrany model. Pierwszy start wymaga internetu. Na innych systemach połączenie działa z już uruchomioną lokalną Ollamą.

Nowe instalacje domyślnie używają `qwen3:4b-instruct`. Istniejący wybór modelu zostaje zachowany. Jeśli poprzednio wybrano 35B i komputer się zacina, w zakładce **Opcje** wybierz **Szybki model: qwen3:4b-instruct**. Gra wyśle żądanie zwolnienia poprzedniego modelu, sprawdzi nowy i pobierze go, jeżeli go brakuje. Poczekaj na zakończenie bieżącego zapytania przed zmianą modelu.

## Życie osady w wersji 0.4

Mieszkańcy mają zdrowie, wiek, potrzebę kontaktu, relacje, cel osobisty i rodzinę. AI może zmieniać zawód dorosłego: zbieracz, drwal, budowniczy, rolnik, strażnik lub opiekun. Każdy nadal sam otrzymuje plan i uzasadnienie; gra wykonuje skończone działania i sprawdza ich warunki.

- **Domy:** cztery miejsca na dom. Na początku pięć osób mieszka w jednym domu, więc potrzebna jest rozbudowa. Bez miejsca odpoczynek działa wolniej, a schronienie nie chroni. Ciąża rezerwuje dodatkowe miejsce.
- **Żywność:** jagody mają limit 60 i powoli odrastają (0,04 porcji/s). Po ich wyczerpaniu AI może wybrać uprawę pola: 4 porcje za 1 drewno na narzędzia. Plon trafia do magazynu dopiero po fizycznej dostawie.
- **Rozmowy:** `socialize` wymaga wskazania mieszkańca w `target`. Postać podchodzi do rozmówcy; udane spotkanie poprawia obustronną więź o 15 i zaspokaja kontakt. Jeśli rozmówca odszedł, wynik porażki wraca do AI.
- **Nauka:** `learn` wymaga dorosłego nauczyciela w `target`. Daje 5 XP tylko wtedy, gdy nauczyciel ma wyższy poziom danej umiejętności. Dzieci mogą się uczyć, lecz nie zbierają drewna, nie budują i nie walczą.
- **Własne cele:** model może zapisać `goal` i zmienić `job`. Cele, relacje i ważne wydarzenia są zachowywane w pamięci i zapisie gry. To nie jest trenowanie wag modelu.

### Rodziny i dzieci

`start_family` wymaga **dwóch osobnych, wzajemnych decyzji AI** dorosłej kobiety i dorosłego mężczyzny w ciągu jednej doby gry. Najpierw każda z relacji musi osiągnąć 50; rodzice muszą mieć zdrowie ≥60, sytość ≥50 i wypoczęcie ≥40. Potrzebne są wolne miejsce, rezerwa co najmniej `2 × liczba mieszkańców + 4` porcji, włączone rodziny, brak alarmu i wolny limit populacji. Bliskie pokrewieństwo jest sprawdzane do trzech pokoleń. Inny partner, trwająca ciąża lub okres po narodzinach blokują nową ciążę.

Domyślnie dziecko rodzi się po **3 dobach gry**, a dorasta przez **12 dób**. To umownie przyspieszony cykl życia. Początkowo doba trwa 4 minuty przy tempie 1×. Każde dziecko ma własne potrzeby, rodziców, więzi, pamięć i umiejętności. Po osiągnięciu dorosłości AI może wybrać mu zawód. Po narodzinach rodzice mają 3 doby przerwy przed kolejną ciążą.

Limit dotyczy rozpoczęcia nowych ciąż, z uwzględnieniem już oczekiwanych dzieci. Wyłączenie rodzin lub obniżenie limitu **nie przerywa istniejących ciąż**. Wczytanie gry zachowuje nowych mieszkańców i cały postęp oczekiwania na dziecko.

### Zagrożenia i pomoc

Pierwsze automatyczne zagrożenie może pojawić się po 8 minutach symulacji; następne zdarzenia są oddzielone dwiema dobami spokoju. Burze i wilki występują naprzemiennie. Alarm jest widoczny na mapie i w panelu osady. Usuwa niezaczęte kroki planów i unieważnia wcześniejsze odpowiedzi AI; bieżący transport kończy się normalnie.

- **Burza:** szybciej wychładza osoby poza domem. AI może wybrać `shelter` lub ogrzewanie.
- **Wilki:** ranią odsłoniętych mieszkańców i mogą zabrać część zapasów. `guard` oznacza dojście na wartę i odstraszanie; każde ukończenie zmniejsza siłę stada o 3. Zwykła warta trwa 12 sekund.
- **Leczenie:** `heal` zabiera dwie porcje z magazynu, następnie mieszkaniec niesie je do wskazanej osoby i udziela pomocy. Zdrowie rośnie o 30, sytość o 20. Bez `target` leczy siebie. Zapis w trakcie transportu zachowuje zabrane porcje i nie nalicza kosztu ponownie.
- **Wyczerpanie:** skrajny głód i zimno obniżają zdrowie. Poniżej 30 zdrowia chodzenie jest wolniejsze. Zdrowie powoli odnawia się przy dobrym zaspokojeniu potrzeb.
- **Śmiertelność:** domyślnie wyłączona, zdrowie zatrzymuje się na 1. Po jej włączeniu zerowe zdrowie oznacza trwałą śmierć; historia zmarłego zostaje zachowana.

### Opcje świata i interfejs

Domyślny widok **Osada** pokazuje populację, dzieci, rodziny, brakujące miejsca, rezerwę jedzenia, alarmy i podział pracy. Widoki wybiera się z listy nad panelem; lista mieszkańców automatycznie obejmuje nowo narodzonych. W inspektorze są paski zdrowia i kontaktu, wiek, rodzina i cel. Mapa pokazuje pole, wartę, stan jagód, dzieci, osoby ranne oraz alarm.

W **Opcjach** można ustawić: zagrożenia, ich siłę (3 poziomy), nowe ciąże, śmiertelność, psucie żywności, limit 5–20 mieszkańców, długość doby, czas ciąży, czas dorastania i tempo zużywania potrzeb 25–200%. Zasady świata zapisuje się osobnym przyciskiem. Przyciski scenariuszy wywołują burzę albo wilki w aktualnej osadzie; skutki są rzeczywiste i trafiają do zapisu.

Dodatkowa opcja AI określa **2, 3 albo 5 mieszkańców w jednym zapytaniu**. Domyślnie jest 3; rotacja zaczyna od osób najdłużej bez przyjętego planu. Nadal działa tylko jedno zapytanie naraz. Wariant 5 osób używa większego kontekstu i może zużywać więcej pamięci.

## Dlaczego mieszkańcy kończą teraz dostawę

AI wybiera do trzech kolejnych zadań dla wolnych mieszkańców. Jedno zadanie zbierania ma etapy: dojście → zbiór 4 jednostek → powrót z widocznym ładunkiem → oddanie do magazynu. Stan magazynu zmienia się dopiero po dotarciu postaci. Nowa odpowiedź modelu nie może przerywać aktywnego zadania. Każdy plan jest przypisany do wersji stanu mieszkańca; spóźnione odpowiedzi są odrzucane.

Gra nie wybiera zastępczej pracy. Jeśli nie ma poprawnego planu, mieszkaniec czeka. Błędna decyzja (np. jedzenie przy pustym magazynie i braku własnej porcji) kończy zadanie z wynikiem przekazywanym AI. Model może zaplanować kolejne działanie. Polecenie jedzenia oznacza jedną porcję. Prywatne jedzenie i ładunek nie są automatycznie zawartością wspólnego magazynu.

## Widoczność AI i sterowanie

Stały pasek u góry pokazuje stan AI, model, czas trwającego zapytania i limit, ostatni przyjęty plan oraz FPS. Znalezienie modelu nie jest przedstawiane jako dowód poprawnych decyzji. Błąd modelu pozostaje widoczny na głównym ekranie.

- **Postać**: aktualne zadanie, paski potrzeb, ładunek, rzeczy prywatne, powód decyzji i kolejne kroki. Wybór mieszkańca jest wspólny dla wszystkich zakładek.
- **Pamięć**: trwałe wnioski, osobiste dostawy, udane/nieudane działania oraz 40 ostatnich wspomnień.
- **Rozwój**: osobne poziomy, paski XP i osiągnięcia zbieractwa, drwalstwa oraz budowania.
- **AI**: czas odpowiedzi, liczba zapytań, błędów, przyjętych planów i oczekujących osób.
- **Opcje**: model, automatyczne pobieranie lekkiego modelu, przerwa 10–120 s, limit 30/60 FPS, timeout 45/120 s, wskazówki dla AI, widoczność trasy i eksport diagnostyki.
- **Log**: ostatnie 160 zdarzeń.
- **Spacja**: pauza. **1–5** lub kliknięcie: wybór postaci. **F2**: opcje.
- Na górnym pasku: tempo 0.5× / 1× / 2×, ręczny plan, ponowne połączenie i zapis.

Wyłączenie AI zatrzymuje nowe zapytania; już otrzymane plany są kończone. Pauza zatrzymuje świat. Przycisk „Zaplanuj teraz” nie przerywa aktywnych zadań i nie dodaje równoległych zapytań.

## Pamięć i nauka przez doświadczenie

Każdy mieszkaniec ma własną historię. Ukończone zadania i porażki tworzą wspomnienia. Ostatnich 40 zdarzeń można przeglądać w panelu, a trwałe wnioski oraz sumy udanych i nieudanych działań pozostają po usunięciu starszych zdarzeń z tej listy. Osobno liczone są dostarczone porcje jedzenia i sztuki drewna.

Wnioski powstają z faktycznych wyników: np. nieudany posiłek przy pustym magazynie zostawia informację, że najpierw trzeba zdobyć jedzenie. Model otrzymuje ograniczony skrót: maksymalnie dwa wnioski o porażkach, jeden istotny poznany fakt, dwa ostatnie zdarzenia oraz ukończone prace i poziomy umiejętności. Wielkość kontekstu nie rośnie bez końca. To pamięć i rozwój w symulacji, bez trenowania wag modelu.

## Umiejętności

- Pełny zbiór zakończony dostawą: **10 XP** do zbieractwa lub drwalstwa.
- Ukończony etap budowy: **12 XP** do budowania.
- Posiłki, odpoczynek, czekanie i nieudane zadania nie dają XP do pracy.
- Pierwszy awans wymaga **30 XP**, kolejne progi rosną o 20 XP. Maksymalny poziom to **10**.
- Każdy poziom powyżej pierwszego zwiększa szybkość odpowiedniej pracy o **8%**, maksymalnie o 72%. Nie zwiększa prędkości chodzenia ani ilości surowca.
- Poziomy są niezależne: zbieranie jedzenia nie rozwija budowania. Każdy NPC może zdobywać wszystkie trzy umiejętności.

Zapis wersji 4 przechowuje dodatkowo rodziny, populację, stan zagrożeń i zasady świata. Zachowuje też pamięć, poziomy, XP i osiągnięcia. Przy wczytaniu starego zapisu ogólny poziom jest przypisany do umiejętności dotychczasowego zawodu, a stare wspomnienia trafiają do historii. Brak dawnych liczników dostaw nie jest uzupełniany wymyślonymi wartościami.

## Obciążenie i zapis

Symulacja pracuje ze stałym krokiem 20 Hz, interfejs tekstowy 4 Hz. Zapytania sieciowe oraz weryfikacja i rozpakowanie pobranego runtime'u pracują poza wątkiem renderowania. Model ma kontekst 4096 tokenów dla grupy do 3 osób lub 8192 dla 5 osób i limit odpowiedzi 1024 tokenów. Nie ma kolejki równoległych zapytań. Jeśli wszyscy mają plan, AI nie dostaje następnego zapytania. Domyślna przerwa to 20 sekund po odpowiedzi; wolne odpowiedzi mogą ją wydłużyć. Duży model nadal może obciążać CPU/GPU systemu — limit FPS gry nie jest ograniczeniem mocy Ollamy.

Autozapis co 30 sekund oraz przy zamknięciu. Zapis przez plik tymczasowy, z kopią poprzedniego pliku `.bak`. Stare zapisy są wczytywane z zachowaniem zapasów, potrzeb, ładunków i rzeczy prywatnych. Stare pozycje są ograniczane do widocznej mapy. Nowe zapisy przechowują aktywne polecenie i kolejkę AI; po wczytaniu mieszkaniec wznawia polecenie z zachowanym ładunkiem. Praca przy zbiorze/budowie może rozpocząć swój etap od początku; nie powiela to zasobów.

Eksport diagnostyki zapisuje lokalny plik `wioska_diagnostyka.txt` i otwiera folder danych gry. Nic nie jest wysyłane automatycznie.

## Architektura

- `scripts/simulation.gd`: stan świata, skończone zadania, transport, potrzeby i zapis; bez sieci i interfejsu.
- `scripts/village_life.gd`: relacje, rodziny, wiek, zdrowie, zagrożenia i zasady świata.
- `scripts/ollama_bridge.gd`: przygotowanie lokalnego silnika, HTTP, walidacja odpowiedzi, timeout i metryki.
- `scripts/village.gd`: harmonogram zapytań i integracja.
- `scripts/world_view.gd`: rysowanie świata i zaznaczanie mieszkańców.
- `scripts/village_ui.gd`: stały status, zakładki i ustawienia.

## Testy

Z folderu `game`:

```sh
godot --headless --path . --script res://tests/test_simulation.gd
godot --headless --path . --script res://tests/test_bridge.gd
godot --headless --path . --script res://tests/test_progression.gd
godot --headless --path . --script res://tests/test_village_life.gd
python tests/mock_ollama.py
```

Test integracyjny wymaga wolnego portu 11434 i używa tymczasowego folderu danych na Linuksie. Nie uruchamiaj go obok prawdziwej Ollamy. Testy nie pobierają modelu.

W wersji 0.4 dodatkowo sprawdzono wzajemną decyzję o rodzinie, narodziny, dorastanie, ograniczenia dzieci, zapis dynamicznej populacji, brak jagód, uprawę i transport plonu, burze i domy, wilki i wartę, leczenie wraz ze wznowieniem transportu zapasów, opcjonalną śmiertelność, rotację planowania i ustawienia świata. Test 20 NPC sprawdza równoczesne dostawy i rozliczenie 80 sztuk drewna.

W Godot 4.6.3 sprawdzono pełne cykle zbioru i transportu dla pięciu NPC, pojedyncze posiłki, budowę, plan trzyetapowy, odrzucanie starych decyzji, zapis z ładunkiem, odpowiedzi opóźnione/błędne i timeout, zmianę modelu, status na wszystkich zakładkach, wymiary panelu i rozpakowanie w tle. Dodatkowo sprawdzono przyznawanie XP, niezależność umiejętności, wzrost szybkości w wykonywanej symulacji, limit poziomów, trwałe wnioski po wyparciu starych zdarzeń, pamięć przekazywaną do AI, migrację zapisów i widoki pamięci/rozwoju dla wybranej postaci. Testowy serwer nie mierzy jakości prawdziwego modelu ani wydajności Windows/GPU użytkownika.

## Ograniczenia

To nadal prototyp: mapa używa czytelnych figur, bez podłączonych paczek animacji; brak kolizji i szukania ścieżek między przeszkodami. Nie ma jeszcze gotowego EXE/instalatora ani ekonomii z handlem i walutą. Gospodarka opiera się na zapasach, kosztach produkcji, pracy i potrzebach. Domy są przedstawione zbiorczo; nie mają jeszcze indywidualnych wnętrz. Cykl życia i rolnictwo są umowne, bez szczegółowej biologii i sezonowego wzrostu roślin. Nowa struktura oddziela te obszary od połączenia AI i interfejsu.

Sprawdzenie sceny odbywa się bez renderowania przez testy integracyjne. Jakość nowych decyzji prawdziwego lokalnego modelu i wydajność na komputerze użytkownika wymagają sprawdzenia w grze.
