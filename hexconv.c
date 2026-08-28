#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Apufunktio suuren numeron pilkkomiseen selkokielelle
void tulosta_koko_selkokielella(long luku) {
    // Jos luku on vähintään 1 Giga (1024 * 1024 * 1024)
    if (luku >= 1073741824L) {
        double gigat = (double)luku / 1073741824.0;
        printf(" (Vastaa noin: %.2f GB / GiB)\n", gigat);
    }
    // Jos luku on vähintään 1 Mega (1024 * 1024)
    else if (luku >= 1048576L) {
        double megat = (double)luku / 1048576.0;
        printf(" (Vastaa noin: %.2f MB / MiB)\n", megat);
    }
    // Jos luku on vähintään 1 Kilo (1024)
    else if (luku >= 1024L) {
        double kilot = (double)luku / 1024.0;
        printf(" (Vastaa noin: %.2f KB / KiB)\n", kilot);
    }
    // Pienille luvuille ei tulosteta erillistä kokoluokkaa
    else {
        printf("\n");
    }
}

void muunna_luku(const char *syote) {
    if (syote == NULL || strlen(syote) == 0) {
        printf("Virheellinen syöte.\n");
        return;
    }

    if (syote[0] == '0' && (syote[1] == 'x' || syote[1] == 'X')) {
        long desimaali = strtol(&syote[2], NULL, 16);
        printf("Heksaluku %s on desimaalina: %ld", syote, desimaali);
        
        // Kutsutaan koon pilkkojaa desimaalitulokselle
        tulosta_koko_selkokielella(desimaali);
    } 
    else {
        long luku = strtol(syote, NULL, 10);
        printf("Desimaaliluku %ld on heksana: 0x%lX", luku, luku);
        
        // Kutsutaan koon pilkkojaa alkuperäiselle luvulle
        tulosta_koko_selkokielella(luku);
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Virhe: Anna muutettava luku parametrina.\n");
        printf("Käyttöesimerkki: %s 16777216\n", argv[0]);
        return 1;
    }

    muunna_luku(argv[1]);
    return 0;
}
