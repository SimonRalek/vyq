# Opakuj

Smyčky `opakuj` poskytují mocný nástroj pro opakování bloku kódu několikrát. V našem jazyce existují dvě formy této smyčky: základní forma pro jednoduchou iteraci a rozšířená forma pro pokročilou kontrolu iterace.

#### Základní Smyčka Opakuj

Základní forma smyčky `opakuj` umožňuje opakovat blok kódu, dokud je splněna určitá podmínka.

Syntaxe:

```c
opakuj prm i = 0; .i < 5; .i += 1: {
    // Blok kódu pro opakování
}
```

Tento příklad ukazuje smyčku, která se opakuje pětkrát. Proměnná `i` se inicializuje na 0, smyčka pokračuje, dokud `i` je menší než 5, a `i` se zvýší o 1 v každé iteraci.

#### Rozšířená Smyčka Opakuj

Rozšířená forma smyčky `opakuj` nabízí více kontrol nad iterací, včetně směru iterace a volitelného intervalu.

Syntaxe:

```c
opakuj jako i 0..4: {
    tiskni .i;  // Vytiskne čísla od 0 do 4 (bez čtyrky)
}

opakuj jako i 6 dolu 2 po 2: {
    tiskni .i;  // Vytiskne 6, 4
}
```

První příklad iteruje od 0 do 3 s výchozím krokem 1. Druhý příklad ukazuje iteraci od 6 dolů k 2 s krokem 2. Klíčová slova `dolu` a `po` specifikují směr a velikost kroku iterace.

##### Specifikace Směru a Intervalu

- **Směr**: Klíčové slovo `dolu` určuje, že iterace bude probíhat v opačném směru, tedy od vyšších hodnot k nižším.
- **Interval**: Klíčové slovo `po` následované číslem specifikuje velikost kroku pro iteraci. Pokud není uvedeno, předpokládá se krok 1.

## Řízení Průběhu Smyček: Zastav a Pokracuj

Při práci se smyčkami `opakuj` můžete narazit na situace, kdy potřebujete předčasně ukončit iteraci nebo přeskočit zbytek aktuální iterace a pokračovat přímo na další. Pro tyto účely slouží příkazy `zastav` (break) a `pokracuj` (continue).

#### Zastav

Příkaz `zastav` ukončí celou smyčku okamžitě, bez ohledu na to, kolik iterací bylo původně plánováno. Používá se, když je požadováno opustit smyčku dříve, než by byla dosažena její konečná podmínka.

Příklad použití `zastav`:

```c
opakuj jako i 0..10: {
    pokud .i == 5: {
        zastav;  // Ukončí smyčku, jakmile i dosáhne 5
    }
    tiskni .i;  // Tiskne čísla od 0 do 4
}
```

#### Pokracuj

Na rozdíl od `zastav`, příkaz `pokracuj` neukončí celou smyčku, ale místo toho přeskočí zbytek aktuální iterace a pokračuje přímo na další. Je užitečný, pokud chcete ignorovat zbytek kódu v těle smyčky pro určité hodnoty iterátoru.

Příklad použití `pokracuj`:

```c
opakuj jako i 0..10: {
    pokud .i % 2 == 0: {
        pokracuj;  // Přeskočí zbytek těla smyčky pro sudá čísla
    }
    tiskni .i;  // Tiskne pouze lichá čísla
}
```

#### Použití Smyček Opakuj

Smyčky `opakuj` jsou ideální pro situace, kdy potřebujete opakovat určité operace pevně stanovený počet krát, nebo když potřebujete iteračně procházet rozsahem hodnot s kontrolou nad směrem a velikostí kroku iterace.

Používáním těchto smyček můžete zefektivnit vaše programy a učinit kód čitelnějším a strukturovanějším.

