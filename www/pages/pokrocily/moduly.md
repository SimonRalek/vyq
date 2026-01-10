# Moduly a Importování

Vyq podporuje modulární programování, což vám umožňuje rozdělit váš kód do více souborů a importovat je podle potřeby.

## Importování souborů

K importu a spuštění jiného souboru slouží funkce `.použij(cesta)`. Tato funkce načte obsah souboru, zkompiluje jej a okamžitě spustí. Všechny globální proměnné a funkce definované v importovaném souboru budou dostupné i v hlavním programu.

```c
// Importování souboru 'knihovna.vyq'
.použij('knihovna.vyq');

// Nyní můžeme používat funkce a proměnné z knihovny
tiskni .pomocnaZprava;
.vypocitejNeco();
```

## Sdílení Proměnných

Důležitou vlastností importu ve Vyq je sdílený globální prostor. Pokud v modulu definujete globální proměnnou (pomocí `prm` nebo `konst`), bude tato proměnná viditelná pro jakýkoli kód, který tento modul importuje, a naopak.

### Příklad

Soubor `math_utils.vyq`:
```c
prm PI = 3.14159;

fun obsahKruhu(polomer) {
    vrat .PI * .polomer * .polomer;
}
```

Hlavní program:
```c
.použij('math_utils.vyq');

tiskni 'Hodnota PI je: ' + .PI;
tiskni 'Obsah kruhu s poloměrem 5 je: ' + .obsahKruhu(5);
```

## Poznámky

- Importovaný soubor se chová jako skript, který se spustí v místě zavolání `.použij`.
- Cesta k souboru je relativní k aktuálnímu pracovnímu adresáři, ze kterého jste spustili interpret `vyq`.
- Chyby v importovaném souboru budou hlášeny s odkazem na správný soubor a řádek.
