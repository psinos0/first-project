# Następna sesja

1. Uruchom `git status --short --branch`, `./scripts/setup.sh` i `./scripts/test.sh`.
2. Przeczytaj `docs/AUTONOMOUS_DEV_CHECKPOINT.md` oraz konfigurację `config/meatcraft_game.json`.
3. Dodaj do konfiguracji role pracowników, płace, szybkość, koszt zatrudnienia i dozwolone etapy.
4. Rozszerz `MeatGame` o pracowników, kolejkę zadań i naliczanie płac według czasu gry. Jedna zmiana stanu musi mieć jednego właściciela.
5. Połącz istniejące trzy modele pracowników z zadaniami oraz punktami pracy przy urządzeniach.
6. Dodaj panel pracowników do lewego menu i pokaż rolę, bieżące zadanie, status oraz koszt zmiany.
7. Zwiększ wersję zapisu i dodaj migrację lub bezpieczną obsługę starszego v2.
8. Dodaj testy rekrutacji, przydziału, kosztu, pauzy, zapisu/wczytania i braku podwójnego naliczania płac.
9. Uruchom wszystkie 43 testy regresji, testy MeatCraft i test renderowania; obejrzyj nowe zrzuty.
10. Zaktualizuj checkpoint i utwórz osobny commit na stabilnym wyniku.

Po systemie pracowników kolejnym priorytetem są awarie i naprawy urządzeń, a następnie incydenty HACCP i kwarantanna partii.
