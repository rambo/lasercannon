#!/usr/bin/python
import sys


from PyQt4 import QtGui, QtCore
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
        
        self.tool_buttons = QtGui.QButtonGroup()

        line_button = QtGui.QToolButton()
        self.connect(line_button, QtCore.SIGNAL('clicked()'), self.line_button_clicked) 
        line_button.setCheckable(True)
        line_button.setText("Line")
        self.tool_buttons.addButton(line_button, 1)
        vbox.addWidget(line_button)
        line_button.click()

        circle_button = QtGui.QToolButton()
        self.connect(circle_button, QtCore.SIGNAL('clicked()'), self.circle_button_clicked) 
        circle_button.setCheckable(True)
        circle_button.setText("Circle")
        self.tool_buttons.addButton(circle_button, 2)
        vbox.addWidget(circle_button)

        vbox.addStretch()
        
        main_container = QtGui.QWidget()
        main_container.setLayout(hbox)
        self.setCentralWidget(main_container)

        self.center()
        pass

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

# Based on example from http://www.commandprompt.com/community/pyqt/x2765
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
            rx = abs(self.startPos.x() - self.currentPos.x())
            ry = abs(self.startPos.y() - self.currentPos.y())
            # The Arduino FW handles only circles now. NOTE: strictly speaking we should solve the hypotenuse and use that as r...
            if ( ry >= rx):
                r = ry
            else:
                r = rx
            self.p.drawEllipse(self.startPos, r, r)


        self.p.end()
        self.repaint()

    def mousePressEvent(self, ev):
        self.blit(self.backupbuffer, self.buffer)
        self.currentPos = QtCore.QPoint(ev.pos())
        self.startPos = QtCore.QPoint(ev.pos())

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