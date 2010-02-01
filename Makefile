INSTALL = install
ETCDIR = $(ROOTDIR)/etc
CONFDIR = $(ETCDIR)/sqlgrey
SBINDIR = $(ROOTDIR)/usr/sbin
BINDIR = $(ROOTDIR)/usr/bin
INITDIR = $(ETCDIR)/init.d
MANDIR = $(ROOTDIR)/usr/share/man/man1

VERSION := $(shell cat VERSION)

default:
	@echo "See INSTALL textfile";

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

use_dbcluster:
	cat sqlgrey | sed 's/^use DBI;/use DBIx::DBCluster;/' > sqlgrey.new
	mv sqlgrey.new sqlgrey
	chmod a+x sqlgrey
	cd lib/DBIx-DBCluster-0.01/;perl Makefile.PL;make;make install

use_dbi:
	cat sqlgrey | sed 's/^use DBIx::DBCluster;/use DBI;/' > sqlgrey.new
	mv sqlgrey.new sqlgrey
	chmod a+x sqlgrey

manpage:
	perldoc -u sqlgrey | pod2man -n sqlgrey > sqlgrey.1

clean:
	rm -f sqlgrey.1
	rm -f *~ .#* init/*~ etc/*~

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
	$(INSTALL) -m 644 etc/discrimination.regexp $(CONFDIR)
	$(INSTALL) -m 644 etc/dyn_fqdn.regexp $(CONFDIR)
	$(INSTALL) -m 644 etc/smtp_server.regexp $(CONFDIR)
	$(INSTALL) -m 644 etc/README $(CONFDIR)
	$(INSTALL) -m 644 sqlgrey.1 $(MANDIR)

rh-install: install
	$(INSTALL) init/sqlgrey $(INITDIR)

gentoo-install: install
	$(INSTALL) init/sqlgrey.gentoo $(INITDIR)/sqlgrey

debian-install: install
	$(INSTALL) init/sqlgrey.debian $(INITDIR)/sqlgrey
	ln -s ../init.d/sqlgrey /etc/rc0.d/K20sqlgrey 
	ln -s ../init.d/sqlgrey /etc/rc1.d/K20sqlgrey 
	ln -s ../init.d/sqlgrey /etc/rc2.d/S20sqlgrey 
	ln -s ../init.d/sqlgrey /etc/rc3.d/S20sqlgrey 
	ln -s ../init.d/sqlgrey /etc/rc4.d/S20sqlgrey 
	ln -s ../init.d/sqlgrey /etc/rc5.d/S20sqlgrey
	ln -s ../init.d/sqlgrey /etc/rc5.d/K20sqlgrey

dist: update-version clean
	##
	## TAG the revision first with:
	## [1mgit tag sqlgrey_$(VERSION)[0m
	##
	## NOTE: this will create an archive from the
	##       state of repository, ignoring your
	##       uncommited changes!!!
	@-mkdir -p dist
	git archive sqlgrey_$(VERSION) --prefix=sqlgrey-$(VERSION)/ -o dist/sqlgrey-$(VERSION).tar
	gzip -v dist/sqlgrey-$(VERSION).tar

rpm: dist
	rpmbuild -ta dist/sqlgrey-$(VERSION).tar.gz
