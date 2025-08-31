# This file contains all the UART commands, 
# for communication with electro-optical modulator FPGA driver.
# All commands are in the hexadecimal format.

START_BYTE = 0x55

START_SEQUENCE = 0x41
STOP_SEQUENCE = 0x42
CLEAR_SEQUENCE = 0x43

SEQUENCE_PERIOD = 0x44
SEQUENCE_DELAY = 0x45
LD_PULSE_WIDTH = 0x46
LD_DELAY = 0x47

WINDOW_DATA = 0x52


# Response codes from UART FPGA
CHECKSUM_OK = 0x01.to_bytes(1,byteorder='big')
START_BYTE_ERROR = 0x02.to_bytes(1,byteorder='big')
CHECKSUM_ERROR = 0x03.to_bytes(1,byteorder='big')
COMMAND_ERROR = 0x04.to_bytes(1,byteorder='big')
SUCCESS = 0x05.to_bytes(1,byteorder='big')

