# Funkce

Funkce jsou základním stavebním kamenem většiny programovacích jazyků, umožňující skupinovat kód do znovupoužitelných bloků. V našem jazyce můžete definovat funkce pro provádění specifických úkolů a následně je volat kdekoliv ve vašem programu.

#### Definice Funkce

Pro definování funkce použijte klíčové slovo `funkce`, následované názvem funkce, seznamem parametrů v závorkách a tělem funkce uzavřeným v složených závorkách.

##### Funkce Bez Parametrů

Funkce bez parametrů je jednoduchá funkce, která nevyžaduje žádné vstupní hodnoty.

```c
funkce ahoj(): {
    tiskni 'Ahoj';
}
```

Pro volání funkce `ahoj` jednoduše napište její název následovaný prázdnými závorkami:

```c
.ahoj();
```

##### Funkce s Parametry

Funkce mohou také přijímat parametry, což jsou hodnoty, které můžete předat do funkce, aby s nimi mohla pracovat.

```c
funkce scitej(a; b): {
    vrat a + b;
}
```

V tomto příkladu funkce `scitej` přijímá dva parametry `a` a `b` a vrací jejich součet. Pro volání této funkce s konkrétními hodnotami použijte:

```c
.scitej(3; 5);
```

Funkce `scitej` se vyhodnotí a vrátí součet hodnot 3 a 5, v tomto případě 8.

#### Volání Funkce

Funkce se volá zapsáním jejího názvu následovaného závorkami, které obsahují argumenty oddělené středníkem, pokud jsou nějaké požadovány.

#### Návratová Hodnota

Klíčové slovo `vrat` se používá v těle funkce pro určení hodnoty, která má být vrácena volajícímu. Funkce nemusí vracet hodnotu; v takovém případě může být použita primárně pro provedení určité akce, jako je tisk výstupu.

Používáním funkcí můžete váš kód učinit čitelnějším, strukturovanějším a lépe znovupoužitelným. Definováním funkcí pro opakované úkoly nebo logické bloky můžete zjednodušit údržbu kódu a usnadnit jeho rozšíření.