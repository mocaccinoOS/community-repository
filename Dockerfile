FROM quay.io/mocaccino/desktop

ENV LUET_YES=true
ENV LUET_NOLOCK=true
RUN luet install --relax repository/mocaccino-extra mocaccino/cli
RUN luet uninstall repository/mocaccino-desktop
RUN luet install --relax repository/mocaccino-desktop

RUN luet install --relax -qy container/docker system/luet

ENTRYPOINT /usr/bin/luet
