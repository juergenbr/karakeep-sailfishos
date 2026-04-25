Name:       tst-karakeepapi

Summary:    KaraKeep API backend tests
Version:    0.1
Release:    1
License:    LICENSE
Source0:    %{name}-%{version}.tar.bz2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Test)

%description
Non-destructive integration tests for the KaraKeep API backend layer.

%prep
%setup -q -n harbour-karakeep-%{version}

%build
qmake -qt=5 tests/tests.pro
%make_build

%install
install -d %{buildroot}%{_bindir}
install -m 755 tst_karakeepapi %{buildroot}%{_bindir}/tst_karakeepapi

%files
%{_bindir}/tst_karakeepapi
