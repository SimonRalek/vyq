# Vestavěné Funkce

Naším jazykem jsou poskytovány různé vestavěné funkce, které vám umožní provádět běžné úkoly, jako je manipulace s řetězci, načítání vstupu od uživatele, generování náhodných čísel a další. Tyto funkce jsou přístupné přímo ve vašem kódu bez potřeby jakéhokoliv importu.

#### Práce s Řetězci

- `.délka(retezec)`: Vrátí délku daného řetězce.

### Práce s Listy

- `.přidat(list, hodnota)`: Přidá hodnotu na konec listu, vrátí počet prvků v listu
- `.vyjmout(list)`: Vyjme poslední prvek z listu a vrátí ho

#### Vstup a Výstup

- `.načtiVstup()`: Načte řetězec z standardního vstupu.

#### Typy a Kontrola Typů

- `.získejTyp(hodnota)`: Vrátí řetězec reprezentující typ dané hodnoty (např. "textový řetězec", "číslo").

#### Generování Náhodných Čísel

- `.náhoda()`: Vrátí náhodné číslo.
- `.náhoda(max)`: Vrátí náhodné číslo mezi 0 a zadaným maximem.

#### Matematické Funkce

- `.mocnina(hodnota, naKterouMocninu)`: Vrátí hodnotu zvýšenou na specifikovanou mocninu.
- `.odmocnina(hodnota)`: Vrátí druhou odmocninu dané hodnoty.

#### Kontrola Typů

- `.jeČíslo(hodnota)`: Vrátí `ano`, pokud je daná hodnota číslem, jinak `ne`.
- `.jeŘetězec(hodnota)`: Vrátí `ano`, pokud je daná hodnota řetězcem, jinak `ne`.
- `.jeList(hodnota)`: Vrátí `ano`, pokud je daná hodnota listem, jinak `ne`.

#### Převedení Typů

- `.naČíslo(řetězec)`: Vrátí číselnou hodnotu řetězce. Jestliže řetězec není číslo vyhodí chybu.
- `.naŘetězec(hodnota)`: Vrátí řetězec reprezentující danou hodnotu.

#### Čas a Datum

- `.čas()`: Vrátí aktuální časovou známku (timestamp).

##### Příklady Použití

Zde je několik příkladů, jak můžete vestavěné funkce používat ve vašem kódu:

```c
// Získání délky řetězce
prm delkaJmena = .délka('Petr');
tiskni .delkaJmena;  // Vytiskne délku řetězce 'Petr'

// Generování náhodného čísla
prm nahodneCislo = .náhoda(100);
tiskni 'Náhodné číslo do 100: ' + .nahodneCislo;

// Čtení vstupu od uživatele
tiskniB 'Zadejte číslo: ';
prm uzivatelskyVstup = .načtiVstup();
tiskni 'Zadali jste: ' + .uzivatelskyVstup;

// Kontrola, zda je hodnota číslem
pokud (.naČíslo(.uzivatelskyVstup)): {
    tiskni 'Zadaná hodnota je číslo.';
}
```

Použitím těchto vestavěných funkcí můžete efektivně provádět různé úkoly bez nutnosti definovat vlastní pomocné funkce pro tyto běžné operace.
