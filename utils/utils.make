#===============================================================================
# This utility makefile compiled a Z80 assembly program and generates both
# a .bin and a .hex (Intel hex) file containing the assembled program.
# It also generates a listing file (.listing extension).
#
# It takes as input the following variables :
# - SRC: a single assembly file
# - PROGRAM_ADDR: The targeted load address in C like hex format (0x....)
#
# - BURN_ROM (optional):
#   defined in case the .hex file is intended to be used for burning an EPROM
#   or EEPROM. In this case, the following variable must also be defined:
#   - ROM_BASE_ADDR : base address of the ROM chip in the system in which the
#                     assembled program will reside. The addresses of the
#                     generated Hex file will be relative to this ROM_BASE_ADDR
#                     address base
# - In case BURN_ROM is not defined, the program will be compiled to be loaded
#   by a a system loader meaning that the addresses in the Hex file will be the
#   the target address in the system memory mapping (LOAD_ADDR)
#===============================================================================

#-----------------------------------------
# Determine the hex file start address
#-----------------------------------------

ifdef BURN_ROM
  # When burning an EPROM, the base address may be 0
  # in the hex file should be (PROGRAM_ADDR - ROM_ADDR)
  ifndef ROM_BASE_ADDR
	$(error 'BURN_ROM' was defined but not 'ROM_BASE_ADDR')
  endif
  PROGRAM_ADDR_DEC= $(shell printf "%d" $(PROGRAM_ADDR))
  ROM_BASE_ADDR_DEC= $(shell printf "%d" $(ROM_BASE_ADDR))
  HEX_START_ADDR= $(shell echo $$(( $(PROGRAM_ADDR_DEC) - $(ROM_BASE_ADDR_DEC) )) )
else
  # For a runtime loader on the target hardware, the Hex start address
  # should just be the target load address
  HEX_START_ADDR= $(PROGRAM_ADDR)
endif


#-----------------------------------------
# Assembly rules
#-----------------------------------------

ASM= z80asm

LISTING= $(SRC:.asm=.listing)
BIN= $(SRC:.asm=.bin)
HEX= $(SRC:.asm=.hex)

all: $(HEX)

$(LISTING) $(BIN) : $(SRC)
	$(ASM) $< -l --output $(BIN) 2> $(LISTING)

$(HEX) : $(BIN)
	@echo "# Create Hex file at start address" $(HEX_START_ADDR)
	objcopy -I binary $< -O ihex $@ --change-addresses $(HEX_START_ADDR)

clean:
	rm -f $(HEX) $(LISTING) $(BIN)

