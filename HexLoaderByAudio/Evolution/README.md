# Introduction

The Hex loader 'evolution' is an improvement of the loader from the FLite
Electronics LTD company and that allows users to load Intel Hex files created
by a PC to the MPF-1 system through a serial link.

The original loader only supports a RS232 link and doesn't support all the
Intel Hex records. This improved version brings extra features:
* Support modern USB-Serial converters that provide TTL levels, while keeping
  the support for RS232.
* Ignore Intel Hex records not relevant for the MPF-1 system, rather then
  failing on errors.

Note: Intel Hex is a common ASCII file format for uploading programs to
embedded systems or for burning an EPROM. It is described here:
[Intel Hex file format](https://en.wikipedia.org/wiki/Intel_HEX)


# Connection between the MPF-1 and the PC

## Cable

The connection of the PC and the MPF-1 is done through the EAR audio input of
the MPF-1. A cable is required:

```
MPF1 (receiver)            Serial emitter

EAR tip    -----<   <-------- TX
    ground -----<   <-------- Ground
```

For modern PCs, there are different USB-Serial converters:
* RS232 converter generates signals with voltages between -V and V (V is typically
  12v, but converters may deliver different voltages like 9v). These converters
  use a DB9 plug.
* TTL converters usually output 4 Dupont cables and will deliver TTL tensions
  between 0 and 3.3v or between 0 and 5v.

All converters will work due to the fact that:
* The MPF-1 clamps input signals to range 0-5v thanks to diodes and resistor
  on EAR input.
* The MPF-1 uses the 74LSxx logic which makes it compatible with 3.3v levels.

But since the MPF-1 systems operates itself with TTL levels, the most natural
converter is a USB-Serial TTL converter delivering a tension between 0 and 5v.
Such converter will minimize the current that has to be dissipated at the EAR
input, compared to a RS232 link.

## PC side: serial terminal program

To send a file on the MPF-1, a serial terminal emulation software is needed on
the PC. For instance, _Tera Term_ can be used under Windows.

It must be configured to use the right COM port as following;
* 2400 bauds
* Data bits: 8
* Parity: None
* Stop bit: 1


# MPF1 side: installation and usage of the MPF-1

## Installation of the loader

In addition to the source assembly code, this repository contains a preassembled
binary code in both Intel Hex and Binary formats. This version was assembled
assuming the loader is placed at address 2000h, then at the beginning of U7.

It is possible to move the loader to a different place in memory. In this case,
the programm will need to be changed (ORG directive, potentially the makefile if
used) and re-assembled.

The natural place for such a loader is an EPROM. It is possible for instance
possible to place it instead of the tiny BASIC in the main EPROM at address 800h,
in case you prefer to keep U7 for another usage (RAM for instance).

## RAM used by the loader

The loader uses the RAM between addresses 1F6Fh and 1F76h included.
The RAM section can be used by other programs, but as soon a the loader is executed,
the content of this section will be changed by the loader.


## Execution

Loading an Intel Hex program is done in multiple steps.
Here, we assume the loader is at address 2000h.

* *Launch the program*:
    * Type on keyboard: 'Addr' 2000 'Go'
* *Offset request*:<br>
  The MPF-1 displays 'Offset'.<br>
  Depending on how you have created the Intel Hex file, it may already contain the
  target address or not. The offset allows you to amend the address of the Hex file
  by adding a fixed offset value to it.
    * No offset (value 0) : 'Go'
    * Offset  : enter hexa offset 'Go'
* *Sound request*:<br>
  The MPF-1 displays 'Sound'.<br>
  When loading a Intel Hex file through the serial link, you may want to hear that
  data are being loaded or not.
    * No sound: 'Go'
    * Sound: any key except 'Go'
* *Plug request*:<br>
  The MPF-1 displays 'Plug'.<br>
  At this stage, the loader asks you to make sure the serial cable is connected
  to the MPF-1. The loader will determine if the serial emitter uses RS232 or TTL
  levels and will automatically know how to interpret data received.
    * Press 'go' when the cable is plugged
    * After pressing the key, the loader will display which type of serial link it
      has detected: 'RS232' or 'TTL'
* *Transmission*:<br>
  After the plug request, the loader will display 'Send', will beep and will display
  '......' to notify that it is now waiting for data on the serial link.

At this stage, you can on the PC side send the Intel Hex file through the properly
configured serial port.