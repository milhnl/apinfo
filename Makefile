.POSIX:
.SILENT:
.PHONY: install uninstall

install: apinfo.sh
	mkdir -p "${DESTDIR}${PREFIX}/bin"
	cp apinfo.sh "${DESTDIR}${PREFIX}/bin/apinfo"
	chmod a+x "${DESTDIR}${PREFIX}/bin/apinfo"

uninstall:
	rm -f "${DESTDIR}${PREFIX}/bin/apinfo"
