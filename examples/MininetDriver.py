#!/usr/bin/python
import socket
from subprocess import Popen, call
from mininet.node import RemoteController, OVSKernelSwitch
from mininet.net import Mininet
import mininet.topolib
import mininet.topo
import re
import os
from time import gmtime, strftime

CONTROLLER_PATH = "./dist/build/frenetic-example-suite/frenetic-example-suite"

TreeTopo = mininet.topolib.TreeTopo
LinearTopo = mininet.topo.LinearTopo

def is_ipv6_enabled():
  lines = 0
  fh = open("/proc/net/if_inet6")
  return len([l for l in fh]) > 0

class PaneException(Exception):
  pass

def quiet_system(cmd):
  fnull = open(os.devnull, 'w')
  result = call(cmd, shell = True, stdout = fnull, stderr = fnull)
  fnull.close()

def kill_controllers():
  quiet_system('lsof | grep "TCP \\*:6633 (LISTEN)" | cut -d " " -f 2 | \
    xargs kill')


class MininetRunner(object):

  def __init__(self, topo, controller):
    # Mininet can cleanup after itself
    quiet_system('mn -c')
    self.controller = controller
    self.net = Mininet(topo=topo,controller=RemoteController,switch=OVSKernelSwitch)
    self.net.start()
    self.hosts = self.net.hosts

  def destroy(self):
    if hasattr(self, 'net'):
      self.net.stop()
      delattr(self, 'net')
    if hasattr(self, 'controller'):
      self.controller.kill()
      delattr(self, 'controller')

  def __del__(self):
    self.destroy()

  def ping(self, src, dst, interval, count):
    cmd = 'ping -i %s -c%s %s' % (interval, count, dst.IP())
    out = src.cmd(cmd)
    m = re.search(r"(\d+)% packet loss", out)
    if m == None:
      raise PaneException("%s output was %s" % (cmd, out))
    return int(m.group(1))

def time():
  return strftime("%Y-%m-%d %H:%M:%S", gmtime())
