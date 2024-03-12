# Instalace

Tato část vás provede kroky potřebnými k instalaci programovacího jazyka, jeho přidání do systémové proměnné `PATH` a jeho základnímu použití.

Program lze nainstalovat stažením binárního souboru ze sekce "Releases" na GitHubu. Prosím, vyberte soubor odpovídající vašemu operačnímu systému a platformě.


### Kroky pro instalaci:

1. Klikněte na tento [link](#downloadLink) pro instalaci přímo pro váš systém.

nebo 

1. Přejděte na [GitHub](https://github.com/simonralek/vyq) a otevřete stránku projektu.
2. Klikněte na záložku "Releases" nalezenou na stránce projektu.
3. Vyberte nejnovější verzi vhodnou pro váš operační systém a stáhněte příslušný binární soubor.
4. Po stažení soubor uložte do preferovaného umístění na vašem počítači.


### Přidání do PATH

Pro snadnější použití můžete program přidat do systémové proměnné `PATH`. Tím umožníte jeho spouštění z jakéhokoli umístění v příkazovém řádku.

#### Pro Windows:

1. Vyhledejte "Systémové proměnné prostředí" ve vyhledávači Windows a otevřete dialogové okno "Systémové vlastnosti".
2. Klikněte na "Pokročilé" a poté na "Proměnné prostředí".
3. Ve spodní části okna, pod "Systémové proměnné", najděte a vyberte `Path`, poté klikněte na "Upravit".
4. Klikněte na "Nový" a přidejte cestu ke složce, kde je uložen binární soubor.
5. Klikněte na "OK" a uložte změny.

#### Pro Unix/Linux/Mac:

1. Otevřete terminál.
2. Editujte soubor profilu vašeho shellu (např. `~/.bash_profile`, `~/.zshrc`, atd.) pomocí textového editoru.
3. Přidejte řádek `export PATH="$PATH:/cesta/ke/složce"` na konec souboru, kde `/cesta/ke/složce` je cesta ke složce s binárním souborem.
4. Uložte soubor a restartujte terminál nebo použijte `source ~/.bash_profile` (nebo ekvivalent pro váš shell) k aplikaci změn.

### Skripty pro usnadnění instalace

Pro usnadnění procesu přidání programu do `PATH` můžete vytvořit instalační skripty.

##### Windows
```powershell
[Environment]::SetEnvironmentVariable("Path", $Env:Path + ";C:\cesta\k\vašemu\programu", [EnvironmentVariableTarget]::User)
```

##### Linux
```bash
echo 'export PATH="$PATH:/cesta/k/vašemu/programu"' >> ~/.bashrc && source ~/.bashrc
```
