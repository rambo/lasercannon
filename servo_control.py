#!/opt/local/bin/python -i 
# -*- coding: utf-8 -*-

import serial, time
from datetime import datetime



class lasercannon:
    def __init__(self, port):
        self.last_read = 0
        self.port = port
        self.servos = 2
        self.lasers = 1
        # Limit servo travel due to HW constraints
        self.limits = [
        ]
        # Reverse servos so that 0,0 is always top-left
        self.servo_reverse = [
            False,
            True,
        ]
        
        self._char_buffer = ''
        self._input_buffer = []

        self.reset_and_enable()

    def reset_and_enable(self):
        self.print_input_buffer()

    def enable_laser(self, channel = 0):
        """Enable given laser channel"""
        pass

    def disable_laser(self, channel = 0):
        pass

    def send_command(self, command):
        # I think this byte-by-byte CTS checking should not be neccessary but lets be sure
        command = command + "\n"
        for c in command:
            if self.port.rtscts:
                # This should not be neccessary (i think)
                while port.getCTS() != True:
                    print 'DEBUG: waiting for CTS'
                    time.sleep(0.001) # sleep 1ms each time port is not ready
            self.read_and_check_xoff()
            self.port.write(c)
        self.port.flush()
        self.read_and_check_xoff()
        #print 'DEBUG: sent command ' + command.encode('hex')
        print 'DEBUG: sent command (binary) ' + string_to_bin(command)
        tsobj = datetime.now()
        uts = int(tsobj.strftime('%H%M%S') +  str(tsobj.microsecond).rjust(6,'0'))
        #print 'DEBUG: uts(%s) - last_read(%s): %s' % (uts, self.last_read, (uts - self.last_read),)
        if (uts - self.last_read) > 10000: # 0.1 second since last buffer read, print buffers
            self.read_print_input_buffer()
            self.last_read = uts

    def set_read_timer(self):
        import signal
        signal.signal(signal.SIGALRM, self.alarm_handler)
        signal.alarm(1)
    
    def alarm_handler(self, *args):
        import signal
        self.read_print_input_buffer()
        signal.alarm(1)

    def read_and_check_xoff(self):
        while self.port.inWaiting() > 0:
            self._char_buffer += self.port.read()
            #print "Char buffer now: %s" % repr(self._char_buffer)
            if (    len(self._char_buffer) > 0
                and self.port.xonxoff):
                if self._char_buffer[-1] == chr(0x13):
                    print "DEBUG: XOFF detected"
                    self.print_input_buffer()
                    while True:
                        time.sleep(0.001) # sleep 1ms each time port is not ready
                        self._char_buffer += self.port.read()
                        print 'DEBUG: waiting for XON, last char is %s' % repr(self._char_buffer[-1])
                        try:
                            if self._char_buffer[-1] == chr(0x11):
                                print "DEBUG: XON detected"
                                break
                        except IndexError:
                            pass
                        self.check_buffer_line()
                    self.print_input_buffer()
            self.check_buffer_line()

    def check_buffer_line(self):
        if (    len(self._char_buffer) > 1
            and self._char_buffer[-2:] == "\r\n"):
                self._input_buffer.append(self._char_buffer)
                #print "DEBUG: Put %s to buffer" % repr(self._char_buffer)
                self._char_buffer = ''

    def read_print_input_buffer(self):
        self.read_and_check_xoff()
        self.print_input_buffer()

    def print_input_buffer(self):
        #self._input_buffer += self.port.readlines()
        for line in self._input_buffer:
            print "INPUT: " + repr(line).strip("'")
