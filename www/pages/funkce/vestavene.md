# Vestavěné Funkce

Naším jazykem jsou poskytovány různé vestavěné funkce, které vám umožní provádět běžné úkoly, jako je manipulace s řetězci, načítání vstupu od uživatele, generování náhodných čísel a další. Tyto funkce jsou přístupné přímo ve vašem kódu bez potřeby jakéhokoliv importu.

#### Práce s Řetězci

- `.delka(retezec)`: Vrátí délku daného řetězce.

#### Vstup a Výstup

- `.nactiVstup()`: Načte řetězec z standardního vstupu.

#### Typy a Kontrola Typů

- `.ziskejTyp(hodnota)`: Vrátí řetězec reprezentující typ dané hodnoty (např. "retezec", "cislo").

#### Generování Náhodných Čísel

- `.nahoda()`: Vrátí náhodné číslo.
- `.nahoda(max)`: Vrátí náhodné číslo mezi 0 a zadaným maximem.

#### Matematické Funkce

- `.mocnina(hodnota, naKterouMocninu)`: Vrátí hodnotu zvýšenou na specifikovanou mocninu.
- `.odmocnina(hodnota)`: Vrátí druhou odmocninu dané hodnoty.

#### Kontrola Typů

- `.jeCislo(hodnota)`: Vrátí `ano`, pokud je daná hodnota číslem, jinak `ne`.
- `.jeRetezec(hodnota)`: Vrátí `ano`, pokud je daná hodnota řetězcem, jinak `ne`.

#### Čas a Datum

- `.cas()`: Vrátí aktuální časovou známku (timestamp).

##### Příklady Použití

Zde je několik příkladů, jak můžete vestavěné funkce používat ve vašem kódu:

```c
// Získání délky řetězce
prm delkaJmena = .delka('Petr');
tiskni delkaJmena;  // Vytiskne délku řetězce 'Petr'

// Čtení vstupu od uživatele
prm uzivatelskyVstup = .nactiVstup();
tiskni 'Zadali jste: ' + uzivatelskyVstup;

// Generování náhodného čísla
prm nahodneCislo = .nahoda(100);
tiskni 'Náhodné číslo do 100: ' + nahodneCislo;

// Kontrola, zda je hodnota číslem
pokud (.jeCislo(uzivatelskyVstup)): {
    tiskni 'Zadaná hodnota je číslo.';
} jinak {
    tiskni 'Zadaná hodnota není číslo.';
}
```

Použitím těchto vestavěných funkcí můžete efektivně provádět různé úkoly bez nutnosti definovat vlastní pomocné funkce pro tyto běžné operace.
