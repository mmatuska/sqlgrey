INSTALL = install -C
ETCDIR = $(ROOTDIR)/etc
SYSCONFDIR = $(ETCDIR)/sysconfig
BINDIR = $(ROOTDIR)/usr/bin
INITDIR = $(ETCDIR)/init.d
MANDIR = $(ROOTDIR)/usr/share/man/man1

all: manpage

manpage:
	perldoc -u sqlgrey | pod2man -n sqlgrey | gzip > sqlgrey.1.gz

clean:
	rm -f sqlgrey.1.gz

install: all
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -d -m 755 $(SYSCONFDIR)
	$(INSTALL) -d -m 755 $(INITDIR)
	$(INSTALL) -d -m 755 $(MANDIR)
	$(INSTALL) sqlgrey $(BINDIR)
	$(INSTALL) etc/sqlgrey $(SYSCONFDIR)
	$(INSTALL) init/sqlgrey $(INITDIR)
	$(INSTALL) sqlgrey.1.gz $(MANDIR)
