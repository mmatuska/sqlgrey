%define name sqlgrey
%define ver  1.0.1
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
make install ROOTDIR=$RPM_BUILD_ROOT

cd $RPM_BUILD_ROOT
find . -type f | sed 's,^\.,\%attr(-\,root\,root) ,' > $RPM_BUILD_DIR/file.list.sqlgrey

%clean
make clean

%files -f ../file.list.sqlgrey
%doc sqlgrey_client_access README HOWTO

%post
if ! /usr/bin/id sqlgrey 2>/dev/null; then /usr/sbin/adduser -m -k /dev/null sqlgrey; fi

%postun
/usr/sbin/userdel sqlgrey
