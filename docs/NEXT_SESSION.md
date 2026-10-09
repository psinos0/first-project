# Następna sesja

1. Sprawdź `git status --short --branch`, przeczytaj `docs/AUTONOMOUS_DEV_CHECKPOINT.md` i uruchom `./scripts/test.sh`.
2. Dodaj w `MeatGame` trwałą `production_queue` z rekordami: ID, receptura, masa, priorytet, stan, źródło kontraktu i czas utworzenia.
3. Pozostaw jedną `active_batch`; po jej bezpiecznym zakończeniu uruchamiaj pierwszą wykonalną pozycję kolejki. Nie rezerwuj ani nie odejmuj surowców dwa razy.
4. Zapisz i odtwórz kolejkę w schemacie v3, z normalizacją uszkodzonych lub nieaktualnych pozycji.
5. Egzekwuj `shift_start` i `shift_end` w `WorkforceSystem`, również dla zmiany przechodzącej przez północ. Poza zmianą pracownik regeneruje zmęczenie i nie otrzymuje nowego zadania.
6. W panelu Planning pokaż kolejność partii, przewidywane blokady materiałów, brak obsady oraz powiązanie z kontraktem.
7. Dodaj testy kolejnych dwóch partii, zapisu kolejki, braku duplikacji surowców, obsady poza zmianą i dużego skoku czasu przez granicę zmiany.
8. Uruchom wszystkie trzy zestawy logiki oraz test renderowania, obejrzyj zrzuty i zapisz stabilny commit.
9. Dopiero po stabilizacji kolejki zacznij pierwszy tryb rozmieszczania urządzeń na siatce z walidacją stref i przejść.

Nie rozszerzaj od razu `active_batch` do tablicy wielu aktywnych procesów. Najpierw oddziel kolejkę oczekującą od jednego sprawdzonego przebiegu produkcyjnego.
