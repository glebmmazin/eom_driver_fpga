# This file contains the code which communicates with the EOM driver FPGA board,
# and sets all the neccessary paremeters for the experiment. 
# Each command below has its own description, behavior, inputs and outputs in the dedicated comment above the function declaration.  

#----------------------------EOM output timing diagram-----------------------------#
#                                                                                  #
#Trigger______|¯¯|_________________________________________________________________:
#             :                  :                                                 :
#             :<----LD delay---->:                                                 :
#             :                  :                                                 :
#LD pulse_____:__________________|¯¯|______________________________________________:
#             :                          :                                         :
#             :<-----sequence delay----->:                                         :
#             :                          :                                         :
#Chann 11¯¯¯¯¯:¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__|¯¯|__|¯¯. . .¯¯|__|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯:
#             :                                                                    :
#Chann 12¯¯¯¯¯:¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__|¯¯|__|¯¯. . .¯¯|__|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯:
#. . .        :                                                                    :
#. . .        :                                                                    :
#Chann 23¯¯¯¯¯:¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|__|¯¯|__|¯¯. . .¯¯|__|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯:
#             :                            0-----1---. . .----N----window number---:  
#             :                                                                    :
#Chann ENA¯¯¯¯|___________________________________________. . .___|¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯: 
#             :                                                                    :
#             :---------------<----sequence period---->----------------------------:
#
####################################################################################
#           
# Chann XY    :¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯|_________________|¯¯¯¯¯¯¯¯|_________________|¯¯¯¯¯¯¯:
#                             :<window number>  :        :<window number>  :       :
#                             :<--pulse width-->:        :<--pulse width-->:       :
#                             :<--window width---------->:<--window width--------->:      

#Trigger and LD pulse have positive LVTTL logic
# Chann 11-23 and chann ENA have negative LVTTL logic

#---Timing specifications---#
# System clock of the device is 300MHz (3.3333 ns), therefore it is minimal possible time increment    
# All time relevant parameters used in functions below will set corresponding time values in the FPGA as a number of system clock cycles, i.e. 3.3333 ns


import serial
import time
import struct
import numpy as np
import eom_uart_commands as eom


serialInst = serial.Serial(port='COM3', 
                        baudrate=115200, 
                        bytesize=serial.EIGHTBITS,
                        parity=serial.PARITY_NONE,
                        stopbits=serial.STOPBITS_ONE, 
                        timeout=1,
                        xonxoff=False,
                        rtscts=False,
                        write_timeout=None,
                        dsrdtr=False, 
                        inter_byte_timeout=None, 
                        exclusive=None)


def uart_send_message(buf):
      while True:
            if serialInst.out_waiting == 0:
                  break
      for b in buf:
            a = struct.pack( "B", b )
            serialInst.write(a)
            time.sleep(0.1)
      serialInst.flush()
      response = serialInst.read()
      if response == eom.START_BYTE_ERROR: 
           print("START BYTE ERROR")
      elif response == eom.CHECKSUM_ERROR: 
           print("WRONG CHECKSUM")
      elif response == eom.COMMAND_ERROR: 
           print("WRONG COMMAND")
      elif response == eom.SUCCESS: 
           print("SUCCESS")
      elif response == eom.CHECKSUM_OK:
           print("CHECKSUM OK")
      else:
           print("UKNOWN ERROR", response)
      
      #serialInst.close()

def calc_checksum(s):
    sum = 0x00
    for c in s:
        sum += c
    sum = sum % 256
    return sum #.to_bytes(1,'big', signed=False) 

def start_sequence():
     body = [eom.START_BYTE, eom.START_SEQUENCE, 0x00, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)

def stop_sequence():
     body = [eom.START_BYTE, eom.STOP_SEQUENCE, 0x00, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)
     

# Sets sequence period(within range of 20-200 us), value must be in range 20-200
def set_sequence_period(val):
     if val < 20 or val > 200:
          raise Exception("Sequence period value must be in the range of 20-100")
     body = [eom.START_BYTE, eom.SEQUENCE_PERIOD, val, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)
     

# Sets sequence delay (relative to trigger), value must be in range 0-255 
def set_sequence_delay(val):
     if val < 0 or val > 255:
          raise Exception("Sequence delay value must be in the range of 0-255")
     body = [eom.START_BYTE, eom.SEQUENCE_DELAY, val, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)


# Sets laser diode pulse width, value must be in range 1-255 
def set_LD_pulse_width(val):
     if val < 1 or val > 255:
          raise Exception("LD pulse width value must be in the range of 1-255")
     body = [eom.START_BYTE, eom.LD_PULSE_WIDTH, val, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)


# Sets laser diode pulse delay (relative to trigger), value must be in range 0-255 
def set_LD_pulse_delay(val):
     if val < 0 or val > 255:
          raise Exception("LD pulse delay value must be in the range of 0-255")
     body = [eom.START_BYTE, eom.LD_DELAY, val, 0x00,  0x00, 0x00, 0x00]
     body.append(calc_checksum(body))
     uart_send_message(body)




# sets sequence data within one time window
# Whole sequence in then programmed window by window 
# Parameter window_number = 0...N, see comment header in the beggining of the file 
# Parameters window_width, pulse_width are set as integers
# Real time values are then integer multipliers of the system clock, i.e. 3.3333 ns
# example: window_width = 18 => 18 * 3.3333 ns  ~= 60 ns 
# Sequence memory size is 1024 x 8 bits
# The maximal number of time windows = 1024 / window_width
# example: for 60 ns window, parameter window_width = 18
# 1024/18 ~= 56 time windows  
# channels_data must be set in a binary format as follows: 0b11 + ch23ch22ch21ch13ch12ch11
# where ch23-ch11 are values for the respective channels
# example: 0b11 + 001100 = 0b11001100.  
# remember that we use inverted logic for channels, i.e. 1 = logic LOW state, 0 = logic HIGH state

def write_sequence_window(window_number, window_width, pulse_width, channels_data):
    if pulse_width >= window_width: 
        raise Exception("pulse width within widnow must be less than window width!")
    print("Maximal window number for inputted window_width is: " + str(np.floor(1024/window_width))) 
    body = [eom.START_BYTE, eom.WINDOW_DATA, window_number, window_width,  pulse_width, channels_data, 0x00]
    body.append(calc_checksum(body))
    uart_send_message(body)
     

















