#!/usr/bin/python
import sys, threading

# Either PyQT4 or PySide is fine
try:
    from PyQt4 import QtGui, QtCore
except:
    from PySide import QtGui, QtCore

from lasercannon import *
import math

# try:
#     from PyQt4.QtOpenGL import QGLWidget, QGLPixelBuffer
#     QtGui.QWidget = QGLWidget
#     QtGui.QPixmap = QGLPixelBuffer
# except Exception, e:
#     # import traceback
#     print "Got exception when trying make magical GLWidgets"
#     print e

class lasercannon_gui(QtGui.QMainWindow):
    def __init__(self):
        QtGui.QMainWindow.__init__(self)
        
        self.serial_port = None
        self.backend = None
        
        self.paintarea = Painting()
        self.paintarea.callback = self.draw_callback

        screen = QtGui.QDesktopWidget().screenGeometry()
        if (   screen.height() < 1000
            or screen.width() < 1100):
            # 500x500 paint area
            self.paintarea.setGeometry(0,0,500,500)
            self.setGeometry(0,0,600,500)
            self.xyfactor = 2
        else:
            # 1000x1000 paint area
            self.paintarea.setGeometry(0,0,1000,1000)
            self.setGeometry(0,0,1100,1000)
            self.xyfactor = 1

        hbox = QtGui.QHBoxLayout()
        vbox = QtGui.QVBoxLayout()
        hbox.addLayout(vbox)
        hbox.addWidget(self.paintarea)

        ## Grouped toggle-buttons for the drawing tools        
        self.tool_buttons = QtGui.QButtonGroup()

        line_button = QtGui.QToolButton()
        self.connect(line_button, QtCore.SIGNAL('clicked()'), self.line_button_clicked) 
        line_button.setCheckable(True)
        line_button.setText("Line")
        self.tool_buttons.addButton(line_button)
        vbox.addWidget(line_button)
        line_button.click()

        circle_button = QtGui.QToolButton()
        self.connect(circle_button, QtCore.SIGNAL('clicked()'), self.circle_button_clicked) 
        circle_button.setCheckable(True)
        circle_button.setText("Circle")
        self.tool_buttons.addButton(circle_button)
        vbox.addWidget(circle_button)

        ## Buttons for other things (clear, terminal view, etc)
        clear_button = QtGui.QToolButton()
        self.connect(clear_button, QtCore.SIGNAL('clicked()'), self.paintarea.clear) 
        clear_button.setText("Clear")
        vbox.addWidget(clear_button)
        
        # TODO: Make work like Hildon touchselector (or even just a simple button) to conserve screen estate
        serial_port_select = QtGui.QComboBox()
        serial_port_select.setInsertPolicy(QtGui.QComboBox.InsertAlphabetically)
        serial_port_select.addItems(QtCore.QStringList(['select port',] + self.get_serial_ports()))
        self.connect(serial_port_select, QtCore.SIGNAL('currentIndexChanged(const QString&)'), self.serial_port_changed) 
        #serial_port_select.setEditable(True)
        #self.connect(serial_port_select, QtCore.SIGNAL('editTextChanged (const QString&)'), self.serial_port_changed) 
        vbox.addWidget(serial_port_select)
        

        # "Packing"
        vbox.addStretch()

        # Make a dummy widget to contain our layout and make it the "CentralWidget"
        main_container = QtGui.QWidget()
        main_container.setLayout(hbox)
        self.setCentralWidget(main_container)

        # Center the window
        self.center()
        pass

    def get_serial_ports(self):
        import os, fnmatch, re
        path = '/dev'
        regex = re.compile('ttys.+|ttyUSB.+|tty.usb.+|ttyS.+')
        return [os.path.join(path, x) for x in filter(lambda item: bool(regex.search(item)), os.listdir(path))]

    def serial_port_changed(self, port):
        import serial
        self.serial_port = serial.Serial(str(port), 57600, timeout=0)
        # TODO: Swicth to QT threads ?
        self.backend = lasercannon_serial_backend(self.serial_port)
        self.receiver_thread = threading.Thread(target=self.serial_reader)
        self.receiver_thread.setDaemon(1)
        self.receiver_thread.start()

    def serial_reader(self):
        alive = True
        try:
            while alive:
                data = self.serial_port.read(1)
                # TODO: hex-encode unprintable characters
                # TODO: Write a a text buffer that can be shown in separate window/tab instead of stdout
                sys.stdout.write(data)
        except serial.SerialException, e:
            self.alive = False


    def line_button_clicked(self, *args):
        self.paintarea.tool = 'line'

    def circle_button_clicked(self, *args):
        self.paintarea.tool = 'circle'

    def center(self):
        screen = QtGui.QDesktopWidget().screenGeometry()
        size =  self.geometry()
        self.move((screen.width()-size.width())/2, (screen.height()-size.height())/2)
    
    def draw_callback(self, *args):
        """ Data is a tuple with tool, startpoint & endpoint """
        #print "callback data %s" % data_tuple
        print "callback args %s" % args
        data = args[0]
        tool = data[0]
        print tool
        if (tool == 'clear'):
            self.backend.clear()
        if (tool == 'line'):
            #print "start_x=%d, start_y=%d, end_x=%d, end_y=%d" % (data[1].x(), data[1].y(), data[2].x(), data[2].y())
            self.backend.line((data[1].x(), data[1].y()), (data[2].x(), data[2].y()))
        if (tool == 'circle'):
            origo = (data[0].x(), data[0].y())
            r = int(round(helpers().point_distance(origo, (data[1].x(), data[1].y()))))
            self.backend.circle(r, origo)


