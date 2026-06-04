ARG NIFI_TAG=latest
FROM apache/nifi:${NIFI_TAG} AS patch
ARG NIFI_TAG
USER root:root
RUN apt-get --allow-releaseinfo-change update && apt-get install -y zip
USER nifi:nifi
RUN mkdir -p /opt/nifi/build
WORKDIR /opt/nifi/build
COPY --chown=nifi:nifi dilcher-theme/build/ /opt/nifi/build/build/
COPY --chown=nifi:nifi patch.sh .
RUN chmod +x ./patch.sh && ./patch.sh "${NIFI_TAG}"

FROM apache/nifi:${NIFI_TAG}
ARG NIFI_TAG
USER root:root
RUN chown -R nifi:nifi /opt/nifi/nifi-current/lib
USER nifi:nifi
COPY --from=patch --chown=nifi:nifi \
     /opt/nifi/build/nifi-server/nifi-server-patched.nar \
     /opt/nifi/nifi-current/lib/nifi-server-nar-${NIFI_TAG}.nar
