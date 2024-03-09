# Pokud

Podmíněné příkazy umožňují vašemu programu rozhodovat, které části kódu se mají vykonat na základě daných podmínek. V našem jazyce se pro tento účel používá klíčové slovo `pokud`, které může být doplněno o `jinak` pro definování alternativního chování.

#### Syntaxe

Základní syntaxe pro `pokud` příkaz je následující:

```c
pokud podmínka: {
    // Kód, který se vykoná, pokud je podmínka pravdivá
} jinak {
    // Kód, který se vykoná, pokud je podmínka nepravdivá
}
```

#### Příklad

Zde je jednoduchý příklad, který demonstruje použití `pokud` příkazu:

```c
pokud .cislo > 10: {
    tiskni 'Číslo je větší než 10.';
} jinak {
    tiskni 'Číslo je 10 nebo menší.';
}
```

#### Vrstvení Podmínek

`Pokud` příkazy lze vrstvit pro vytvoření složitějších logických struktur. To umožňuje testovat řadu podmínek a reagovat na ně různými způsoby.

```c
pokud .cislo > 10: {
    tiskni 'Číslo je větší než 10.';
} jinak pokud .cislo == 10: {
    tiskni 'Číslo je přesně 10.';
} jinak {
    tiskni 'Číslo je menší než 10.';
}
```

## Ternární Operátor

Ternární operátor je zkrácená forma podmíněného vyjádření, které umožňuje přiřadit hodnotu proměnné na základě podmínky v jediném výrazu. Ternární operátor typicky zahrnuje tři části: podmínku, hodnotu, pokud je podmínka pravdivá, a hodnotu, pokud je podmínka nepravdivá.

#### Syntaxe

Základní syntaxe ternárního operátoru vypadá takto:

```c
prm vysledek = (podmínka) ? 'Pravda' : 'Nepravda';
```

#### Příklad Použití

Představme si, že chceme proměnné `pozdrav` přiřadit hodnotu 'Dobrý den' pokud je proměnná `cas` menší než 12, jinak chceme přiřadit 'Dobrý večer'. Ternární operátor to umožní udělat jednoduše:

```c
prm cas = 10;
prm pozdrav = (.cas < 12) ? 'Dobrý den' : 'Dobrý večer';
tiskni .pozdrav;  // Vytiskne 'Dobrý den', pokud je 'cas' menší než 12
```

#### Výhody Ternárního Operátoru

Ternární operátor může zjednodušit váš kód tím, že redukuje potřebu psát rozsáhlé `pokud`-`jinak` struktury pro jednoduché podmíněné přiřazení. Je ideální pro případy, kdy potřebujete rychle rozhodnout mezi dvěma hodnotami na základě jednoduché podmínky.

Používejte ternární operátor s rozvahou, aby váš kód zůstal čitelný, zejména při složitějších podmínkách nebo když je výsledek operátoru další komplexní výraz.

### Důležité Poznámky

- Ujistěte se, že vaše podmínky jsou jasně definované a testují to, co skutečně potřebujete.
- Při vrstvení `pokud` příkazů je důležité udržet kód přehledný a srozumitelný, aby bylo snadné pochopit, co váš program dělá.

Používáním podmíněných příkazů můžete výrazně zvýšit flexibilitu a rozhodovací schopnost vašich programů.