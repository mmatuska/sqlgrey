INSTALL = install
ETCDIR = $(ROOTDIR)/etc
CONFDIR = $(ETCDIR)/sqlgrey
SBINDIR = $(ROOTDIR)/usr/sbin
BINDIR = $(ROOTDIR)/usr/bin
INITDIR = $(ETCDIR)/init.d
MANDIR = $(ROOTDIR)/usr/share/man/man1

VERSION := $(shell cat VERSION)
TBZ2 = sqlgrey-$(VERSION).tar.bz2

all: manpage update-version

update-version:
	cat sqlgrey | sed 's/^my $$VERSION = .*;/my $$VERSION = "$(VERSION)";/' > sqlgrey.new
	mv sqlgrey.new sqlgrey
	chmod a+x sqlgrey
	cat sqlgrey.spec | sed 's/^%define ver  .*/%define ver  $(VERSION)/' > sqlgrey.spec.new
	mv sqlgrey.spec.new sqlgrey.spec
	cat sqlgrey-logstats.pl | sed 's/^my $$VERSION = .*;/my $$VERSION = "$(VERSION)";/' > sqlgrey-logstats.pl.new
	mv sqlgrey-logstats.pl.new sqlgrey-logstats.pl
	chmod a+x sqlgrey-logstats.pl

manpage:
	perldoc -u sqlgrey | pod2man -n sqlgrey > sqlgrey.1

clean:
	rm -f sqlgrey.1
	rm -f *~ init/*~ etc/*~

install: all
	$(INSTALL) -d -m 755 $(SBINDIR)
	$(INSTALL) -d -m 755 $(ETCDIR)
	$(INSTALL) -d -m 755 $(CONFDIR)
	$(INSTALL) -d -m 755 $(INITDIR)
	$(INSTALL) -d -m 755 $(MANDIR)
	$(INSTALL) -d -m 755 $(BINDIR)
	$(INSTALL) -m 755 sqlgrey $(SBINDIR)
	$(INSTALL) -m 755 update_sqlgrey_config $(SBINDIR)
	$(INSTALL) -m 755 sqlgrey-logstats.pl $(BINDIR)
	$(INSTALL) -m 644 etc/sqlgrey.conf $(CONFDIR)
	$(INSTALL) -m 644 etc/clients_ip_whitelist $(CONFDIR)
	$(INSTALL) -m 644 etc/clients_fqdn_whitelist $(CONFDIR)
	$(INSTALL) -m 644 etc/dyn_fqdn.regexp $(CONFDIR)
	$(INSTALL) -m 644 etc/smtp_server.regexp $(CONFDIR)
	$(INSTALL) -m 644 etc/README $(CONFDIR)
	$(INSTALL) -m 644 sqlgrey.1 $(MANDIR)

rh-install: install
	$(INSTALL) init/sqlgrey $(INITDIR)

gentoo-install: install
	$(INSTALL) init/sqlgrey.gentoo $(INITDIR)/sqlgrey

tbz2: update-version clean
	cd ..;ln -s sqlgrey sqlgrey-$(VERSION);tar cjhf $(TBZ2) sqlgrey-$(VERSION);rm sqlgrey-$(VERSION)

rpm: tbz2
	rpmbuild -ta ../$(TBZ2)
