INSTALL = install -C
ETCDIR = $(ROOTDIR)/etc
SYSCONFDIR = $(ETCDIR)/sysconfig
BINDIR = $(ROOTDIR)/bin
INITDIR = $(ETCDIR)/init.d

install:
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -d -m 755 $(SYSCONFDIR)
	$(INSTALL) -d -m 755 $(INITDIR)
	$(INSTALL) sqlgrey $(BINDIR)
	$(INSTALL) etc/sqlgrey $(SYSCONFDIR)
	$(INSTALL) init/sqlgrey $(INITDIR)
