INSTALL = install
ETCDIR = $(ROOTDIR)/etc
CONFDIR = $(ETCDIR)/sqlgrey
BINDIR = $(ROOTDIR)/usr/bin
INITDIR = $(ETCDIR)/init.d
MANDIR = $(ROOTDIR)/usr/share/man/man1

VERSION := $(shell cat VERSION)
TBZ2 = sqlgrey-$(VERSION).tar.bz2

all: manpage sqlgrey-recreate sqlgrey.spec-recreate

sqlgrey-recreate:
	cat sqlgrey | sed 's/^my $$VERSION = .*;/my $$VERSION = "$(VERSION)";/' > sqlgrey.new
	mv sqlgrey.new sqlgrey
	chmod a+x sqlgrey

sqlgrey.spec-recreate:
	cat sqlgrey.spec | sed 's/^%define ver  .*/%define ver  $(VERSION)/' > sqlgrey.spec.new
	mv sqlgrey.spec.new sqlgrey.spec

manpage:
	perldoc -u sqlgrey | pod2man -n sqlgrey > sqlgrey.1

clean:
	rm -f sqlgrey.1
	rm -f *~ init/*~ etc/*~

install: all
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -d -m 755 $(ETCDIR)
	$(INSTALL) -d -m 755 $(CONFDIR)
	$(INSTALL) -d -m 755 $(INITDIR)
	$(INSTALL) -d -m 755 $(MANDIR)
	$(INSTALL) sqlgrey $(BINDIR)
	$(INSTALL) etc/sqlgrey.conf $(CONFDIR)
	$(INSTALL) etc/clients_ip_whitelist $(CONFDIR)
	$(INSTALL) etc/clients_fqdn_whitelist $(CONFDIR)
	$(INSTALL) sqlgrey.1 $(MANDIR)

rh-install: install
	$(INSTALL) init/sqlgrey $(INITDIR)

gentoo-install: install
	$(INSTALL) init/sqlgrey.gentoo $(INITDIR)/sqlgrey

tbz2: all clean
	cd ..;ln -s sqlgrey sqlgrey-$(VERSION);tar cjhf $(TBZ2) sqlgrey-$(VERSION);rm sqlgrey-$(VERSION)

rpm: tbz2
	rpmbuild -ta ../$(TBZ2)
