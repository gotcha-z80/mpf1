#-----------------------------------------
# Program information
#-----------------------------------------

# The program is not relovcable and should be at address LOAD_ADDR
# in the target system
SRC= HEX-1BP-RS232.asm
LOAD_ADDR= 0x2000


#-----------------------------------------
# Determine the hex file start address
#-----------------------------------------

ifdef EPROM
  # When burning an EPROM, the base address may be 0
  # in the hex file should be (LOAD_ADDR - ROM_ADDR)
  ROM_BASE_ADDR= 0x2000
  LOAD_ADDR_DEC= $(shell printf "%d" $(LOAD_ADDR))
  ROM_BASE_ADDR_DEC= $(shell printf "%d" $(ROM_BASE_ADDR))
  HEX_START_ADDR= $(shell echo $$(( $(LOAD_ADDR_DEC) - $(ROM_BASE_ADDR_DEC) )) )
else
  # For a dynamic loader on the target hardware, the hex start address
  # should just be the load address
  HEX_START_ADDR= $(LOAD_ADDR)
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


