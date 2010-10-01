#!/usr/bin/python
import sys


from PyQt4 import QtGui, QtCore
from lasercannon import *


class lasercannon_gui(QtGui.QMainWindow):
    def __init__(self):
        QtGui.QMainWindow.__init__(self)
        self.paintarea = Painting(self)
        self.setCentralWidget(self.paintarea)
        
        pass

# Based on example from http://www.commandprompt.com/community/pyqt/x2765
class Painting(QtGui.QWidget):

    def __init__(self, *args):
        apply(QtGui.QWidget.__init__,(self, ) + args)
        self.buffer = QtGui.QPixmap()
        self.currentPos = QtCore.QPoint(0,0)

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

    def mouseMoveEvent(self, ev):
        self.p = QtGui.QPainter()
        self.p.begin(self.buffer)
        self.p.drawLine(self.currentPos, ev.pos())
        self.currentPos = QtCore.QPoint(ev.pos())
        self.p.end()
        self.repaint()
                
    def mousePressEvent(self, ev):
        self.p = QtGui.QPainter()
        self.p.begin(self.buffer)
        self.p.drawPoint(ev.pos())
        self.currentPos = QtCore.QPoint(ev.pos())
        self.p.end()
        self.repaint()
        
    def resizeEvent(self, ev):
        tmp = QtGui.QPixmap(self.buffer.size())
        self.blit(tmp, self.buffer)
        self.buffer = QtGui.QPixmap(ev.size())
        self.buffer.fill()
        self.blit(self.buffer, tmp)


if __name__ == "__main__":
    app = QtGui.QApplication(sys.argv)
    gui = lasercannon_gui()
    gui.show()
    sys.exit(app.exec_())