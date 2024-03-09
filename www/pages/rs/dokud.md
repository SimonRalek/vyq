# Dokud

Smyčka `dokud` umožňuje opakovat blok kódu, dokud je splněna určitá podmínka. Tato smyčka je užitečná pro provádění kódu, který musí běžet opakovaně, dokud není dosaženo určitého stavu nebo podmínky.

#### Syntaxe

Základní syntaxe pro smyčku `dokud` je následující:

```c
dokud podmínka: {
    // Kód, který se má opakovat
}
```

#### Použití Smyčky Dokud

Smyčka `dokud` se opakuje, dokud je podmínka pravdivá. Jakmile podmínka již není pravdivá, smyčka se ukončí a program pokračuje dalším kódem za smyčkou.

Příklad:

```c
prm pocet = 0;
dokud .pocet < 5: {
    tiskni 'Hodnota počtu je: ' + .pocet;
    .pocet += 1;  // Zvyšujeme hodnotu počtu
}
```

V tomto příkladu se smyčka `dokud` opakuje, dokud je hodnota proměnné `pocet` menší než 5. V každé iteraci smyčky se vytiskne hodnota `pocet` a poté se zvýší o 1.

#### Přerušení Smyčky pomocí `Zastav`

Pokud potřebujete v některých situacích předčasně ukončit smyčku, můžete použít příkaz `zastav`. Tento příkaz okamžitě ukončí smyčku a program pokračuje kódem za smyčkou.

Příklad použití `zastav`:

```c
prm pocet = 0;
dokud (pravda): {
    .pocet = .pocet + 1;
    tiskni 'Hodnota počtu je: ' + .pocet;

    pokud (.pocet == 5): {
        zastav;  // Ukončí smyčku, když pocet dosáhne 5
    }
}
```

V tomto příkladu se smyčka `dokud` teoreticky opakuje nekonečně, ale díky příkazu `zastav` v podmínce `pokud` se smyčka ukončí, jakmile proměnná `pocet` dosáhne hodnoty 5.

Používáním smyčky `dokud` a příkazu `zastav` můžete vytvořit flexibilní smyčky, které reagují na dynamické podmínky během běhu vašeho programu.