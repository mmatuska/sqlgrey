%define name sqlgrey
%define ver  1.4.0
%define rel  1

Summary:   SQLgrey is a postfix grey-listing policy service.
Name:      %{name}
Version:   %{ver}
Release:   %{rel}
Copyright: GPL
Vendor:    Lionel Bouton <lionel-dev@bouton.name>
Url:       http://sqlgrey.sourceforge.net
Packager:  Lionel Bouton <lionel-dev@bouton.name>
Group:     System Utils
Source:    %{name}-%{ver}.tar.bz2
BuildRoot: /var/tmp/%{name}-%{ver}-build
BuildArch: noarch

%description
SQLgrey is a Postfix grey-listing policy service with auto-white-listing
written in Perl with SQL database as storage backend.
Greylisting stops 50 to 90 % junk mails (spam and virus) before they
reach your Postfix server (saves BW, user time and CPU time).

%prep
%setup

%build
make

%install
make rh-install ROOTDIR=$RPM_BUILD_ROOT

%clean
make clean

%files
%defattr(-,root,root)
/etc/init.d/sqlgrey
/usr/sbin/sqlgrey
/usr/share/man/man1/sqlgrey.1.gz
%defattr(644,root,root)
%config(noreplace) /etc/sqlgrey/sqlgrey.conf
/etc/sqlgrey/clients_ip_whitelist
/etc/sqlgrey/clients_fqdn_whitelist
%doc README HOWTO Changelog FAQ TODO

%pre
if [ `getent group sqlgrey | wc -l` = 0 ]; then
        /usr/sbin/groupadd sqlgrey
fi
if [ `getent passwd sqlgrey | wc -l` = 0 ]; then
        /usr/sbin/useradd -g sqlgrey -d /var/sqlgrey sqlgrey
fi

%postun
if [ $1 = 0 ]; then
   if [ `getent passwd sqlgrey | wc -l` = 1 ]; then
      /usr/sbin/userdel sqlgrey
   fi
   if [ `getent group sqlgrey | wc -l` = 1 ]; then
      /usr/sbin/groupdel sqlgrey
   fi
fi

%changelog
* Mon Dec 13 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.4.1 release
 - fix for invalid group id messages from Øystein Viggen

* Fri Dec 10 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.4.0 release
 - windows for SQL injection fix (reported by Øystein Viggen)
 - spec file tuning inspired by Derek Battams

* Tue Nov 30 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.3.6 release
 - whitelist for FQDN as well as IP
 - 3 different greylisting algorithms
   (RFE from Derek Battams)

* Mon Nov 22 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.3.4 release
 - ip whitelisting

* Mon Nov 22 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.3.3 release
 - preliminary whitelist support

* Wed Nov 17 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.3.2 release
 - RPM packaging fixed
 - DB connection pbs don't crash SQLgrey anymore

* Thu Nov 11 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.3.0 release
 - Database schema slightly changed,
 - Automatic database schema upgrade framework

* Sun Nov 07 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.2.0 release
 - SQL code injection protection
 - better DBI error reporting
 - better VERP support
 - small log related typo fix
 - code cleanups

* Mon Oct 11 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.1.2 release
 - pidfile handling code bugfix

* Mon Sep 27 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.1.1 release
 - MySQL-related SQL syntax bugfix

* Tue Sep 21 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.1.0 release
 - SQLite support (RFE from Klaus Alexander Seistrup)

* Tue Sep 14 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 1.0.1 release
 - man page cleanup

* Tue Sep 07 2004 Lionel Bouton <lionel-dev@bouton.name>
 - pushed default max-age from 12 to 24 hours

* Sat Aug 07 2004 Lionel Bouton <lionel-dev@bouton.name>
 - bug fix for space trimming values from database

* Tue Aug 03 2004 Lionel Bouton <lionel-dev@bouton.name>
 - trim spaces before logging possible spams
 - v1.0 added license reference at the top
   at savannah request

* Fri Jul 30 2004 Lionel Bouton <lionel-dev@bouton.name>
 - Bugfix: couldn't match on undefined sender
 - debug code added

* Fri Jul 30 2004 Lionel Bouton <lionel-dev@bouton.name>
 - Removed NetAddr::IP dependency at savannah request

* Sat Jul 17 2004 Lionel Bouton <lionel-dev@bouton.name>
 - Default max-age pushed to 12 hours instead of 5
   (witnessed more than 6 hours for a mailing-list subscription
   system)

* Fri Jul 02 2004 Lionel Bouton <lionel-dev@bouton.name>
 - Documentation

* Thu Jul 01 2004 Lionel Bouton <lionel-dev@bouton.name>
 - PostgreSQL support added

* Tue Jun 29 2004 Lionel Bouton <lionel-dev@bouton.name>
 - various cleanups and bug hunting

* Mon Jun 28 2004 Lionel Bouton <lionel-dev@bouton.name>
 - 2-level AWL support

* Sun Jun 27 2004 Lionel Bouton <lionel-dev@bouton.name>
 - Initial Version, replaced BDB by mysql in postgrey
