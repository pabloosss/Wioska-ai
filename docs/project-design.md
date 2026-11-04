# Projekt gry — założenia

## Pierwsza wersja

- 5 mieszkańców na starcie.
- Potrzeby: głód, odpoczynek i temperatura.
- Podstawowe zasoby: jedzenie i drewno.
- Pierwsze zajęcia: zbieracz i budowniczy.
- Wspólny magazyn na zapasy wioski.
- Każdy mieszkaniec ma własny ekwipunek i prywatne rzeczy. Ubrania, narzędzia i osobiste przedmioty nie trafiają automatycznie do wspólnego magazynu.
- Wioska rozbudowuje się wraz z dostępnością surowców i miejsc do zamieszkania.

## Założenie AI

Jeden lokalny model obsługuje decyzje wielu mieszkańców. Każdy NPC ma oddzielny profil: charakter, potrzeby, umiejętności, relacje, cele i zapisane wspomnienia.

Model wybiera zamiar, na przykład „zbierz jedzenie” albo „dokończ budowę”. Symulacja gry sprawdza, czy działanie jest możliwe, i odpowiada za ruch, ścieżki, animacje, zużycie zasobów oraz zmianę potrzeb. Model nie steruje każdą klatką ani nie zmienia bezpośrednio stanu świata.

Decyzje AI uruchamiają się przy ważnych zdarzeniach lub zmianie zadania. Dzięki temu mieszkańcy mogą stale poruszać się i pracować, a model może obsługiwać ich po kolei. Pamięć i umiejętności zapisują się jako dane gry; nie trzeba trenować modelu ponownie przy każdym doświadczeniu.

## Ustalenia do dopracowania

- Jak temperatura, ubranie, schronienie i ogień wpływają na komfort mieszkańca.
- Jak mieszkańcy dzielą się jedzeniem i narzędziami ze wspólnego magazynu.
- Jak wybierają pracę, gdy kilka potrzeb konkuruje ze sobą.
- Kiedy pojawiają się nowi mieszkańcy i jakie warunki muszą być spełnione.
- Wybór jednej spójnej paczki graficznej.
