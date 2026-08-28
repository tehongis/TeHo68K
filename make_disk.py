# Tiedosto: make_disk.py
import os
import subprocess

ASM_DIR = "asm"
ROM_DIR = "ROM"
HDD_DIR = "HDD"

def assemble(source_name, output_name):
    # Rakennetaan oikeat polut (esim. asm/ccp.asm -> ROM/ccp.bin)
    source_path = os.path.join(ASM_DIR, source_name)
    output_path = os.path.join(ROM_DIR, output_name)
    
    print(f"Käännetään {source_path} -> {output_path}...")
    
    # Ajetaan vasm oikeilla poluilla
    subprocess.run(["vasmm68k_mot", "-Fbin", "-o", output_path, source_path], check=True)

if __name__ == "__main__":
    # 1. Varmistetaan, että tarvittavat kansiot ovat olemassa
    os.makedirs(ROM_DIR, exist_ok=True)
    os.makedirs(HDD_DIR, exist_ok=True)

    # 2. Käännetään CP/M-moduulit asm-kansiosta suoraan ROM-kansioon
    assemble("ccp.asm", "ccp.bin")
    assemble("bdos.asm", "bdos.bin")
    assemble("bios.asm", "bios.bin")

    # 3. Määritetään luotavien binäärien polut hakuja varten
    ccp_bin_path = os.path.join(ROM_DIR, "ccp.bin")
    bdos_bin_path = os.path.join(ROM_DIR, "bdos.bin")
    bios_bin_path = os.path.join(ROM_DIR, "bios.bin")
    hdd_img_path = os.path.join(HDD_DIR, "virtual_disk.img")

    # 4. Luodaan tyhjä 1 megatavun virtuaalikiintolevykuva
    disk_size = 1024 * 1024
    disk_data = bytearray(disk_size)

    # 5. Luetaan käännetyt osaset muistiin ROM-kansiosta
    with open(ccp_bin_path, "rb") as f: ccp_data = f.read()
    with open(bdos_bin_path, "rb") as f: bdos_data = f.read()
    with open(bios_bin_path, "rb") as f: bios_data = f.read()

    # 6. Sijoitetaan moduulit tarkasti oikeille sektoreille (1 sektori = 512 tavua)
    # Sektori 0: CCP alkaa heti levyn alusta
    disk_data[0:len(ccp_data)] = ccp_data
    
    # Sektori 3: BDOS alkaa mallissasi tavusta 1536
    disk_data[1536:1536+len(bdos_data)] = bdos_data
    
    # Sektori 7: BIOS alkaa mallissasi tavusta 3584
    disk_data[3584:3584+len(bios_data)] = bios_data

    # 7. Tallennetaan valmis kiintolevykuva HDD-kansioon
    with open(hdd_img_path, "wb") as f:
        f.write(disk_data)

    print(f"\nOnnistui! {hdd_img_path} on valmis ja ladattu CP/M-moduuleilla.")
