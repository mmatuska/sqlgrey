%define name sqlgrey
%define ver  1.3.1
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

cd $RPM_BUILD_ROOT
find . -type f | sed 's,^\.,\%attr(-\,root\,root) ,' > $RPM_BUILD_DIR/file.list.sqlgrey

%clean
make clean

%files -f ../file.list.sqlgrey
%doc sqlgrey_client_access README HOWTO

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
