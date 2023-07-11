FROM maven:3.9.3-eclipse-temurin-17-alpine AS builder

COPY ./src/demo /home

WORKDIR /home

RUN mvn package && cp /home/target/*.jar /enclave.jar

# Enclave image build stage
FROM enclaive/gramine-os:jammy-33576d39

RUN apt-get update \
    && apt-get install -y libprotobuf-c1 openjdk-17-jre-headless \
    && apt-get -y install make \
    && rm -rf /var/lib/apt/lists/* \


COPY --from=builder /enclave.jar /app/
COPY ./src/demo/src/main/resources/demo-file /plaintext/
COPY ./demo.manifest.template /app/
COPY ./entrypoint.sh /app/
COPY ./ra-tls-secret-prov /ra-tls-secret-prov

RUN cd ra-tls-secret-prov \
    && make app dcap RA_TYPE=dcap

RUN mkdir files \
    && dd if=/dev/urandom of=files/wrap_key bs=16 count=1

RUN mkdir encrypted \
    && gramine-sgx-pf-crypt encrypt -w files/wrap_key -i plaintext/demo-file -o encrypted/demo-file

RUN cp ra-tls-secret-prov/secret_prov_pf/server_dcap . \
    && cp -R ra-tls-secret-prov/ssl ./ \
    && ./server_dcap &

WORKDIR /app

RUN gramine-argv-serializer "/usr/lib/jvm/java-17-openjdk-amd64/bin/java" "-XX:CompressedClassSpaceSize=8m" "-XX:ReservedCodeCacheSize=8m" "-Xmx8m" "-Xms8m" "-jar" "/app/enclave.jar" "/app/demo-file"> jvm_args.txt

RUN gramine-sgx-gen-private-key \
    && gramine-manifest -Dlog_level=error -Darch_libdir=/lib/x86_64-linux-gnu demo.manifest.template demo.manifest \
    && gramine-sgx-sign --manifest demo.manifest --output demo.manifest.sgx

ENTRYPOINT ["sh", "entrypoint.sh"]