class helpers:
    def point_distance(self, point1=(0,0), point2=(1,3)):
        """Calculate distance between two points"""
        return math.sqrt(math.pow(point1[0]-point2[0], 2) + math.pow(point1[1]-point2[1], 2))


# Based on example from http://www.commandpromptndprompt.com/community/pyqt/x2765
class Painting(QtGui.QWidget):

    def __init__(self, *args):
#        apply(QtGui.QWidget.__init__,(self, ) + args)
        QtGui.QWidget.__init__(self, *args)
        self.buffer = QtGui.QPixmap()
        self.backupbuffer = QtGui.QPixmap()
        self.currentPos = QtCore.QPoint(0,0)
        self.callback = None
        self.tool = None

    def blit(self, target, source):
        """ 'blits' a pixmap to target, done this way since QT4 and thus PyQt4 does not have bitBlt() -function """
        p = QtGui.QPainter()
        p.begin(target)
        p.drawPixmap(0, 0, source)
        p.end()

    def paintEvent(self, ev):
        # blit the pixmap
        self.blit(self, self.buffer)
        pass

    def mouseReleaseEvent(self, ev):
        self.blit(self.backupbuffer, self.buffer)
        data = (self.tool, self.startPos, ev.pos())
        self.callback(data)

    def mouseMoveEvent(self, ev):
        self.p = QtGui.QPainter()
        self.currentPos = QtCore.QPoint(ev.pos())
        #print "mouseMoveEvent positions %s" % self.currentPos
        self.blit(self.buffer, self.backupbuffer)
        self.p.begin(self.buffer)

        if (self.tool == 'line'):
            self.p.drawLine(self.startPos, self.currentPos)
        if (self.tool == 'circle'):
            r = int(round(helpers().point_distance((self.startPos.x(), self.startPos.y()), (self.currentPos.x(), self.currentPos.y()))))
            # The Arduino FW handles only circles now
            self.p.drawEllipse(self.startPos, r, r)

        self.p.end()
        self.repaint()

    def mousePressEvent(self, ev):
        self.blit(self.backupbuffer, self.buffer)
        self.currentPos = QtCore.QPoint(ev.pos())
        self.startPos = QtCore.QPoint(ev.pos())

    def clear(self, *args):
        #print "clear called"
        self.backupbuffer.fill()
        self.blit(self.buffer, self.backupbuffer)
        self.callback(('clear',))
        self.repaint()

    def resizeEvent(self, ev):
        # TODO: recalculate the xyfactor and limit the paintarea size accordingly
        tmp = QtGui.QPixmap(self.buffer.size())
        self.blit(tmp, self.buffer)
        self.buffer = QtGui.QPixmap(ev.size())
        self.backupbuffer = QtGui.QPixmap(ev.size())
        self.buffer.fill()
        self.backupbuffer.fill()
        self.blit(self.buffer, tmp)
        self.blit(self.backupbuffer, self.buffer)

if __name__ == "__main__":
    app = QtGui.QApplication(sys.argv)
    gui = lasercannon_gui()
    gui.show()
    sys.exit(app.exec_())
