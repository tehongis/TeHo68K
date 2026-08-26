#ifndef DISPLAY_H
#define DISPLAY_H

#include "vm.h"

// Alustaa SDL2-ikkunan ja grafiikkapuskurit
int display_init(void);

// Päivittää ruudun sisällön emulaattorin framebufferista
void display_update(VirtualMachine* vm);

// Vapauttaa SDL2-resurssit suljettaessa
void display_cleanup(void);

// Lukee SDL-ikkunan sulkemistapahtumat (hiiri/näppäimistö)
int display_poll_events(void);

#endif // DISPLAY_H
