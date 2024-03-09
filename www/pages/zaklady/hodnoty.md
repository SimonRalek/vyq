# Hodnoty

V tomto programovacím jazyce existuje několik základních typů hodnot, které můžete ve svých programech používat. Tyto zahrnují řetězce, čísla, pravdivostní hodnoty a speciální hodnotu `nic`.

#### Čísla

Podporujeme jak celá čísla, tak čísla s desetinnými místy. Důležité je, že desetinné čísla používají čárku (`,`) místo tečky (`.`) jako desetinný oddělovač, což odpovídá českému zápisu čísel.

Příklady čísel:

```c
42
3,14159
-273
```

#### Řetězce (Stringy)

Řetězce jsou posloupnosti znaků používané pro reprezentaci textu. V našem jazyce mohou být řetězce obklopeny buď jednoduchými (`'`) nebo dvojitými (`"`) uvozovkami. Použití `"` umožnuje psát víceřádkové řetězce. Česká diakritika je plně podporována, takže můžete bez problémů používat znaky jako `č`, `ř`, `ž` atd.

Příklady řetězců:

```c
'ahoj'
"Dobrý den"
'Příliš žluťoučký kůň úpěl ďábelské ódy'
```

#### Pravdivostní hodnoty

Pravdivostní hodnoty jsou používány pro reprezentaci pravdy a nepravdy. V našem jazyce používáme `ano` pro pravdu a `ne` pro nepravdu.

Příklady pravdivostních hodnot:

```c
ano
ne
```

#### Nic

Speciální hodnota `nic` je používána pro reprezentaci "ničeho" nebo "žádné hodnoty". Je to užitečné v situacích, kdy potřebujete indikovat absenci konkrétní hodnoty.

Příklad použití `nic`:

```c
nic
```

Používáním těchto základních typů hodnot můžete vytvářet složitější struktury a logiku ve vašich programech.