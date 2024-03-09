# List

Pole jsou základní datovou strukturou v našem jazyce, která umožňuje uchovávat více hodnot v jediné proměnné. Práce s poli je velmi podobná jako v jiných programovacích jazycích. Tento dokument vám ukáže, jak pole deklarovat, přistupovat k jejich prvkům a jak je manipulovat.

#### Deklarace Listu

Pro deklaraci listu použijte `[]` značící seznam hodnot. Hodnoty v listu mohou být jakéhokoli typu, včetně čísel, řetězců a pravdivostních hodnot.

```c
prm mujList = [1, 2, 3, 4, 5];
prm jmena = ['Karel', 'Eva', 'Jiří'];
prm pravdy = [ano, ne, ano, nic];
```

#### Přístup k Prvkům

K prvkům pole přistupujete pomocí indexace. Indexy začínají od 0 pro první prvek, 1 pro druhý prvek a tak dále. Pro přístup k prvkům použijte hranaté závorky s indexem prvku.

```c
tiskni .mujList[0];  // Vytiskne 1
tiskni .jmena[1];  // Vytiskne 'Eva'
tiskni .pravdy[.mujList[2]]; // Vytiskne 'nic' 
```

#### Změna Prvků

Pro změnu hodnoty prvku v poli, použijte jeho index a přiřaďte novou hodnotu.

```c
.mujList[0] = 10;  // Změní první prvek na 10
.jmena[2] = 'Martina';  // Změní třetí prvek na 'Martina'
```

#### Délka List

Pro zjištění počtu prvků v poli můžete použít vlastnost `delka`. 

```c
tiskni .delka(.mujList);  // Vytiskne 5
```

#### Iterace přes List

Pro projití všech prvků listu můžete použít smyčku. Zde je příklad použití smyčky `opakuj` pro výpis všech prvků pole:

```c
opakuj prm i = 0; .i < .delka(.mujList); .i += 1: {
    tiskni .mujList[.i];
}
```

Více informací o použití `opakuj` se dozvíte v sekci řídících struktur.

Pole jsou mocným nástrojem pro práci s kolekcemi dat. S pomocí polí můžete efektivně organizovat a manipulovat s více hodnotami současně.