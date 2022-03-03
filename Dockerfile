FROM quay.io/mocaccino/desktop

ENV LUET_YES=true
ENV LUET_NOLOCK=true
RUN luet install repository/mocaccino-extra
RUN luet uninstall repository/mocaccino-desktop
RUN luet install repository/mocaccino-desktop-stable

RUN luet install -qy container/docker system/luet

ENTRYPOINT /usr/bin/luet