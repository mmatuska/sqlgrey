%define name sqlgrey
%define ver  1.3.5
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
/usr/bin/sqlgrey
/usr/share/man/man1/sqlgrey.1.gz
%config(noreplace) /etc/sqlgrey/sqlgrey.conf
/etc/sqlgrey/clients_ip_whitelist
/etc/sqlgrey/clients_fqdn_whitelist
%doc README HOWTO Changelog FAQ TODO

%pre
if [ `getent passwd sqlgrey | wc -l` = 0 ]; then
        /usr/sbin/useradd -d /var/sqlgrey sqlgrey
fi

%post
if ! /usr/bin/id sqlgrey >/dev/null 2>/dev/null; then /usr/sbin/adduser -m -k /dev/null sqlgrey; fi

%postun
if [ $1 = 0 ]; then
   if [ `getent passwd sqlgrey | wc -l` = 1 ]; then
      /usr/sbin/userdel sqlgrey
   fi
fi

%changelog
* Mon Nov 22 2004 Lionel Bouton <lionel-dev@bouton.name>
- 1.3.4 : ip whitelisting

* Wed Nov 17 2004 Lionel Bouton <lionel-dev@bouton.name>
- RPM packaging fixed
- DB connection pbs don't crash SQLgrey anymore

* Thu Nov 11 2004 Lionel Bouton <lionel-dev@bouton.name>
- Database schema slightly changed,
- Automatic database schema upgrade framework

* Sun Nov 07 2004 Lionel Bouton <lionel-dev@bouton.name>
- SQL code injection protection
- better DBI error reporting
- better VERP support
- small log related typo fix
- code cleanups

* Wed Sep 22 2004 Lionel Bouton <lionel-dev@bouton.name>
- Fixed mysql support

* Tue Sep 21 2004 Lionel Bouton <lionel-dev@bouton.name>
- SQLite support.
- HOWTO
