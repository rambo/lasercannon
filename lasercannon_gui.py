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
        self.paintarea = Painting(self)
        self.setCentralWidget(self.paintarea)
        self.paintarea.callback = self.draw_callback
        pass
    
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
        self.tool = 'line'
        self.tool = 'circle'

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
            # The Arduino FW handles only circles now
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