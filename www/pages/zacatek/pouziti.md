# Použití

Tento dokument popisuje, jak používat program, včetně základního spuštění, použití REPL (Read-Eval-Print Loop) pro interaktivní programování a spouštění souborů s programovým kódem. Dále jsou zde uvedeny dostupné příkazové řádkové argumenty.

#### Základní spuštění

Pro spuštění programu otevřete terminál nebo příkazový řádek a použijte následující syntaxi:

```c
vyq [argumenty]
```

#### Interaktivní REPL

REPL umožňuje interaktivní programování tím, že okamžitě vyhodnocuje vložený kód a zobrazuje výsledky. Pro vstup do REPL módu spusťte program bez jakýchkoli argumentů:

```c
vyq
```

#### Spouštění souboru

Pro spuštění souboru s programovým kódem jako argument předejte cestu k souboru:

```c
vyq cesta/k/souboru
```

#### Dostupné argumenty

Program podporuje následující argumenty pro různé operace:

| Argument      | Dlouhá forma  | Popis                                |
|---------------|---------------|--------------------------------------|
| `-h`          | `--pomoc`     | Zobrazí pomoc a použití programu.    |
| `-v`          | `--verze`     | Zobrazí aktuální verzi programu.     |
|               | `--bezbarev`  | Vypisuje výstup bez použití barev.   |

##### Příklady použití argumentů

Zobrazení nápovědy:

```c
vyq -h
```

Zobrazení verze:

```c
vyq -v
```

Spouštění programu bez barevného výstupu:

```c
vyq --bezbarev
```

### Rozšíření pro VSCode

Pro usnadnění vývoje a ladění kódu napsaného v našem programovacím jazyce můžete využít speciální [rozšíření](https://marketplace.visualstudio.com/items?itemName=vyq.vyq-language-support) pro Visual Studio Code (VSCode). Toto rozšíření poskytuje pokročilé funkce, jako je zvýrazňování syntaxe, snippety a další.

##### Instalace Rozšíření

1. Otevřete VSCode a přejděte do zobrazení rozšíření (View > Extensions).
2. Vyhledejte `Vyq - Podpora Jazyka` v poli pro vyhledávání.
3. Klikněte na tlačítko 'Install' pro instalaci rozšíření.
4. Po instalaci restartujte VSCode, aby se změny projevily.