#        if self._char_buffer:
#            print "DEBUG: char buffer: " + repr(self._char_buffer)
        self._input_buffer = []

    def hacklab(self, f_origo = (200,500), radius = 100):
        import math
        self.circle(radius, f_origo)
        s_line_x = round(f_origo[0] + math.cos(math.radians(45)) * radius)
        s_line_y = round(f_origo[1] + math.sin(math.radians(45)) * radius)
        print "s_line_x=%d, s_line_y=%d\n" % (s_line_x, s_line_y)
        # Wait for all servos in between
        self.send_command("y");
        self.line((s_line_x, s_line_y),  (s_line_x+50, s_line_y+50))
        self.send_command("y");
        self.line((s_line_x+50, s_line_y+50), (s_line_x+50+300, s_line_y+50))
        e_line_x = round(s_line_x+50+300 + math.cos(math.radians(315)) * 50)
        e_line_y = round(s_line_y+50 + math.sin(math.radians(315)) * 50)
        print "e_line_x=%d, e_line_y=%d\n" % (e_line_x, e_line_y)
        self.send_command("y");
        self.line((s_line_x+50+300, s_line_y+50), (e_line_x, e_line_y))
        self.send_command("y");
        self.circle(radius, (f_origo[0], f_origo[1]+600))
        self.send_command("y");
        

    def servo_position(self, channel, position):
        raise Exception("Not implemented")

    def xy(self, x, y, start_channel = 0):
        raise Exception("Not implemented")

    def span(self, drange, radius, origo = (500, 500), start_channel = 0):
        raise Exception("Not implemented")

    def line(self, start = (100,100), end = (900,900), start_channel = 0):
        self.send_command("C" + chr(start_channel+1) + int2bytes(start[0]) + int2bytes(start[1]) + int2bytes(end[0]) + int2bytes(end[1]))

    def circle(self, radius, origo = (500, 500), start_channel = 0, step = 8):
        self.send_command("E" + chr(start_channel+1) + int2bytes(radius) + int2bytes(origo[0]) + int2bytes(origo[1]) + chr(step))


    def _curses_interactive(self, screen, start_channel = 0):
        raise Exception("Not implemented")
        self.reset_and_enable()
        x = 500
        y = 500
        step = 2
        laser_toggle = True
        key = ''
        while True:
            c = screen.getch()
            # output keycodes if possible (helps debugging)
            try:
                screen.addstr('keycode: ' + str(c) + ' repr: ' + repr(chr(c)) + '\n')
            except:
                pass
                
            # Check read keycode
            if c == 0x04: # ctrl-d, break out of loop
                break
            if c == 0x1b: # arrow-key, read two characters more
                key = chr(c) + chr(screen.getch()) + chr(screen.getch())
            if c > 0xff:
                screen.addstr("Got c " + repr(c))
            else:
                key = chr(c)
            
            # Up, Down, Left, Right move servos
            if key == '\x1b\x5b\x41':
                limited = self.servo_position(start_channel+1, y-step)
                if not limited:
                    y = y-step
            if key == '\x1b\x5b\x42':
                limited = self.servo_position(start_channel+1, y+step)
                if not limited:
                    y = y+step
            if key == '\x1b\x5b\x44':
                limited = self.servo_position(start_channel, x-step)
                if not limited:
                    x = x-step
            if key == '\x1b\x5b\x43':
                limited = self.servo_position(start_channel, x+step)
                if not limited:
                    x = x+step

            # Space toggles laser
            if key == '\x20':
                if laser_toggle:
                    self.disable_laser(0)
                    laser_toggle = False
                else:
                    self.enable_laser(0)
                    laser_toggle = True

        # Loop ends here
        
    
    def interactive(self, start_channel = 0):
        import curses
        screen = curses.initscr()
        curses.wrapper(self._curses_interactive, start_channel)

def int2bytes(i_input):
    i_input = int(i_input)
    return chr(i_input >> 8) + chr(i_input & 0x00ff)

def ascii_to_bin(char):
    ascii = ord(char)
    bin = []

    while (ascii > 0):
        if (ascii & 1) == 1:
            bin.append("1")
        else:
            bin.append("0")
        ascii = ascii >> 1

    bin.reverse()
    binary = "".join(bin)
    zerofix = (8 - len(binary)) * '0'
    return zerofix + binary

def string_to_bin(s):
    bin = []
    for char in s:
        bin.append(ascii_to_bin(char))
    return " ".join(bin)

def print_arduino_bauds():
    for n in range(1,50):
        print 16000000/(16 * n)

if __name__ == "__main__":
    DEVICE='/dev/tty.usbserial-A900cbdG'
    port = serial.Serial(DEVICE, 57600, xonxoff=False, timeout=0.00001)
    time.sleep(0.5)
    c = lasercannon(port)
    c.set_read_timer()
