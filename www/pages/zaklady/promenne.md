# Proměnné a Konstanty

V tomto programovacím jazyce můžete v kódu používat proměnné a konstanty pro uchování hodnot. Jednou z klíčových vlastností je, že pro názvy proměnných a konstant můžete používat českou diakritiku, což umožňuje psát kód přirozeněji pro mluvčí češtiny.

#### Proměnné

Proměnné se vytvářejí pomocí klíčového slova `prm` a mohou obsahovat různé typy hodnot, jak vysvětleno na předchozí stránce. Je povoleno používat českou diakritiku v názvech proměnných, což umožňuje lepší čitelnost a srozumitelnost kódu.

Příklad deklarace proměnné s diakritikou:

```c
prm početNávštěvníků = 42;
prm příjmeníUživatele = 'Novák';
```

Hodnotu proměnné můžete kdykoliv změnit přiřazením nové hodnoty:

```c
početNávštěvníků = .početNávštěvníků + 1;
příjmeníUživatele = 'Svoboda';
```

#### Konstanty

Konstanty se definují pomocí klíčového slova `konst` a používají se pro uchování neměnných hodnot. Podobně jako u proměnných, i u konst ant je možné v názvech využívat českou diakritiku.

Příklad deklarace konstanty s diakritikou:

```c
konst maximálníPočet = 100;
konst základníPozdrav = 'Ahoj, světe!';
```

Pokud se pokusíte změnit hodnotu konstanty po její inicializaci, dojde k chybě.

```c
maximálníPočet = 200; // Toto vyvolá chybu
```

#### Přístup

K proměnným a konstantám se přistupuje pomocí tečkové notace.

Pro příklad:
```c
prm k = 3;
tiskni .k; // vytiskne 3
```

```c
konst PI = 3,14;
tiskni .PI; // vytiskne 3,14
```

Při nepřistupování k proměnným a konstantám s tečkou nastane k chybě! Díky tečkové notaci můžete jasně rozlišit, kdy přistupujete k proměnné nebo konstantě ve vašem kódu, což zvyšuje čitelnost a organizaci programu.