# MeatCraft Empire 3D — roadmapa

## Ukończony pionowy wycinek i Sprint 02

- Zakup małego warsztatu i uruchomienie działalności MeatCraft.
- Pełna linia 3D od przyjęcia dostawy do wysyłki.
- Trzech dostawców, trzy receptury, zapasy i identyfikowalność partii.
- Siedmiodniowe suszenie z widocznym mięsem i obowiązkową kontrolą w 3,5. dniu.
- Bilans masy, opakowania, sprzedaż, koszty, reputacja, higiena i konserwacja.
- Funkcjonalna załoga: rekrutacja, zwalnianie, przydziały, role, zadania, doświadczenie, zmęczenie i odporne na wczytanie naliczanie płac.
- Żywi pracownicy 3D poruszający się do przypisanych maszyn i wyświetlający imię, rolę oraz zadanie.
- Zużycie i awarie każdej maszyny, części zamienne, odpłatne naprawy technika, historia serwisowa i czytelne stany 3D.
- Incydenty jakości, kwarantanna aktywnej lub gotowej partii, działania korygujące i trwała historia identyfikowalności.
- Kontrakty klientów, terminy, prawidłowe zużycie magazynu i przychód dopiero po wysyłce.
- Menu, tutorial, panele zarządzania, zapis v3 z migracją v2 oraz lokalizacja EN/PL.
- Automatyczne testy regresji, symulacji, operacji i rzeczywistego renderowania.

## Następny etap — planowanie i budowa

1. Dodać kolejkę przyszłych partii oraz bezpiecznie rozszerzyć architekturę poza jedną `active_batch`.
2. Egzekwować godziny zmian i dostępność poza zmianą, z czytelnym planem obsady dla kolejnych zadań.
3. Zbudować pierwszy tryb rozmieszczania urządzeń na siatce z walidacją stref, przejść i kosztu zakupu.
4. Rozszerzyć HACCP o odchylenia monitoringu suszarni oraz decyzję przeróbki lub utylizacji.
5. Dodać kary za spóźnione kontrakty i minimalną jakość jako warunek wysyłki.

## Następnie — rozwój firmy

- Odblokowanie średniej i dużej hali, wielu linii oraz większego magazynu.
- Umowy z dostawcami, zmienne ceny, partie o różnej jakości i zdarzenia rynkowe.
- Produkty whole/sliced, różne gramatury, etykiety i planowanie produkcji.
- Cele kolejnych rozdziałów, osiągnięcia i dłuższy balans ekonomii.
- Opcjonalny, ograniczony i walidowany postęp offline.

## Walidacja platform

1. Zainstalować oficjalne szablony eksportu Godot 4.7.2.
2. Wygenerować i sprawdzić Windows x86-64 oraz Web/HTML5.
3. Skonfigurować Android SDK/JDK, wygenerować debug APK i przetestować na telefonie oraz tablecie.
4. Sprawdzić dotyk, gesty, safe areas, zmianę orientacji, uśpienie i wznowienie.
5. Zmierzyć czas klatki, pamięć i baterię na słabszym urządzeniu; dopiero na podstawie pomiarów optymalizować modele i aktualizacje symulacji.

Publikacja sklepowa, płatności, reklamy i wdrożenie na żywą stronę nie należą do obecnego etapu.
