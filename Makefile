INSTALL = install -C
ETCDIR = $(ROOTDIR)/etc
SYSCONFDIR = $(ETCDIR)/sysconfig
BINDIR = $(ROOTDIR)/bin
INITDIR = $(ETCDIR)/init.d

install:
	$(INSTALL) sqlgrey $(BINDIR)
	$(INSTALL) etc/sqlgrey $(SYSCONFDIR)
	$(INSTALL) init/sqlgrey $(INITDIR)
