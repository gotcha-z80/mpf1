#-----------------------------------------
# Program information
#-----------------------------------------

# The program is not relocable and should be at address PROGRAM_ADDR
# in the target system
SRC= HEX-1BP-RS232.asm
PROGRAM_ADDR= 0x2000


# Compile the loader to reside at the beginning of the U7 EPROM
# (mapped at 0x2000).
# We request the generation of an Hex file for burning an EPROM
BURN_ROM= 1
ROM_BASE_ADDR= 0x2000


#-----------------------------------------
# Utility makefile with compilation rules
#-----------------------------------------
include ../../utils/utils.make
