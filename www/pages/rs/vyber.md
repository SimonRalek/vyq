# Vyber

Příkaz `vyber` je užitečný pro provádění různých akcí na základě různých hodnot jedné proměnné. Je to čistější alternativa k několika `pokud`-`jinak` příkazům, když potřebujete porovnávat stejnou proměnnou s mnoha různými hodnotami.

#### Syntaxe

Základní syntaxe příkazu `vyber` vypadá takto:

```c
vyber z_hodnoty: {
    pripad neco -> tiskni ano;
    jinak -> tiskni ne;
}
```

V tomto příkladu `vyber` příkaz testuje hodnotu proměnné `.k`. Na základě této hodnoty se rozhodne, který blok kódu se má vykonat. `pripad` specifikuje hodnotu, která se má testovat, a `->` ukazuje na blok kódu, který se má vykonat, pokud je hodnota shodná.

#### Použití

- **pripad**: Určuje konkrétní hodnotu, kterou chcete testovat proti proměnné uvedené v `vyber`. Pokud se hodnota proměnné rovná hodnotě specifikované v `pripad`, vykoná se následující blok kódu.
- **jinak**: Používá se pro definování bloku kódu, který se vykoná, pokud žádný z `pripad` bloků neodpovídá hodnotě proměnné. Tento blok je volitelný, ale užitečný pro zachycení "výchozího" chování. V jednom bloku může být maximálně jen jedno `jinak`!

#### Příklad s Více Případy

```c
prm mesic = 4;
vyber .mesic: {
    pripad 1 -> tiskni 'Leden';
    pripad 2 -> tiskni 'Únor';
    pripad 3 -> tiskni 'Březen';
    pripad 4 -> tiskni 'Duben';
    // Další případy...
    jinak -> tiskni 'Neznámý měsíc';
}
```

V tomto příkladu se `vyber` příkaz používá pro výpis názvu měsíce na základě jeho číselného označení. Pokud hodnota proměnné `.mesic` není v rozsahu 1-4, vykoná se `jinak` blok a vytiskne se 'Neznámý měsíc'.

Používáním `vyber` příkazu můžete váš kód udržet čistý a organizovaný, což usnadňuje jeho čtení a údržbu, když potřebujete provádět různé akce založené na hodnotě jedné proměnné.